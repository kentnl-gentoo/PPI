package PPI::Tokenizer;

# Second attempt at a Perl tokenizer
# Improvements for this second attempt include
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

# Make sure everything we need is loaded, without 
# resorting to loading all of PPI if possible.
use PPI::Common  ();
use PPI::Element ();
use PPI::Token   ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.801';
	@PPI::Tokenizer::ISA = 'PPI::Common';
}





#####################################################################
# Creation and Initialization

# Constructor
# Returns the new object on success
# Returns undef on error
sub new {
	# Create the empty tokenizer struct
	my $self = bless {
		# Source code
		source         => undef,
		source_bytes   => undef,

		# Line buffer
		line           => undef,
		line_length    => undef,
		line_cursor    => undef,
		line_count     => 0,

		# Parse state
		token          => undef,
		class          => 'PPI::Token::Whitespace',
		zone           => 'PPI::Token::Whitespace',

		# Output token buffer
		tokens         => [],
		token_cursor   => 0,
		token_eof      => 0,
		}, shift;

	# Do we have source
	return $self->_error( "No source passed to constructor" ) unless defined $_[0];

	# Handle the IO case
	if ( ref $_[0] and UNIVERSAL::isa( $_[0], 'IO::Handle' ) ) {
		# Check the handle
		$self->{source} = shift;
		return $self->_error( "IO handle is not valid and/or open" ) unless $self->{source}->opened;
		return $self->_error( "IO handle is empty, or already at EOF" )	if $self->{source}->eof;
		return $self;
	}

	# Is it straight text
	if ( ! ref $_[0] ) {
		$self->{source} = shift;

	} elsif ( UNIVERSAL::isa( $_[0], 'SCALAR' ) ) {
		$self->{source} = ${shift()};

	} elsif ( UNIVERSAL::isa( $_[0], 'ARRAY' ) ) {
		$self->{source} = join "\n", @{shift()};

	} elsif ( UNIVERSAL::isa( $_[0], 'IO::Handle' ) ) {

	} else {
		# We don't support this
		return $self->_error( "Object of type " . ref($_[0]) . " is not supported as a source" );
	}

	# Check the size of the source
	$self->{source_bytes} = length $self->{source};
	unless ( $self->{source_bytes} ) {
		return $self->_error( "Empty source argument provided to constructor" );
	}

	# Clean up it's newlines and split into an array
	$self->{source} =~ s/(?:\015\012|\015|\012)/\n/g;
	my @source = split /(?<=\n)/, $self->{source};
	$self->{source} = \@source;

	$self;
}

# Creates a new tokenizer from a file
sub load {
	my $class = shift;
	my $filename = (-f $_[0] and -r $_[0]) ? shift : return undef;

	# Load the file
	local $/;
	open( FILE, $filename ) or return undef;
	my $source = <FILE>;
	close FILE;

	$class->new( $source );
}






#####################################################################
# Main Public Methods

# Fetchs the next token
# Returns a PPI::Token on success
# Returns 0 on EOF
# Returns undef on error
sub get_token {
	my $self = shift;

	# Shortcut for EOF
	if ( $self->{token_eof}
	 and $self->{token_cursor} > scalar @{$self->{tokens}}
	) {
		return 0;
	}

	# Return the next token if we can
	if ( $_ = $self->{tokens}->[ $self->{token_cursor} ] ) {
		$self->{token_cursor}++;
		return $_;
	}

	# No token, we need to get some more
	while ( $_ = $self->_process_next_line ) {
		# If there is something in the buffer, return it
		if ( $_ = $self->{tokens}->[ $self->{token_cursor} ] ) {
			$self->{token_cursor}++;
			return $_;
		}
	}

	if ( defined $_ ) {
		# End of file, but we can still return things from the buffer
		if ( $_ = $self->{tokens}->[ $self->{token_cursor} ] ) {
			$self->{token_cursor}++;
			return $_;
		}

		# Set our token end of file flag
		$self->{token_eof} = 1;
		return 0;
	}

	# Error, pass it up to our caller
	undef;
}

# Get all the tokens
# Returns reference to array of tokens on success
# Returns 0 if no tokens before EOF
# Returns undef on error
sub all_tokens {
	my $self = shift;

	# Process lines until we get EOF
	unless ( $self->{token_eof} ) {
		my $rv;
		while ( $rv = $self->_process_next_line ) {}
		return $self->_error( "Error while processing source" ) unless defined $rv;
	}

	# End of file, return a copy of the token array.
	return @{ $self->{tokens} } ? [ @{$self->{tokens}} ] : 0;
}

# Manually increment the cursor
# Returns true on success
# Returns 0 if at EOF
# Returns undef on error
sub increment_cursor {
	# Do this via the get_token method, which makes sure there
	# is actually a token there to move to.
	$_[0]->get_token and 1;
}

# Manually decrement the cursor
# Returns true on success
# Returns 0 if at the beginning of the file
# Returns undef on error
sub decrement_cursor {
	my $self = shift;

	# Check for the beginning of the file
	return 0 unless $self->{token_cursor};

	# Decrement the token cursor
	$self->{token_eof} = 0;
	--$self->{token_cursor};
}





#####################################################################
# Working With Source

# Fetches a reference to a line of source, including
# ( cleaned up if necesary ) trailing slash.
# Returns '' at EOF.
# Returns undef on error.
sub _get_line {
	my $self = shift;
	return '' unless defined $self->{source};

	# The most likely case is it's an array
	if ( ref $self->{source} eq 'ARRAY' ) {
		# Normal line
		$_ = shift @{ $self->{source} };
		return $_ if defined $_;

		# End of file
		$self->{source} = undef;
		return '';
	}

	# It's a filehandle
	unless ( $self->{source}->eof ) {
		$_ = $self->{source}->getline;
		$self->{source_bytes} += length $_;
		s/[\015\012]*$/\n/g;
		return $_;
	}

	# End of file
	$self->{source} = undef;
	return '';
}

# Fetches the next line, ready to process
# Returns 1 on success
# Returns 0 on EOF
# Returns undef on error
sub _fill_line {
	my $self = shift;

	# Get a new line
	my $line = $self->_get_line;
	if ( length $line ) {
		$self->{line} = $line;
		$self->{line_cursor} = -1;
		$self->{line_length} = length $line;
		$self->{line_count}++;
		return 1;
	}

	if ( defined $line ) {
		# End of file, clean up
		delete $self->{line};
		delete $self->{line_cursor};
		delete $self->{line_length};
		return 0;
	}

	# Must be an error.
	# Add a comment for from us, and pass the error along
	return $self->_error( "Error getting line " . ($self->{line_count} + 1) );
}

# Get the current character
sub _char {
	my $self = shift;
	substr( $self->{line}, $self->{line_cursor}, 1 );
}





####################################################################
# Per line processing methods

# Processes the next line
# Returns 1 on success completion
# Returns 0 if EOF
# Returns undef on error
sub _process_next_line {
	my $self = shift;

	# Fill the line buffer
	unless ( $_ = $self->_fill_line ) {
		return undef unless defined $_;

		# End of file, finalize last token
		$self->_finalize_token;
		return 0;
	}

	# Run the _on_line_start
	$_ = $self->{class}->_on_line_start( $self );
	unless ( $_ ) {
		return defined $_ ? 1 # Defined but false signals "go to next line"
			: $self->_error( "Error at line $self->{line_count}" );
	}

	# If we can't deal with the entire line, process char by char
	while ( $_ = $self->_process_next_char ) {}
	unless ( defined $_ ) {
		return $self->_error( "Error at line $self->{line_count}, character $self->{line_cursor}" );
	}

	# Trigger any action that needs to happen at the end of a line
	$self->{class}->_on_line_end( $self );

	# If we have any entries in the rawinput queue process it.
	# This should happen at the END of the line, not the beginning,
	# because Tokenizer->get_token, may retrieve the RawInput terminator
	# and process it before we get a chance to rebless it from a bareword
	# or a string that it was originally.
	# Note also that _handle_raw_input has the same return conditions as
	# this method.
	$self->{rawinput_queue} ? $self->_handle_raw_input : 1;
}

# Read in raw input from the source
# Returns 1 on success
# Returns 0 on EOF
# Returns undef on error
sub _handle_raw_input {
	my $self = shift;

	# Is there a half finished token?
	if ( defined $self->{token} ) {
		if ( ref($self->{token}) eq 'PPI::Token::Whitespace' ) {
			# Finish the whitespace token
			$self->_finalize_token;
		} else {
			# This is just a little too complicated to tokenize.
			# The Perl interpretor has the luxury of being able to
			# destructively consume the input. We don't... so having
			# a token that SPANS OVER a raw input is just silly, and
			# too complicated for this little parsing to turn back
			# into something usefull.
			return $self->_error( "The code is too crufty for the tokenizer.\n"
				. "Cannot have tokens that span across rawinput lines." );
		}
	}

	while ( scalar @{$self->{rawinput_queue}} ) {
		# Find the rawinput operator and terminator
		my $position = shift @{$self->{rawinput_queue}};
		my $operator = $self->{tokens}->[ $position ];
		my $terminator = $self->{tokens}->[ $position + 1 ];

		# Check the terminator, and get the termination string
		my $tString;
		if ( ref($terminator) eq 'PPI::Token::Bareword' ) {
			$tString = $terminator->{content};
		} elsif ( ref($terminator) =~ /^PPI::Token::Quote::(Single|Double)$/ ) {
			$tString = $terminator->get_string;
			return undef unless defined $tString;
		} else {
			return $self->_error( "Syntax error. The raw input << operator must be followed by a bare word, or a single or double quoted string" );
		}
		$tString .= "\n";

		# Change the class of the terminator token to the appropriate one
		$terminator->set_class( 'RawInput::Terminator' ) or return undef;

		# Create the token
		my $rawinput = PPI::Token::RawInput::String->new( '' ) or return undef;
		$rawinput->{endString} = $tString;

		# Add some extra links, so these will know where it's other parts are
		$rawinput->{_operator} = $operator;
		$operator->{_string} = $rawinput;

		# Start looking at lines, and pull new ones until we find the
		# termination string.
		my $rv;
		while ( $rv = $self->_fill_line ) {
			# Add to the token
			$rawinput->{content} .= $self->{line};

			# Does the line match the termination string
			if ( $self->{line} eq $tString ) {
				# Done
				push @{ $self->{tokens} }, $rawinput;
				last;
			}
		}

		# End of this rawinput
		next if $rv;

		# Pass on any error
		return undef unless defined $rv;

		# End of file. We are a bit more leniant on errors, so
		# we will let this slip by without mention

		# Finish the token
		push @{ $self->{tokens} }, $rawinput if $rawinput->{content} ne '';
		return 0;
	}

	# Clean up and return true
	delete $self->{rawinput_queue};
	return 1;
}




#####################################################################
# Per-character processing methods

# Process on a per-character basis.
# Note that due the the high number of times this gets
# called, it has been fairly heavily in-lined, so the code
# might look a bit ugly and duplicated.
sub _process_next_char {
	my $self = shift;

	# Increment the counter and check for end of line
	return 0 if ++$self->{line_cursor} >= $self->{line_length};

	# Pass control to the token class
	$_ = $self->{class}->_on_char( $self ) or return 1; # False == next char

	# We will need the value of the current character
	my $char = substr( $self->{line}, $self->{line_cursor}, 1 );
	if ( $_ eq '1' ) {
		# If _on_char returns 1, it is signalling that it thinks that
		# the character is part of it.

		# Add the character
		if ( defined $self->{token} ) {
			$self->{token}->{content} .= $char;
		} else {
			$self->{token} = $self->{class}->new( $char ) or return undef;
		}

		return 1;
	}

	# We have been provided with the name of a class
	if ( $self->{class} eq "PPI::Token::$_" ) {
		# Same class as current
		if ( defined $self->{token} ) {
			$self->{token}->{content} .= $char;
		} else {
			$self->{token} = $self->{class}->new( $char ) or return undef;
		}
	} else {
		$self->_new_token( $_, $char );
	}

	1;
}





#####################################################################
# Altering Tokens in Tokenizer

# Finish the end of a token.
# Returns the resulting parse class as a convenience.
sub _finalize_token {
	my $self = shift;
	return $self->{class} unless $self->{token};

	# Add the token to the token buffer
	push @{ $self->{tokens} }, $self->{token};
	$self->{token} = undef;

	# Return the parse class to that of the zone we are in
	$self->{class} = $self->{zone};
}

# Creates a new token and sets it in the tokenizer
sub _new_token {
	my $self = shift;
	return undef unless @_;
	my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::'
		? shift : 'PPI::Token::' . shift;

	# Finalize any existing token
	$self->_finalize_token if $self->{token};

	# Create the new token and update the parse class
	$self->{token} = $class->new( $_[0] ) or return undef;
	$self->{class} = $class;

	1;
}

# Changes the token class
sub _set_token_class {
	my $self = shift;
	return $self->_error( "No token to change" ) unless $self->{token};

	# Change the token class
	$self->{token}->set_class( $_[0] )
		or $self->_error( "Failed to change token class to '$_[0]'" );

	# Update our parse class
	$self->{class} = ref $self->{token};
	1;
}






#####################################################################
# Utility Methods

# Context
sub _last_token { $_[0]->{tokens}->[-1] }
sub _last_significant_token {
	my $self = shift;
	my $cursor = $#{ $self->{tokens} };
	while ( $cursor >= 0 ) {
		my $token = $self->{tokens}->[$cursor--];
		return $token if $token->significant;
	}

	# Nothing...
	PPI::Token::Whitespace->null;
}

# Get an array ref of previous significant tokens.
# Like _last_significant_token except it get's more than just one token
# Returns array ref on success.
# Returns 0 on not enough tokens
sub _previous_significant_tokens {
	my $self = shift;
	my $count = shift || 1;
	my $cursor = $#{ $self->{tokens} };

	my ($token, @tokens);
	while ( $cursor >= 0 ) {
		$token = $self->{tokens}->[$cursor--];
		if ( $token->significant ) {
			push @tokens, $token;
			return \@tokens if scalar @tokens >= $count;
		}
	}

	# Pad with empties
	foreach ( 1 .. ($count - scalar @tokens) ) {
		push @tokens, PPI::Token::Whitespace->null;
	}

	\@tokens;
}

1;
