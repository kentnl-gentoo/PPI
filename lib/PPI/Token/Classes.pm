package PPI::Token::Whitespace;

# This file contains a number of token classes

# The _on_line_start and _on_line_end methods are passed the PPI::Tokenizer object
# as an argument. The tokenizer is normally used as $t, for convenience.

# Things to remember.
# - return 0 in _on_line_start signals to go to the next line

# The 'Whitespace' class represents the normal default state of the parser.
# That is, the whitespace area 'outside' the code.

use strict;
# use warnings;
# use diagnostics;
use PPI::Token ();
use PPI::Token::Quote::Simple ();
use PPI::Token::Quote::Full   ();

use vars qw{@classmap @commitmap};
use vars qw{$pod $blank $comment $end};
BEGIN {
	$PPI::Token::Whitespace::VERSION = '0.821';
	@PPI::Token::Whitespace::ISA     = 'PPI::Token';

	# Build the class map
        @classmap = ();
        foreach ( 'a' .. 'w', 'y', 'z', 'A' .. 'Z', '_' ) { $commitmap[ord $_] = 'PPI::Token::Bareword'  }
	foreach ( qw!; [ ] { } )! )                       { $commitmap[ord $_] = 'PPI::Token::Structure' }
        foreach ( 0 .. 9 )                                { $classmap[ord $_]  = 'Number'   }
	foreach ( qw{= ? | + < > . ! ~ ^} )               { $classmap[ord $_]  = 'Operator' }
	foreach ( qw{* $ @ & : - %} )                     { $classmap[ord $_]  = 'Unknown'  }

	# Miscellaneous remainder
        $commitmap[ord '#'] = 'PPI::Token::Comment';
        $classmap[ord ',']  = 'PPI::Token::Operator';
	$classmap[ord "'"]  = 'Quote::Single';
	$classmap[ord '"']  = 'Quote::Double';
	$classmap[ord '`']  = 'Quote::Execute';
	$classmap[ord '\\'] = 'Cast';
	$classmap[ord '_']  = 'Bareword';
}

# Create a null whitespace token
sub null { $_[0]->new('') }

sub significant { 0 }

sub _on_line_start {
	my $t = $_[1];
	$_ = $t->{line};

	# Can we classify the entire line in one go
	if ( /^\s*$/ ) {
		# A whitespace line
		$t->_new_token( 'Whitespace', $t->{line} ) or return undef;
		return 0;

	} elsif ( /^\s*#/ ) {
		# Add the comment token, and finalize it immediately
		$t->_new_token( 'Comment', $_ ) or return undef;
		$t->_finalize_token;
		return 0;

	} elsif ( /^=(\w+)/ ) {
		# A Pod tag... change to pod mode
		$t->_new_token( 'Pod', $t->{line} ) or return undef;
		if ( $1 eq 'cut' ) {
			# This is an error, but one we'll ignore
			# Don't go into Pod mode, since =cut normally
			# signals the end of Pod mode
		} else {
			$t->{class} = 'PPI::Token::Pod';
		}
		return 0;

#	} elsif ( /^\s*__(END|DATA)__\s*$/ ) {
#		# Preprocessor end of file signal
#		if ( $1 eq 'END' ) {
#			# Something off the end of the file
#			$t->_new_token( 'End', $t->{line} );
#			$t->{class} = 'PPI::Token::End';
#			$t->{class} = 'PPI::Token::End';
#			return 0;
#		} else {
#			# Data at the end of the file
#			$t->_new_token( 'Data', $t->{line} );
#			$t->{class} = 'PPI::Token::Data';
#			$t->{class} = 'PPI::Token::Data';
#			return 0;
#		}
	}

	1;
}

sub _on_char {
	my $t = $_[1];
	$_ = ord substr $t->{line}, $t->{line_cursor}, 1;

	# Do we definately know what something is?
	return $commitmap[$_]->_commit($t) if $commitmap[$_];

	# Handle the simple option first
	return $classmap[$_] if $classmap[$_];

	if ( $_ == 40 ) {  # $_ eq '('
		# Finalise any whitespace token...
		$t->_finalize_token if $t->{token};

		# Is this the beginning of a sub prototype?
		# We are a sub prototype IF
		# 1. The previous significant token is a bareword.
		# 2. The one before that is the word 'sub'.
		# 3. The one before that is a 'structure'

		# Get the three previous significant tokens
		my $tokens = $t->_previous_significant_tokens( 3 );
		if ( $tokens ) {
			# A normal subroutine declaration
		     	if ( $tokens->[0]->is_a('Bareword')
		     		and $tokens->[1]->is_a('Bareword', 'sub')
		     	 	and (
			     		$tokens->[2]->is_a('Structure')
					or $tokens->[2]->is_a('Whitespace', '')
			     		)
		     	) {
				# This is a sub prototype
				return 'SubPrototype';
			}

			# An prototyped anonymous subroutine
			if ( $tokens->[0]->is_a( 'Bareword', 'sub' ) ) {
				return 'SubPrototype';
			}
		}

		# This is a normal open bracket
		return 'Structure';

	} elsif ( $_ == 47 ) { #  $_ eq '/'
		# Finalise any whitespace token...
		$t->_finalize_token if $t->{token};

		# This is either a "divided by" or a "start regex"
		# Do some context stuff to guess ( ack ) which.
		# Hopefully the guess will be good enough.
		my $previous = $t->_last_significant_token;

		# Most times following an operator, we are a regex
		return 'Regex::Match' if $previous->is_a( 'Operator' );

		# After a symbol
		return 'Operator' if $previous->is_a( 'Symbol' );
		return 'Operator' if $previous->is_a( 'Structure', ']' );
		return 'Operator' if $previous->is_a( 'Structure', '}' );

		# After another number
		return 'Operator' if $previous->is_a( 'Number' );

		# After going into scope/brackets
		return 'Regex::Match' if $previous->is_a( 'Structure', '(' );
		return 'Regex::Match' if $previous->is_a( 'Structure', '{' );
		return 'Regex::Match' if $previous->is_a( 'Structure', ';' );

		# Functions that we know use commonly use regexs as an argument
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'split' );

		# After a keyword
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'if' );
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'unless' );
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'grep' );

		# As an argument in a list
		return 'Regex::Match' if $previous->is_a( 'Operator', ',' );

		# What about the char after the slash? There's some things
		# that would be highly illogical to see if it's an operator.
		my $next_char = substr $t->{line}, $t->{line_cursor} + 1, 1;
		if ( defined $next_char and length $next_char ) {
			if ( $next_char =~ /(?:\^|\[|\\)/ ) {
				return 'Regex::Match';
			}
		}

		# Otherwise... erm... assume operator?
		# Add more tests here as potential cases come to light
		return 'Operator';

	} elsif ( $_ == 120 ) { # $_ eq 'x'
		# Handle an arcane special case where "string"x10 means the x is an operator.
		# String in this case means ::Single, ::Double or ::Execute, or the operator versions or same.
		my $nextchar = substr $t->{line}, $t->{line_cursor} + 1, 1;
		my $previous = $t->_previous_significant_tokens(1);
		$previous = ref $previous->[0];
		if ( $nextchar =~ /^\d$/ and $previous ) {
			if ( $previous =~ /::Quote::(?:Operator)?(?:Single|Double|Execute)$/ ) {
				return 'Operator';
			}
		}

		# Otherwise, commit like a normal bareword
		PPI::Token::Bareword->_commit($t);
	}

	# This SHOULD BE is just normal base stuff
	'Whitespace';
}

sub _on_line_end { $_[1]->_finalize_token if $_[1]->{token} }

# Horozintal space before a newline is not needed.
# The ->tidy method removes it.
sub tidy {
	my $self = shift;
	$self->{content} =~ s/^\s+?(?>\n)//;
	1;
}





#####################################################################
# POD

package PPI::Token::Pod;

BEGIN {
	$PPI::Token::Pod::VERSION = '0.821';
	@PPI::Token::Pod::ISA     = 'PPI::Token';
}

sub significant { 0 }

sub _on_line_start {
	my $t = $_[1];

	# Add the line to the token first
	$t->{token}->{content} .= $t->{line};

	# Check the line to see if it is a =cut line
	if ( $t->{line} =~ /^=(\w+)/ ) {
		# End of the token
		$t->_finalize_token if lc $1 eq 'cut';
	}

	0;
}

# Breaks the pod into lines, returned as a reference to an array
sub lines { [ split /(?:\015{1,2}\012|\015|\012)/, $_[0]->{content} ] }

# Extended methods.
# See PPI::Token::_Pod for details
sub merge { require PPI::Token::_Pod; shift->merge( @_ ) }





#####################################################################
# After the __DATA__ tag

package PPI::Token::Data;

BEGIN {
	$PPI::Token::Data::VERSION = '0.821';
	@PPI::Token::Data::ISA     = 'PPI::Token';
}

sub _on_char { 1 }




#####################################################################
# After the __END__ tag

package PPI::Token::End;

BEGIN {
	$PPI::Token::End::VERSION = '0.821';
	@PPI::Token::End::ISA     = 'PPI::Token';
}

sub significant { 0 }

sub _on_char { 1 }

sub _on_line_start {
	my $t = $_[1];

	# Can we classify the entire line in one go
	$_ = $t->{line};
	if ( /^=(\w+)/ ) {
		# A Pod tag... change to pod mode
		$t->_new_token( 'Pod', $_ ) or return undef;
		unless ( $1 eq 'cut' ) {
			# Normal start to pod
			$t->{class} = 'PPI::Token::Pod';
		}

		# This is an error, but one we'll ignore
		# Don't go into Pod mode, since =cut normally
		# signals the end of Pod mode
	} else {
		if ( defined $t->{token} ) {
			# Add to existing token
			$t->{token}->{content} .= $t->{line};
		} else {
			$t->_new_token( 'End', $t->{line} );
		}
	}

	0;
}





#####################################################################
# Comments

package PPI::Token::Comment;

BEGIN {
	$PPI::Token::Comment::VERSION = '0.821';
	@PPI::Token::Comment::ISA     = 'PPI::Token';
}

sub significant { 0 }

# Most stuff goes through _commit.
# This is such a rare case, do char at a time to keep the code small
sub _on_char {
	my $t = $_[1];

	# Make sure not to include the trailing newline
	if ( substr( $t->{line}, $t->{line_cursor}, 1 ) eq "\n" ) {
		return $t->_finalize_token->_on_char( $t );
	}

	1;
}

sub _commit {
	my $t = $_[1];

	# Get the rest of the line
	$_ = substr( $t->{line}, $t->{line_cursor} );
	if ( chomp ) { # Include the newline seperately
		# Add the current token, and the newline
		$t->_new_token( 'Comment', $_ );
		$t->_new_token( 'Whitespace', "\n" );
	} else {
		# Add this token only
		$t->_new_token( 'Comment', $_ );
	}

	# Advance the line cursor to the end
	$t->{line_cursor} = $t->{line_length} - 1;

	0;
}

# Comments end at the end of the line
sub _on_line_end {
	$_[1]->_finalize_token if $_[1]->{token};
	1;
}

# Is this comment an entire line?
sub line {
	# Entire line comments have a newline at the end
	$_[0]->{content} =~ /\n$/ ? 1 : 0;
}





#####################################################################
# Bareword

package PPI::Token::Bareword;

use vars qw{%quotelike};
BEGIN {
	$PPI::Token::Bareword::VERSION   = '0.821';
	@PPI::Token::Bareword::ISA       = 'PPI::Token';
	%quotelike = (
		'q'  => 'Quote::OperatorSingle',
		'qq' => 'Quote::OperatorDouble',
		'qx' => 'Quote::OperatorExecute',
		'qw' => 'Quote::Words',
		'qr' => 'Quote::Regex',
		'm'  => 'Regex::Match',
		's'  => 'Regex::Replace',
		'tr' => 'Regex::Transform',
		'y'  => 'Regex::Transform',
		);
}

sub _on_char {
	my $class = shift;
	my $t     = shift;

	# Suck in till the end of the bareword
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(\w+(?:::[^\W\d]\w*)*(?:::)?)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# We might be a subroutine attribute.
	my $tokens = $t->_previous_significant_tokens(1);
	if ( $tokens and $tokens->[0]->{_attribute} ) {
		$t->_set_token_class( 'Attribute' );
		return $t->{class}->_commit( $t );
	}

	# Check for a quote like operator
	my $word = $t->{token}->{content};
	if ( $quotelike{$word} ) {
		# Turn it into the appropriate class
		$t->_set_token_class( $quotelike{$word} );
		return $t->{class}->_on_char( $t );
	}

	# Or one of the word operators
	if ( $PPI::Token::Operator::operator{$word} ) {
	 	$t->_set_token_class( 'Operator' );
	 	return $t->_finalize_token->_on_char( $t );
	}

	# Unless this is a simple identifier, at this point
	# it has to be a normal bareword
	if ( $word =~ /\:/ ) {
		return $t->_finalize_token->_on_char( $t );
	}

	# If the NEXT character in the line is a colon, this
	# is a label.
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );
	if ( $char eq ':' ) {
		$t->{token}->{content} .= ':';
		$t->{line_cursor}++;
		$t->_set_token_class( 'Label' );

	# If not a label, '_' on it's own is the magic filehandle
	} elsif ( $word eq '_' ) {
		$t->_set_token_class( 'Magic' );

	}

	# Finalise and process the character again
	$t->_finalize_token->_on_char( $t );
}

# We are committed to being a bareword.
# Or so we would like to believe.
sub _commit {
	my $t = $_[1];

	# Our current position is the first character of the bareword.
	# Capture the bareword.
	my $line = substr( $t->{line}, $t->{line_cursor} );
	unless ( $line =~ /^([^\W\d]\w*(?:::[^\W\d]\w*)*(?:::)?)/ ) {
		# Programmer error
		$DB::single = 1;
		die "Fatal error... regex failed to match when expected";
	}

	# Advance the position one after the end of the bareword
	my $word = $1;
	$t->{line_cursor} += length $word;

	# We might be a subroutine attribute.
	my $tokens = $t->_previous_significant_tokens(1);
	if ( $tokens and $tokens->[0]->{_attribute} ) {
		$t->_new_token( 'Attribute', $word );
		return ($t->{line_cursor} >= $t->{line_length}) ? 0
			: $t->{class}->_on_char($t);
	}

	# Check for the special case of the quote-like operator
	if ( $quotelike{$word} ) {
		$t->_new_token( $quotelike{$word}, $word );
		return ($t->{line_cursor} >= $t->{line_length}) ? 0
			: $t->{class}->_on_char( $t );
	}

	# Check for the end of the file
	if ( $word eq '__END__' ) {
		# Create the token for the __END__ itself
		$t->_new_token( 'Bareword', $1 );
		$t->_finalize_token;

		# Change into the End zone
		$t->{zone} = 'PPI::Token::End';

		# Add the rest of the line as the End token
		$line = substr( $t->{line}, $t->{line_cursor} );
		$t->_new_token( 'End', $line );

		return 0;
	}

	# Check for the data section
	if ( $word eq '__DATA__' ) {
		# Create the token for the __DATA__ itself
		$t->_new_token( 'Bareword', "$1" );
		$t->_finalize_token;

		# Change into the Data zone
		$t->{zone} = 'PPI::Token::Data';

		# Add the rest of the line as the Data token
		$line = substr( $t->{line}, $t->{line_cursor} );
		$t->_new_token( 'Data', $line );

		return 0;
	}

	my $token_class;
	if ( $PPI::Token::Operator::operator{$word} ) {
		# Word operator
		$token_class = 'Operator';

	} elsif ( $word =~ /\:/ ) {
		# Since it's not a simple identifier...
		$token_class = 'Bareword';

	} else {
		# Now, if the next character is a :, it's a label
		my $char = substr( $t->{line}, $t->{line_cursor}, 1 );
		if ( $char eq ':' ) {
			$word .= ':';
			$t->{line_cursor}++;
			$token_class = 'Label';
		} elsif ( $word eq '_' ) {
			$token_class = 'Magic';
		} else {
			$token_class = 'Bareword';
		}
	}

	# Create the new token and finalise
	$t->_new_token( $token_class, $word );
	if ( $t->{line_cursor} >= $t->{line_length} ) {
		# End of the line
		$t->_finalize_token;
		return 0;
	}
	$t->_finalize_token->_on_char($t);
}





#####################################################################
# A Label

package PPI::Token::Label;

BEGIN {
	$PPI::Token::Label::VERSION = '0.821';
	@PPI::Token::Label::ISA     = 'PPI::Token';
}





#####################################################################
# Characters used to create heirachal structure

package PPI::Token::Structure;

BEGIN {
	$PPI::Token::Structure::VERSION = '0.821';
	@PPI::Token::Structure::ISA     = 'PPI::Token';
}

sub _on_char {
	# Structures are one character long, always.
	# Finalize and process again.
	$_[1]->_finalize_token->_on_char( $_[1] );
}

sub _commit {
	my $t = $_[1];
	$t->_new_token( 'Structure', substr( $t->{line}, $t->{line_cursor}, 1 ) );
	$t->_finalize_token;
	0;
}

use vars qw{@match};
BEGIN {
	my @tmp = (
		'{' => '}', '}' => '{',
		'[' => ']', ']' => '[',
		'(' => ')', ')' => '(',
		);
	@match = ();
	while ( @tmp ) {
		$match[ord shift @tmp] = shift @tmp;
	}
}

# For a given brace, find it's opposing pair
sub _opposite { $match[ord $_[0]->{content} ] }





#####################################################################
# A number

package PPI::Token::Number;

# The perl numeric token are
#    $n = 1234;       # decimal integer
#    $n = 0b1110011;  # binary integer
#    $n = 01234;      # octal integer
#    $n = 0x1234;     # hexadecimal integer
#    $n = 12.34e-56;  # exponential notation ( currently not working )

BEGIN {
	$PPI::Token::Number::VERSION = '0.821';
	@PPI::Token::Number::ISA     = 'PPI::Token';
}

sub _on_char {
	my $class = shift;
	my $t     = shift;
	my $char  = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Allow underscores straight through
	return 1 if $char eq '_';

	# Handle the conversion from an unknown to known type.
	# The regex covers "potential" hex/bin/octal number.
	my $token = $t->{token};
	if ( $token->{content} =~ /^-?0_*$/ ) {
		# This could be special
		if ( $char eq 'x' ) {
			$token->{_subtype} = 'hex';
			return 1;
		} elsif ( $char eq 'b' ) {
			$token->{_subtype} = 'bin';
			return 1;
		} elsif ( $char =~ /\d/ ) {
			$token->{_subtype} = 'octal';
			return 1;
		} elsif ( $char eq '.' ) {
			return 1;
		} else {
			# End of the number... it's just 0
			return $t->_finalize_token->_on_char( $t );
		}
	}

	if ( ! $token->{_subtype} or $token->{_subtype} eq 'base256' ) {
		# Handle the easy case, integer or real.
		return 1 if $char =~ /\d/o;

		if ( $char eq '.' ) {
			if ( $token->{content} =~ /\.$/ ) {
				# We have a .., which is an operator.
				# Take the . off the end of the token..
				# and finish it, then make the .. operator.
				chop $t->{token}->{content};
				$t->_new_token( 'Operator', '..' ) or return undef;
				return 0;
			} else {
				# Will this be the first .?
				if ( $token->{content} =~ /\./ ) {
					return 1;
				} else {
					# Flag as a base256.
					$token->{_subtype} = 'base256';
					return 1;
				}
			}
		}

	} elsif ( $token->{_subtype} eq 'octal' ) {
		# You cannot have 9s on octals
		if ( $char eq '9' ) {
			return $class->_error( "Illegal octal digit '9'" );
		}

		# Any other number is ok
		return 1 if $char =~ /\d/o;

	} elsif ( $token->{_subtype} eq 'hex' ) {
		return 1 if $char =~ /[\da-f]/io;

		# Error on other word chars
		if ( $char =~ /\w/ ) {
			return $class->_error( "Illegal hexidecimal character '$char'" );
		}

	} elsif ( $token->{_subtype} eq 'binary' ) {
		return 1 if $char =~ /(?:1|0)/;

		# Other bad characters
		if ( $char =~ /[\w\d]/ ) {
			return $class->_error( "Illegal binary character '$char'" );
		}

	} else {
		return $class->_error( "Unknown number type '$token->{_subtype}'" );
	}

	# Doesn't fit a special case, or is after the end of the token
	# End of token.
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# Operator

package PPI::Token::Operator;

BEGIN {
	$PPI::Token::Operator::VERSION = '0.821';
	@PPI::Token::Operator::ISA     = 'PPI::Token';
}

# Build the operator index
use vars qw{%operator};
BEGIN {
	%operator = ();
	foreach ( qw{
		-> ++ -- ** ! ~ + -
		=~ !~ * / % x + - . << >>
		< > <= >= lt gt le ge
		== != <=> eq ne cmp
		& | ^ && || .. ...
		? : = += -= *= .=
		=>
		and or not
		}, ',' 	# Avoids "comma in qw{}" warning
	) {
		$operator{$_} = 1;
	}
}

sub _on_char {
	my $t = $_[1];
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Are we still an operator if we add the next character
	return 1 if $operator{ $t->{token}->{content} . $char };

	# Unless this is the raw input string operator...
	unless ( $t->{token}->{content} eq '<<' and $char =~ /[a-zA-Z_'"]/ ) {
		# ...handle normally
		return $t->_finalize_token->_on_char( $t );
	}

	# This is a raw input string.
	# Finalize the operator under a different class...
	$t->_set_token_class( 'RawInput::Operator' );
	$t->_finalize_token;

	# ... and add a marker to the multiline input queue
	# to signal that we need to be looked at at the end
	# of the line.
	if ( $t->{rawinput_queue} ) {
		push @{ $t->{rawinput_queue} }, $#{ $t->{tokens} };
	} else {
		$t->{rawinput_queue} = [ $#{ $t->{tokens} } ];
	}

	# Now deal with what should ( hopefully ) be either a
	# normal single quoted string, or a bareword, normally.
	$t->{class}->_on_char( $t );
}





#####################################################################
# Symbol

package PPI::Token::Symbol;

BEGIN {
	@PPI::Token::Symbol::VERSION = '0.821';
	@PPI::Token::Symbol::ISA     = 'PPI::Token';
}

sub _on_char {
	my $t = $_[1];

	# Suck in till the end of the symbol
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^([\w:']+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Check for magic
	my $content = $t->{token}->{content};
	if ( $content eq '@_' or $content eq '$_' ) {
		$t->_set_token_class( 'Magic' );
	}

	$t->_finalize_token->_on_char( $t );
}

# Returns the normalised, canonical symbol name.
# For example, converts '$ ::foo'bar::baz' to '$main::foo::bar::baz'
sub canonical {
	my $self = shift;
	my $name = $self->content;
	$name =~ s/\s+//;
	$name =~ s/(?<=[\$\@\%\&\*])::/main::/;
	$name =~ s/\'/::/g;
	$name;
}





#####################################################################
# An array index thingy

package PPI::Token::ArrayIndex;

BEGIN {
	$PPI::Token::ArrayIndex::VERSION = '0.821';
	@PPI::Token::ArrayIndex::ISA     = 'PPI::Token';
}

sub _on_char {
	my $t = $_[1];

	# Suck in till the end of the arrayindex
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^([\w:']+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# End of token
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# Magic variable

package PPI::Token::Magic;

BEGIN {
	$PPI::Token::Magic::VERSION = '0.821';
	@PPI::Token::Magic::ISA     = 'PPI::Token::Symbol';
}

use vars qw{%magic};
BEGIN {
	# Magic variables taken from perlvar.
	# Several things added seperately to avoid warnings.
	foreach ( qw{
		$1 $2 $3 $4 $5 $6 $7 $8 $9
		$_ $& $` $' $+ @+ $* $. $/ $|
		$\\ $" $; $% $= $- @- $)
		$~ $^ $: $? $! %! $@ $$ $< $>
		$( $0 $[ $] @_ @*

		$^L $^A $^E $^C $^D $^F $^H
		$^I $^M $^N $^O $^P $^R $^S
		$^T $^V $^W $^X
	}, '$}', '$,', '$#', '$#+', '$#-' ) {
		$magic{$_} = 1;
	}
}

sub _on_char {
	my $t = $_[1];
	$_ = $t->{token}->{content} . substr( $t->{line}, $t->{line_cursor}, 1 );

	# Do a quick first test so we don't have to do more than this one.
	# All of the tests below match this one, so it should provide a
	# small speed up. This regex should be updated to match the inside
	# tests if they are changed.
	if ( /^\$.*[\w:\$\{]$/ ) {

		if ( /^(\$(?:\_[\w:]|::))/ or /^\$\'[\w]/ ) {
			# It's actually a normal symbol in the style
			# $_foo or $::foo or $'foo. Overwrite the current token
			$t->{token} = PPI::Token::Symbol->new( $1 );
			return 0;
		}

		if ( /^\$\$\w/ ) {
			# This is really a scalar dereference. ( $$foo )
			# Add the current token as the cast...
			$t->{token} = PPI::Token::Cast->new( '$' );
			$t->_finalize_token;

			# ... and create a new token for the symbol
			$t->_new_token( 'Symbol', '$' ) or return undef;
			return 1;
		}

		if ( $_ eq '$#$' or $_ eq '$#{' ) {
			# This is really an index dereferencing cast, although
			# it has the same two chars as the magic variable $#.
			$t->_set_token_class('Cast');
			return $t->_finalize_token->_on_char( $t );
		}

		if ( /^(\$\#\w)/ ) {
			# This is really an array index thingy ( $#array )
			$t->{token} = PPI::Token::ArrayIndex->new( $1 );
			return 1;
		}

		if ( /^\$\^\w/o ) {
			# It's an escaped char magic... maybe ( like $^M )
			return 1;
		}

		if ( /^\$\#\{/ ) {
			# The $# is actually a case, and { is it's block
			# Add the current token as the cast...
			$t->{token} = PPI::Token::Cast->new( '$#' );
			$t->_finalize_token;

			# ... and create a new token for the block
			$t->_new_token( 'Structure', '{' ) or return undef;
			return 1;
		}
	}

	# End the current magic token, and recheck
	$t->_finalize_token->_on_char( $t );
}

# Our version is canonical is much simple
sub canonical { $_[0]->content }





#####################################################################
# Casting operator

package PPI::Token::Cast;

BEGIN {
	$PPI::Token::Cast::VERSION = '0.821';
	@PPI::Token::Cast::ISA     = 'PPI::Token';
}

# A cast is either % @ $ or $#
sub _on_char {
	$_[1]->_finalize_token->_on_char( $_[1] );
}





#####################################################################
# Subroutine prototype

package PPI::Token::SubPrototype;

BEGIN {
	$PPI::Token::SubPrototype::VERSION = '0.821';
	@PPI::Token::SubPrototype::ISA     = 'PPI::Token';
}

sub _on_char {
	my $class = shift;
	my $t = shift;

	# Suck in until we find the closing bracket
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(.+?\))/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Finish off the token and process the next char
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# Subroutine Attribute

# Attributes are a relatively new invention.
# Given C< sub foo : bar(something) {} >, bar(something) is an attribute.

package PPI::Token::Attribute;

BEGIN {
	$PPI::Token::Attribute::VERSION = '0.821';
	@PPI::Token::Attribute::ISA     = 'PPI::Token';
}

sub _on_char {
	my $class = shift;
	my $t = shift;
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Unless this is a '(', we are finished.
	unless ( $char eq '(' ) {
		# Finalise and recheck
		return $t->_finalize_token->_on_char( $t );
	}

	# This is a bar(...) style attribute.
	# We are currently on the ( so scan in until the end.
	# We finish on the character AFTER our end
	my $string = $class->_scan_for_end( $t );
	if ( ref $string ) {
		# EOF
		$t->{token}->{content} .= $$string;
		$t->_finalize_token;
		return '';
	}

	# Found the end of the attribute
	$t->{token}->{content} .= $string;
	$t->{token}->{_attribute} = 1;
	$t->_finalize_token->_on_char( $t );
}

# Scan for a close braced, and take into account both escaping,
# and open close bracket pairs in the string. When complete, the
# method leaves the line cursor on the LAST character found.
sub _scan_for_end {
	my $t = $_[1];

	# Loop as long as we can get new lines
	my $string = '';
	my $depth = 0;
	while ( exists $t->{line} ) {
		# Get the search area
		$_ = $t->{line_cursor}
			? substr( $t->{line}, $t->{line_cursor} )
			: $t->{line};

		# Look for a match
		unless ( /^(.*?(?:\(|\)))/ ) {
			# Load in the next line
			$string .= $_;
			return undef unless defined $t->_fill_line;
			$t->{line_cursor} = 0;
			next;
		}

		# Add to the string
		$string .= $1;
		$t->{line_cursor} += length $1;

		# Alter the depth and continue if we arn't at the end
		$depth += ($1 =~ /\($/) ? 1 : -1 and next;

		# Found the end
		return $string;
	}

	# Returning the string as a reference indicates EOF
	\$string;
}

# Returns the attribute identifier
sub identifier {
	my $self = shift;
	$self->{content} =~ /^(.+?)\(/ ? $1 : $self->{content};
}

# Returns the attribute parameters, or undef if it has none
sub parameters {
	my $self = shift;
	$self->{content} =~ /\((.+)\)$/ ? $1 : undef;
}
	




#####################################################################
# A Dashed Bareword ( -foo )

package PPI::Token::DashedBareword;

# This should be a string... but I'm still musing on whether that's a good idea

BEGIN {
	$PPI::Token::DashedBareword::VERSION = '0.821';
	@PPI::Token::DashedBareword::ISA     = 'PPI::Token';
}

sub _on_char {
	my $t = $_[1];

	# Suck to the end of the dashed bareword
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(\w+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Are we a file test operator?
	if ( $t->{token}->{content} =~ /^\-[rwxoRWXOezsfdlpSbctugkTBMAC]$/ ) {
		# File test operator
		$t->_set_token_class( 'Operator' ) or return undef;
	} else {
		# No, normal dashed bareword
		$t->_set_token_class( 'Bareword' ) or return undef;
	}

	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# All the quote and quote like operators

# Single Quote
package PPI::Token::Quote::Single;

BEGIN {
	$PPI::Token::Quote::Single::VERSION = '0.821';
	@PPI::Token::Quote::Single::ISA     = 'PPI::Token::Quote::Simple';
}

# Double Quote
package PPI::Token::Quote::Double;

BEGIN {
	$PPI::Token::Quote::Single::VERSION = '0.821';
	@PPI::Token::Quote::Double::ISA     = 'PPI::Token::Quote::Simple';
}

# Initially return true/fales for if there are ANY interpolations.
# Upgrade: Return the interpolated substrings.
# Upgrade: Returns parsed expressions.
sub interpolations {
	my $self = shift;

	# Are there any unescaped $things in the string
	!! $self->content =~ /(?<!\\)(?:\\\\)*\$/;
}

# Simplify a double-quoted string into a single-quoted string
sub simplify {
	# This only works on EXACTLY this class
	my $self = (ref $_[0] eq 'PPI::Token::Quote::Double') ? shift : undef;

	# Don't bother if there are characters that could complicate things
	my $content = $self->content;
	my $value   = substr($content, 1, length($content) - 1);
	return '' if $value =~ /[\\\$\'\"]/;

	# Change the token to a single string
	$self->{content} = '"' . $value . '"';
	bless $self, 'PPI::Token::Quote::Single';
}

# Back Ticks
package PPI::Token::Quote::Execute;

BEGIN {
	$PPI::Token::Quote::Execute::VERSION = '0.821';
	@PPI::Token::Quote::Execute::ISA     = 'PPI::Token::Quote::Simple';
}

# Single Quote
package PPI::Token::Quote::OperatorSingle;

BEGIN {
	$PPI::Token::Quote::OperatorSingle::VERSION = '0.821';
	@PPI::Token::Quote::OperatorSingle::ISA     = 'PPI::Token::Quote::Full';
}

# Double Quote
package PPI::Token::Quote::OperatorDouble;

BEGIN {
	$PPI::Token::Quote::OperatorDouble::VERSION = '0.821';
	@PPI::Token::Quote::OperatorDouble::ISA     = 'PPI::Token::Quote::Full';
}

# Back Ticks
package PPI::Token::Quote::OperatorExecute;

BEGIN {
	$PPI::Token::Quote::OperatorExecute::VERSION = '0.821';
	@PPI::Token::Quote::OperatorExecute::ISA     = 'PPI::Token::Quote::Full';
}

# Quote Words
package PPI::Token::Quote::Words;

BEGIN {
	$PPI::Token::Quote::Words::VERSION = '0.821';
	@PPI::Token::Quote::Words::ISA     = 'PPI::Token::Quote::Full';
}

# Quote Regex Expression
package PPI::Token::Quote::Regex;

BEGIN {
	$PPI::Token::Quote::Regex::VERSION = '0.821';
	@PPI::Token::Quote::Regex::ISA     = 'PPI::Token::Quote::Full';
}

# Operator or Non-Operator Match Regex
package PPI::Token::Regex::Match;

BEGIN {
	$PPI::Token::Regex::Match::VERSION = '0.821';
	@PPI::Token::Regex::Match::ISA     = 'PPI::Token::Quote::Full';
}

# Operator Pattern Regex
### Either this of PPI::Token::Quote::Regex is probably a duplicate
package PPI::Token::Regex::Pattern;

BEGIN {
	$PPI::Token::Regex::Pattern::VERSION = '0.821';
	@PPI::Token::Regex::Pattern::ISA     = 'PPI::Token::Quote::Full';
}

# Replace Regex
package PPI::Token::Regex::Replace;

BEGIN {
	$PPI::Token::Regex::Replace::VERSION = '0.821';
	@PPI::Token::Regex::Replace::ISA     = 'PPI::Token::Quote::Full';
}

# Transform regex
package PPI::Token::Regex::Transform;

BEGIN {
	$PPI::Token::Regex::Transform::VERSION = '0.821';
	@PPI::Token::Regex::Transform::ISA     = 'PPI::Token::Quote::Full';
}





#####################################################################
# Classes to support multi-line inputs

package PPI::Token::RawInput::Operator;

BEGIN {
	$PPI::Token::RawInput::Operator::VERSION = '0.821';
	@PPI::Token::RawInput::Operator::ISA     = 'PPI::Token';
}

package PPI::Token::RawInput::Terminator;

BEGIN {
	$PPI::Token::RawInput::Terminator::VERSION = '0.821';
	@PPI::Token::RawInput::Terminator::ISA     = 'PPI::Token';
}

package PPI::Token::RawInput::String;

BEGIN {
	$PPI::Token::RawInput::String::VERSION = '0.821';
	@PPI::Token::RawInput::String::ISA     = 'PPI::Token';
}

1;
