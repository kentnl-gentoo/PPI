package PPI::Tokenizer;

# Process:
# --------
#
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
use base 'PPI::Base';
use List::MoreUtils ();
use PPI::Element    ();
use PPI::Token      ();
use File::Slurp     ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840';
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

	# Is it straight text
	if ( ! ref $_[0] ) {
		$self->{source} = shift;

	} elsif ( UNIVERSAL::isa( $_[0], 'SCALAR' ) ) {
		$self->{source} = ${shift()};

	} elsif ( UNIVERSAL::isa( $_[0], 'ARRAY' ) ) {
		$self->{source} = join "\n", @{shift()};

	} else {
		# We don't support this
		return $self->_error( "Object of type " . ref($_[0]) . " is not supported as a source" );
	}

	# Localise the newlines for the file
	$self->{source} =~ s/(?:\015{1,2}\012|\015|\012)/\n/g;

	# Check the size of the source
	$self->{source_bytes} = length $self->{source};
	unless ( $self->{source_bytes} ) {
		return $self->_error( "Empty source argument provided to constructor" );
	}

	# Split into the line array
	$self->{source} = [ split /(?<=\n)/, $self->{source} ];

	# OK, listen up, I'm explaining this earlier than I should so you
	# can understand why I'm about to do something that looks very
	# strange. There's a problem with the Tokenizer, in that tokens
	# tend to change classes as each letter is added, but they don't
	# get allocated their definite final class until the "end" of the
	# token, the detection of which occurs in about a hundred different
	# places, all through various crufty code.
	# However, in general, this does not apply to tokens in which a
	# whitespace character is valid, such as comments, whitespace and
	# big strings.
	# So, what we do is add a space to the end of the source. This
	# triggers "end of token" functionality for all cases. Then, once
	# the tokenizer hits end of file, it examines the last token to
	# manually either remove the ' ' token, or chop it off the end of
	# a longer one in which the space would be valid.
	if ( List::MoreUtils::any { /^__(?:DATA|END)__\s*$/ } @{$self->{source}} ) {
		$self->{source_eof_chop} = '';
	} elsif ( $self->{source}->[-1] =~ /\s$/ ) {
		$self->{source_eof_chop} = '';
	} else {
		$self->{source_eof_chop} = 1;
		$self->{source}->[-1] .= ' ';
	}

	$self;
}

# Creates a new tokenizer from a file
sub load {
	my $class    = shift;
	my $filename = shift or return undef;
	my $source   = File::Slurp::read_file($filename, reference => 1) or return undef;
	$class->new( $source );
}





#####################################################################
# Main Public Methods

# Fetches the next token
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

		# Clean up the end of the tokenizer
		$self->_clean_eof;
	}

	# End of file, return a copy of the token array.
	@{ $self->{tokens} } ? [ @{$self->{tokens}} ] : 0;
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

# Fetches the next line from the input line buffer
# Returns undef at EOF.
 sub _get_line {
	my $self = shift;
	return undef unless $self->{source}; # EOF hit previously

	# Pull off the next line
	my $line = shift @{$self->{source}};

	# Flag EOF if we hit it
	$self->{source} = undef unless defined $line;

	# Return the line (or EOF flag)
	$line; # string or undef
}

# Fetches the next line, ready to process
# Returns 1 on success
# Returns 0 on EOF
# Returns undef on error
sub _fill_line {
	my $self = shift;

	# Get the next line
	my $line = $self->_get_line;
	unless ( defined $line ) {
		# End of file, clean up
		delete $self->{line};
		delete $self->{line_cursor};
		delete $self->{line_length};
		return 0;
	}

	# Populate the appropriate variables
	$self->{line} = $line;
	$self->{line_cursor} = -1;
	$self->{line_length} = length $line;
	$self->{line_count}++;

	# Mainly to protect ourselves against the horror that is
	# Crypt::GeneratePassword, don't allow lines longer than 
	# 5000 characters.
	if ( $self->{line_length} > 5000 ) {
		return $self->_error( "Line longer than 5000 characters found ( $self->{line_length} characters )" );
	}

	1;
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
	my $rv;
	unless ( $rv = $self->_fill_line ) {
		return undef unless defined $rv;

		# End of file, finalize last token
		$self->_finalize_token;
		return 0;
	}

	# Run the _on_line_start
	$rv = $self->{class}->_on_line_start( $self );
	unless ( $rv ) {
		# If there are no more source lines, then clean up
		if ( ref $self->{source} eq 'ARRAY' and ! @{$self->{source}} ) {
			$self->_clean_eof;
		}
		return defined $rv ? 1 # Defined but false signals "go to next line"
			: $self->_error( "Error at line $self->{line_count}" );
	}

	# If we can't deal with the entire line, process char by char
	while ( $rv = $self->_process_next_char ) {}
	unless ( defined $rv ) {
		return $self->_error( "Error at line $self->{line_count}, character $self->{line_cursor}" );
	}

	# Trigger any action that needs to happen at the end of a line
	$self->{class}->_on_line_end( $self );

	# If there are no more source lines, then clean up
	if ( ref $self->{source} eq 'ARRAY' and ! @{$self->{source}} ) {
		return $self->_clean_eof;
	}

	# If we have any entries in the rawinput queue process it.
	# This should happen at the END of this line, not the beginning of
	# the next one, because Tokenizer->get_token, may retrieve the RawInput
	# terminator and process it before we get a chance to rebless it from
	# a bareword or a string that it was originally. Note also that
	# _handle_raw_input has the same return conditions as this method.
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
			# too complicated for this little parser to turn back
			# into something useful.
			return $self->_error( "The code is too crufty for the tokenizer.\n"
				. "Cannot have tokens that span across rawinput lines." );
		}
	}

	while ( scalar @{$self->{rawinput_queue}} ) {
		# Find the rawinput operator and terminator
		my $position = shift @{$self->{rawinput_queue}};
		my $operator = $self->{tokens}->[ $position ];
		my $terminator = $self->{tokens}->[ $position + 1 ];

		# Handle a whitespace gap between the operator and terminator
		if ( ref($terminator) eq 'PPI::Token::Whitespace' ) {
			$terminator = $self->{tokens}->[ $position + 2 ];
		}

		# Check the terminator, and get the termination string
		my $tString;
		if ( ref($terminator) eq 'PPI::Token::Word' ) {
			$tString = $terminator->{content};
		} elsif ( ref($terminator) =~ /^PPI::Token::Quote::(Single|Double)$/ ) {
			$tString = $terminator->string;
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

		# Add some extra links, so these will know where its other parts are
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

		# End of file. We are a bit more lenient on errors, so
		# we will let this slip by without mention. In fact, it may
		# well actually be legal.

		# Finish the token
		push @{ $self->{tokens} }, $rawinput if $rawinput->{content} ne '';
		return 0;
	}

	# Clean up and return true
	delete $self->{rawinput_queue};

	1;
}




#####################################################################
# Per-character processing methods

# Process on a per-character basis.
# Note that due the the high number of times this gets
# called, it has been fairly heavily in-lined, so the code
# might look a bit ugly and duplicated.
sub _process_next_char {
	my $self = shift;

	if ( ! defined $self->{line_cursor} or ! defined $self->{line_length} ) {
		$DB::single = 1;
	}

	# Increment the counter and check for end of line
	return 0 if ++$self->{line_cursor} >= $self->{line_length};

	# Pass control to the token class
	unless ( $_ = $self->{class}->_on_char( $self ) ) {
		# undef is error. 0 is "Did stuff ourself, you don't have to do anything"
		return defined $_ ? 1 : undef;
	}

	# We will need the value of the current character
	my $char = substr( $self->{line}, $self->{line_cursor}, 1 );
	if ( $_ eq '1' ) {
		# If _on_char returns 1, it is signaling that it thinks that
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
	if ( $self->{class} ne "PPI::Token::$_" ) {
		# New class
		$self->_new_token( $_, $char );
	} elsif ( defined $self->{token} ) {
		# Same class as current
		$self->{token}->{content} .= $char;
	} else {
		# Same class, but no current
		$self->{token} = $self->{class}->new( $char ) or return undef;
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
	$self->{token} = $class->new($_[0]) or return undef;
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

# At the end of the file, we need to clean up the results of the erroneous
# space that we inserted at the beginning of the process.
sub _clean_eof {
	my $self = shift;

	# Finish any partially completed token
	$self->_finalize_token if $self->{token};

	# Find the last token, and if it has no content, kill it.
	# There appears to be some evidence that such "null tokens" are
	# somehow getting created accidentally.
	my $last_token = $self->{tokens}->[ $#{$self->{tokens}} ];
	unless ( length $last_token->{content} ) {
		pop @{$self->{tokens}};
	}

	# Now, if the last character of the last token is a space we added,
	# chop it off, deleting the token if there's nothing else left.
	if ( $self->{source_eof_chop} ) {
		$last_token = $self->{tokens}->[ $#{$self->{tokens}} ];
		$last_token->{content} =~ s/ $//;
		unless ( length $last_token->{content} ) {
			# Popping token
			pop @{$self->{tokens}};
		}

		# The hack involving adding an extra space is now reversed, and
		# now nobody will ever know. The perfect crime!
		$self->{source_eof_chop} = '';
	}

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
# Like _last_significant_token except it gets more than just one token
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
