package PPI::Tokenizer;

# Second attempt at a Perl tokenizer
# Improvements for this second attempt will include
# - Pod support
# - More overloads
# - Better quote support
# - Support for precompiler tags
#
# Process
# The tokenizer works through a series of buffers.
#
# The first holds the raw source code, which can be either a scalar, an array 
# reference, or a file handle.
#
# The second holds the current row being worked on.
# Code is processed a row at a time, which is pulled from the source buffer.
#
# In the main loop, characters are read from the line buffer one at a time,
# and operations are carried out based on the state of the tokenizer, the
# particular character etc.
#
# Completed token are placed into an output buffer.
# 
# The whole thing works on a pull basis though. When a token is requested,
# it is taken from the token buffer. When the token buffer empties, source
# is processed a line at a time, until the token buffer contains tokens
# again. This process repeats until the source code runs out.
#
# The tokenizer also maintains some statistics

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';
use Class::Autouse; 

# Import the regexs
use PPI::RegexLib qw{%RE};

# Force the loading of some stuff ( so it happens in order )
BEGIN {
	Class::Autouse->load( 'PPI::Tokenizer::Token' );

	# Quote engine must be loaded before classes
	Class::Autouse->load( 'PPI::Tokenizer::Quote' );
	Class::Autouse->load( 'PPI::Tokenizer::Classes' );
}
 
# Constructor
# Returns the new object on success
# Returns undef on error
sub new {
	my $class = shift;
	
	# Get the constructor options
	my %options = ();
	if ( scalar @_ == 1 ) {
		return undef unless isa( $_[0], 'HASH' );
		%options = %{$_[0]};
	} elsif ( scalar @_ ) {
		%options = @_;
	} else {
		return $class->andError( "Invalid constructor argument" );
	}
	
	# Create the emtpy tokenizer struct
	my $self = {
		# Source code
		source_handle => undef,
		source_type => undef,
		
		# Line buffer
		line_buffer => undef,
		line_length => undef,
		line_position => undef,
		
		# Current character and state
		char => undef,
		token => undef,
		class => undef,
		zone => undef,
		
		# Variables to support << style input
		rawinput_queue => [],
		
		# Output token buffer
		tokens => [],
		token_cursor => 0,
		token_eof => 0,
		
		# Statistics
		stats => {
			source_bytes => 0,
			lines => {
				total => 0,
				code  => 0,
				comment => 0,
				whitespace => 0,
				pod => 0,
				}
			}		
		};
	bless $self, $class;
	
	# Set the source. They MUST have this.
	$self->setSource( $options{source} ) 
	or return $self->andError( "Failed to set the source during creation of Tokenizer" );

	# Set the starting class
	$self->setClass( $options{startclass} || "Base" )
	or return $self->andError( "Failed to set initial code class during creation of Tokenizer" );
	
	# Set the starting zone
	$self->setZone( $options{startzone} || "Base" )
	or return $self->andError( "Failed to set initial code zone during creation of Tokenizer" );
	
	return $self;
}





#####################################################################
# Basic getters and setters

sub setClass {
	my $self = shift;
	my $name = shift;
	my $class = $self->resolveClass( $name ) or return undef;
	$self->{class} = $class;
	return 1;
}
	
sub setZone {
	my $self = shift;
	my $name = shift;
	my $class = $self->resolveClass( $name ) or return undef;
	$self->{zone} = $class;
	return 1;
}

use vars qw{%resolve};
BEGIN { %resolve = () }

# Resolve a short token class into it's full class name.
# Make's sure it exists.
sub resolveClass {
	my $class = shift;
	my $name = shift or return undef;
	unless ( defined $resolve{$name} ) {
		my $full = "PPI::Tokenizer::Token::$name";
	
		# Check that it exists
		$resolve{$name} = Class::Autouse->class_exists( $full ) ? $full : 0;
	}
	return $resolve{$name}
	       or $class->andError( "The token class '$name' does not exist" );
}
	

#####################################################################
# Source buffer

sub setSource {
	my $self = shift;
	my $source = shift;
	
	# Make sure we are allowed to set the source
	if ( $self->{stats}->{source_bytes} ) {
		return $self->andError( "It is too late to set the source" );
	}
	
	# Did they give us something
	unless ( defined $source ) {
		return $self->andError( "You did not pass a source" );
	}
	
	# Is it straight text
	if ( isa( $source, 'SCALAR' ) ) {
		$source = $$source;
	}
	if ( ! ref $source ) {
		unless ( length $source ) {
			return $self->andError( "You passed the constructor a zero length string" );
		}			
		# Get the file lines for the scalar
		$self->{source_handle} = $self->getFileLines( $source );
		$self->{source_type} = 'ARRAY';
		return 1;
	}

	# Is it a handle of some sort
	if ( isa( $source, 'IO::Handle' ) ) {
		# Check the handle
		unless ( $source->opened ) {
			return $self->andError( "The IO Handle you passed is not a valid, open, io handle" );
		}
		if ( $source->eof ) {
			return $self->andError( "You passed an empty handle" );
		}
		
		# We assume for now that we have permissions
		# to read the file
		
		$self->{source_handle} = $source;
		$self->{source_type} = 'HANDLE';
		return 1;
	}
			
	# Is it an array of content
	if ( isa( $source, 'ARRAY' ) ) {
		if ( scalar @$source == 0 ) {
			return $self->andError( "You passed an empty array reference" );
		}
		# Get the file lines from the array
		$self->{source_handle} = $self->getFileLines( join '', @$source );
		$self->{source_type} = 'ARRAY';
		return 1;
	}

	# We don't support this
	return $self->andError( "Object of type " . ref( $source ) . " is not supported as a source" );
}

# Fetches a reference to a line of source, including ( cleaned up ) trailing slash
# Returns 0 on eof
# Returns undef on error
sub getSourceLine {
	my $self = shift;
	return 0 unless $self->{source_handle};
	
	my $line = '';
	if ( $self->{source_type} eq 'ARRAY' ) {
		# Check for end of file
		unless ( scalar @{ $self->{source_handle} } ) {
			return $self->{source_handle} = 0;
		}		
		
		$line = shift @{ $self->{source_handle} };
		
	} elsif ( $self->{source_type} eq 'HANDLE' ) {
		# Check for end of file
		if ( $self->{source_handle}->eof ) {
			return $self->{source_handle} = 0;
		}
					
		$line = $self->{source_handle}->getline;
		
	} else {
		return undef;
	}
	
	# Add to the stats
	$self->{stats}->{source_bytes} += length $line;

	# Fix any carriage returns
	$line =~ s/$RE{newline}{crossplatform}$/\n/g;
	return \$line;
}
	




####################################################################
# Line buffer

# Fetches the next line, ready to process
# Returns 1 on success
# Returns 0 on EOF
# Returns undef on error
sub fillNextLine {
	my $self = shift;
	
	# Get a new line
	my $line = $self->getSourceLine;
	if ( $line ) {
		$self->{line_buffer} = $$line;
		$self->{line_position} = -1;
		$self->{line_length} = length $self->{line_buffer};
		$self->{stats}->{lines}->{total}++;
		return 1;
	
	} elsif ( defined $line ) {
		# End of file.
		return 0;
	
	} else {
		# Must be an error
		# Add a comment for us, and pass the error along
		return $self->andError( "Error getting line " . ($self->{stats}->{lines} + 1) );
	}
}

# Processes the next line
# Returns 1 on success completion
# Returns 0 if EOF
# Returns undef on error
sub processNextLine {
	my $self = shift;

	# If we have an entry in the rawinput queue process it
	if ( scalar @{ $self->{rawinput_queue} } ) {
		return $self->handleRawInput();
	}
	
	# Fill the line buffer
	my $rv = $self->fillNextLine();
	return undef unless defined $rv;
	unless ( $rv ) {
		# Finalize the last token, then exit
		$self->finalizeToken if $self->{token};
		return 0;
	}
		
	# Run the onLineStart
	$rv = $self->{class}->onLineStart( $self );
	unless ( defined $rv ) {
		return $self->andError( "Error during $self->{class}\->onLineStart on line $self->{stats}->{lines}->{total}" );
	}
	return 1 if ! $rv; # Handle "next line" signal
	
	# Process each of the characters in the line
	while ( $rv = $self->processNextChar ) {}
	unless ( defined $rv ) {
		# Error while processing			
		return $self->andError( "Error at character $self->{line_position} on line $self->{stats}->{lines}->{total}" );
	}

	# Trigger the onLineEnd hook if required
	$rv = $self->{class}->onLineEnd( $self );
	unless ( defined $rv ) {
		return $self->andError( "Error during $self->{class}\::onLineEnd on line $self->{stats}->{lines}->{total}" );
	}
	
	return 1;
}

# Read in raw input from the source
# Returns 1 on success
# Returns 0 on EOF
# Returns undef on error
sub handleRawInput {
	my $self = shift;
	
	# Is there a half finished token?
	if ( defined $self->{token} ) {
		if ( $self->{token}->{class} eq 'Base' ) {
			# Finish the whitespace token
			$self->finalizeToken();
		} else {
			# This is just a little too complicated to tokenize.
			# The Perl interpretor has the luxury of being able to 
			# destructively consume the input. We don't... so having
			# a token that SPANS OVER a raw input is just silly, and
			# too complicated for this little parsing to turn back 
			# into something usefull.
			return $self->andError( "The code is too crufty for the tokenizer.\n"
				. "Cannot have tokens that span across rawinput lines." );
		}
	}

	# Next, find the rawinput operator and terminator
	my $position = shift @{ $self->{rawinput_queue} };
	my $operator = $self->{tokens}->[ $position ];
	my $terminator = $self->{tokens}->[ $position + 1 ];
	
	# Check the terminator, and get the termination string
	my $tString;
	if ( $terminator->{class} eq 'Bareword' ) {
		$tString = $terminator->{content};
	} elsif ( $terminator->{class} =~ /^Quote::(Single|Double)$/ ) {
		$tString = $terminator->getString;
		return undef unless defined $tString;
	} else {
		return $self->andError( "Syntax error. The raw input << operator must be followed by a bare word, or a single or double quoted string" );
	}
	$tString .= "\n";
	
	# Change the class of the terminator token to the appropriate one ( for later )
	$terminator->setClass( 'RawInput::Terminator' ) or return undef;
	
	# Create the token
	my $rawinput = PPI::Tokenizer::Token::RawInput::String->new( $self->{zone}, '' ) or return undef;
	$rawinput->{endString} = $tString;
	
	# Add some extra links, so these will know where it's other parts are
	$rawinput->{_operator} = $operator;
	$operator->{_string} = $rawinput;
	
	# Start looking at lines, and pull new ones until we find
	my $rv;
	while ( $rv = $self->fillNextLine ) {
		# Add to the token
		$rawinput->{content} .= $self->{line_buffer};
		
		# Does the line match the termination string
		if ( $self->{line_buffer} eq $tString ) {
			# Done
			push @{ $self->{tokens} }, $rawinput;
			return 1;
		}
	}
	if ( defined $rv ) {
		# End of file. We are a bit more leniant on errors, so 
		# we will let this slip by without mention

		# Finish the token
		push @{ $self->{tokens} }, $rawinput if $rawinput->{content} ne '';
		return 0;
	} else {
		# Pass on the error
		return undef;
	}
}
		 
	


#####################################################################
# Per-Character processing

# Process on a per-character basis.
# Note that due the the high number of times this get's 
# called, it has been fairly heavily in-lined, so the code
# might look a bit ugly
sub processNextChar {
	my $self = shift;
	
	# Increment the counter and check for end of line
	return 0 if ++$self->{line_position} >= $self->{line_length};
	
	# Set the char
	$self->{char} = substr( $self->{line_buffer}, $self->{line_position}, 1 );
	
	# Add the character to the token
	my $rv = $self->{class}->onChar( $self );
	if ( $rv eq '1' ) {
		# Add the character
		if ( defined $self->{token} ) {
			$self->{token}->{content} .= $self->{char};
		} else {
			$self->{token} = $self->{class}->new( $self->{zone}, $self->{char} ) or return undef;
		}
		
	} elsif ( $rv ) {
		# Use the legacy style character selector
		if ( $self->{class} eq "PPI::Tokenizer::Token::$rv" ) {
			if ( defined $self->{token} ) {
				$self->{token}->{content} .= $self->{char};
			} else {
				$self->{token} = $self->{class}->new( $self->{zone}, $self->{char} ) or return undef;
			}
		} else {
			$self->newToken( $rv, $self->{char} );
		}
	}
	
	return 1;
}

sub onChar { $_[0]->{class}->onChar( $_[0] ) }






#####################################################################
# Methods called by the above

# Finish the end of a token
sub finalizeToken {
	my $self = shift;
	return 1 unless $self->{token};
	
	# Add the token to the token buffer
	push @{ $self->{tokens} }, $self->{token};
	$self->{token} = undef;
	
	# Return the class to that of the zone we are in
	$self->{class} = $self->{zone};
	
	return 1;
}

# Creates a new token and sets it in the tokenizer
sub newToken {
	my $self = shift;

	# Get and check the class
	my $class = $self->resolveClass( shift ) or return undef;
		
	# Finalize any existing token
	$self->finalizeToken;
	
	# Create the new token
	$self->{token} = $class->new( $self->{zone}, $_[0] ) or return undef;
	$self->{class} = $class;
	
	return 1;
}

# Add a single character to the current token
sub addChar {
	my $self = shift;
	
	# Create a token if we don't have one
	if ( defined $self->{token} ) {
		$self->{token}->{content} .= $self->{char};
	} else {
		$self->{token} = $self->{class}->new( $self->{zone}, $self->{char} );
	}
	return 1;
}

# Changes the token class
sub setTokenClass {
	my $self = shift;
	my $name = shift;
	return $self->andError( "No token to change" ) unless $self->{token};
	
	if ( $name =~ /^(?:Quote|Regex)::/ ) {
		# Special setClass. 
		# We need to create a new one from the content of the old
		my $class = "PPI::Tokenizer::Token::$name";
		my $new = $class->new( $self->{token}->{zone}, $self->{token}->{content} );
		return $self->andError( "Failed to setTokenClass to quote like class '$name'" ) unless $new;
		
		$self->{token} = $new;
	} else {
		# Or just change it's class the normal way
		$self->{token}->setClass( $name ) or return undef;
	}
	
	$self->{class} = ref $self->{token};
	return 1;
}

#####################################################################
# Token processing

# Fetchs the next token
# Returns a PPI::Tokenizer::Token on success
# Returns 0 on EOF
# Returns undef on error
sub nextToken {
	my $self = shift;
	
	# Shortcut for EOF
	if ( $self->{token_eof} 
	 and $self->{token_cursor} > scalar @{ $self->{tokens} } 
	) {
		return 0;
	}
	
	# Return the next token if we can
	my $token = $self->{tokens}->[ $self->{token_cursor} ];
	if ( $token ) {
		$self->{token_cursor}++;
		return $token;
	}
	
	# No token, we need to get some more
	my $rv;
	while ( defined ($rv = $self->processNextLine) ) {
		# If there is something in the buffer, return i
		my $token = $self->{tokens}->[ $self->{token_cursor} ];
		if ( $token ) {
			$self->{token_cursor}++;
			return $token;
		}
		
		# If we get an EOF, with an empty buffer, set our
		# EOF flag and signal
		unless ( $rv ) {
			$self->{token_eof} = 1;
			return 0;
		}				
	}

	# Pass the error on
	return undef;
}

# Get all the tokens
# Returns reference to array of tokens on success
# Returns 0 if no tokens before EOF
# Returns undef on error
sub allTokens {
	my $self = shift;
	
	# Process lines until we get EOF
	my $rv;
	unless ( $self->{token_eof} ) {
		while ( $rv = $self->processNextLine ) {}
	
		# Check for error
		unless ( defined $rv ) {
			return $self->andError( "Error while processing source" );
		}
	}
	
	# End of file
	if ( scalar @{ $self->{tokens} } ) {
		# Return a copy of the token array
		return [ @{$self->{tokens}} ];
	} else {
		return 0;
	}
}





#####################################################################
# Handy methods

sub makeIndex {
	my $class = shift;
	my $hash = {};
	foreach ( @_ ) { $hash->{$_} = 1 }
	return $hash;
}

# Context 
sub lastToken { $_[0]->{tokens}->[-1] }
sub lastSignificantToken {
	my $self = shift;
	my $cursor = $#{ $self->{tokens} };
	while ( $cursor >= 0 ) {
		my $token = $self->{tokens}->[$cursor];
		if ( $token->significant ) {
			return $token;
		}
		$cursor--;
	}

	# Nothing...
	return $self->emptyToken;
}

# Get an array ref of previous significant tokens.
# Like lastSignificantToken except it get's more than just one token
# Returns array ref on success.
# Returns 0 on not enough tokens
sub previousSignificantTokens {
	my $self = shift;
	my $count = shift || 1;
	my $cursor = $#{ $self->{tokens} };
	my ($token, @tokens);
	while ( $cursor >= 0 ) {
		$token = $self->{tokens}->[$cursor];
		if ( $token->significant ) {		
			push @tokens, $token;
			return \@tokens if scalar @tokens >= $count;
		}
		$cursor--;
	}
	
	# Pad with empties
	push @tokens, ($self->emptyToken) x ($count - scalar @tokens);
	return \@tokens;
}

# Create an empty base token
sub emptyToken { PPI::Tokenizer::Token->new( 'Base', '' ) }

# Split function that acts similarly to the normal split, 
# except that the safeSplit can also handle empty end splits.
# Also, returns a reference to the split string, for speed reasons.
sub getFileLines {
	my $self = shift;
	my $string = shift;

	# Look for end lines seperately
	my @result = ();
	while ( $string =~ s/$RE{newline}{crossplatform}$// ) {
		push @result, '';
	}
	
	# Do the proper split
	unshift @result, split /$RE{newline}{crossplatform}/, $string;
	@result = map { "$_\n" } @result;
	chomp $result[-1]; # Don't CRLF the last line
	return \@result;
}

1;
