# This file contains a number of token classes

# The _on_line_start and _on_line_end methods are passed the PPI::Tokenizer object
# as an argument. The tokenizer is normally used as $t, for convenience.

# Things to remember
# - return 0 in _on_line_start signals to go to the next line

package PPI::Token::Whitespace;

# The 'Whitespace' class represents the normal default state of the parser.
# That is, the whitespace area 'outside' the code.

use strict;
# use warnings;
# use diagnostics;
use PPI::Token;

use vars qw{$VERSION};
use vars qw{@classmap @commitmap};
use vars qw{$pod $blank $comment $end};
BEGIN {
	$VERSION = '0.802';
	@PPI::Token::Whitespace::ISA = 'PPI::Token';

	# Build the class map
        @classmap = ();
        foreach ( 'a' .. 'z', 'A' .. 'Z' ) { $commitmap[ord $_] = 'PPI::Token::Bareword' }
	foreach ( qw!; [ ] { } )! )        { $commitmap[ord $_] = 'PPI::Token::Structure' }
        foreach ( 0 .. 9 )                 { $classmap[ord $_]  = 'Number' }
	foreach ( qw{= ? | + < > . ! ~} )  { $classmap[ord $_]  = 'Operator' }
	foreach ( qw{* $ @ & : - %} )      { $classmap[ord $_]  = 'Unknown' }

	# Miscellaneous remainder
        $commitmap[ord '#'] = 'PPI::Token::Comment';
        $classmap[ord ',']  = 'PPI::Token::Operator';
	$classmap[ord "'"]  = 'Quote::Single';
	$classmap[ord '"']  = 'Quote::Double';
	$classmap[ord '`']  = 'Quote::Execute';
	$classmap[ord '\\'] = 'Cast';
	$classmap[ord '_']  = 'Bareword';
}

# Create a null base token
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

	} elsif ( /^\s*__(END|DATA)__\s*$/ ) {
		# Preprocessor end of file signal
		if ( $1 eq 'END' ) {
			# Something off the end of the file
			$t->_new_token( 'End', $t->{line} );
			$t->{class} = 'PPI::Token::End';
			$t->{class} = 'PPI::Token::End';
			return 0;
		} else {
			# Data at the end of the file
			$t->_new_token( 'Data', $t->{line} );
			$t->{class} = 'PPI::Token::Data';
			$t->{class} = 'PPI::Token::Data';
			return 0;
		}
	}

	1;
}

sub _on_char {
	my $t = $_[1];
	$_ = ord substr( $t->{line}, $t->{line_cursor}, 1 );

	if ( $commitmap[$_] ) {
		# We definately know what this is
		return $commitmap[$_]->_commit( $t );
	}

	if ( $classmap[$_] ) {
		# Handle the simple option first
		return $classmap[$_];
	}

	if ( $_ == 40 ) {  # $_ eq '('
		# Finalise any whitespace token...
		$t->_finalize_token if $t->{token};

		# Is this the beginning of a sub prototype?\
		# We are a sub prototype IF
		# 1. The previous significant token is a bareword.
		# 2. The one before that is the word 'sub'.
		# 3. The one before that is a 'structure'

		# Get the three previous significant tokens
		my $tokens = $t->_previous_significant_tokens( 3 );
		if ( $tokens
		     and $tokens->[0]->is_a( 'Bareword' )
		     and $tokens->[1]->is_a( 'Bareword', 'sub' )
		     and ( $tokens->[2]->is_a( 'Structure' )
		 	or $tokens->[2]->is_a( 'Bareword', '' )
		     )
		) {
			# This is a sub prototype
			return 'SubPrototype';
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

		# Functions that we know use regexs as an argument
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'split' );

		# After a keyword
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'if' );
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'unless' );
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'grep' );

		# As an argument in a list

		# Otherwise... erm... assume operator?
		# I expect we will have to add more tests here
		return 'Operator';
	}

	# This SHOULD BE is just normal base stuff
	return 'Whitespace';
}

sub _on_line_end { $_[1]->_finalize_token if $_[1]->{token} }

# Horozintal space before a newline is un-necesary.
# The ->tidy method removes it.
sub tidy {
	my $self = shift;
	$self->{content} =~ s/^\s+?(?>\n)//;
	return 1;
}





#####################################################################
# POD

package PPI::Token::Pod;

use strict;

BEGIN {
	@PPI::Token::Pod::ISA = 'PPI::Token';
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

	return 0;
}

# Breaks the pod into lines, returned as a reference to an array
sub lines { [ split /(?:\015\012|\015|\012)/, $_[0]->{content} ] }

# Extended methods.
# See PPI::Token::_Pod for details
sub merge { require PPI::Token::_Pod; return shift->merge( @_ ) }





#####################################################################
# After the __DATA__ tag

package PPI::Token::Data;

use strict;

BEGIN {
	@PPI::Token::Data::ISA = 'PPI::Token';
}

sub _on_char { 1 }




#####################################################################
# After the __END__ tag

package PPI::Token::End;

use strict;
use base 'PPI::Token';

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

	return 0;
}





#####################################################################
# Comments

package PPI::Token::Comment;

use strict;
use base 'PPI::Token';

sub significant { 0 }

# Most stuff goes through _commit.
# This is such a rare case, do char at a time to keep the code small
sub _on_char {
	my $t = $_[1];

	# Make sure not to include the trailing newline
	if ( substr( $t->{line}, $t->{line_cursor}, 1 ) eq "\n" ) {
		return $t->_finalize_token->_on_char( $t );
	}

	return 1;
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

	return 0;
}

# Comments end at the end of the line
sub _on_line_end {
	$_[1]->_finalize_token if $_[1]->{token};
	return 1;
}

# Is this comment an entire line?
sub line {
	# Entire line comments have a newline at the end
	return $_[0]->{content} =~ /\n$/ ? 1 : 0;
}





#####################################################################
# Bareword

package PPI::Token::Bareword;

use strict;
use base 'PPI::Token';

use vars qw{%quotelike};
BEGIN {
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
	my $t = shift;

	# Suck in till the end of the bareword
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^([\w:]+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Check for a quote like operator
	my $bareword = $t->{token}->{content};
	if ( $quotelike{$bareword} ) {
		# Turn it into the appropriate class
		$t->_set_token_class( $quotelike{$bareword} );
		return $t->{class}->_on_char( $t );

	# Or one of the word operators
	} elsif ( $PPI::Token::Operator::operator{$bareword} ) {
	 	$t->_set_token_class( 'Operator' );

	# Or is it a label
	} elsif ( $bareword =~ /^[A-Za-z_]\w*:$/ ) {
		$t->_set_token_class( 'Label' );

	}

	# Finalise and process the character again
	return $t->_finalize_token->_on_char( $t );
}

# We are committed to being a bareword
sub _commit {
	my $t = $_[1];

	# Our current position is the first character of the bareword.
	# Capture the bareword.
	my $line = substr( $t->{line}, $t->{line_cursor} );
	unless ( $line =~ /^([\w:]+)/ ) {
		# Programmer error
		$DB::single = 1;
		die "Fatal error... regex failed to match when expected";
	}

	# Advance the position one after the end of the bareword
	$t->{line_cursor} += length $1;

	# Check for the special case of the quote-like operator
	my $word = $1;
	if ( $quotelike{$word} ) {
		$t->_new_token( $quotelike{$word}, $word );

		# And hand off to the quotelike _on_char
		return $t->{class}->_on_char( $t );
	}

	# Normal case
	my $token_class = $PPI::Token::Operator::operator{$word} ? 'Operator'
		: ($word =~ /^[A-Za-z_]\w*:$/) ? 'Label'
		: 'Bareword';

	# Create the new token and finalise
	$t->_new_token( $token_class, $word );
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# A Label

package PPI::Token::Label;

use strict;
use base 'PPI::Token::Bareword';

sub DUMMY { 1 }





#####################################################################
# Characters used to create heirachal structure

package PPI::Token::Structure;

use strict;
use base 'PPI::Token';

sub _on_char {
	# Structures are one character long, always.
	# Finalize and process again.
	return $_[1]->_finalize_token->_on_char( $_[1] );
}

sub _commit {
	my $t = $_[1];
	$t->_new_token( 'Structure', substr( $t->{line}, $t->{line_cursor}, 1 ) );
	$t->_finalize_token;
	return 0;
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

sub _matching_brace { $match[ord $_[0]->{content} ] }





#####################################################################
# A number

package PPI::Token::Number;

# We should eventually be able to support the following ( from perlnumber )
#
#    $n = 1234;       # decimal integer
#    $n = 0b1110011;  # binary integer
#    $n = 01234;      # octal integer
#    $n = 0x1234;     # hexadecimal integer
#    $n = 12.34e-56;  # exponential notation ( currently not working )
#
# We currently support decimal, real, and octal ( by accident :) )

use strict;
use base 'PPI::Token';

sub _on_char {
	my $class = shift;
	my $t = shift;
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );

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
		} elsif ( $char =~ /\d/o ) {
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
# Symbol

package PPI::Token::Symbol;

use strict;
use base 'PPI::Token';

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




#####################################################################
# An array index thingy

package PPI::Token::ArrayIndex;

use strict;
use base 'PPI::Token';

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
# Operator

package PPI::Token::Operator;

use strict;
use base 'PPI::Token';

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
	return $t->{class}->_on_char( $t );
}





#####################################################################
# Magic variable

package PPI::Token::Magic;

use strict;
use base 'PPI::Token';

use vars qw{%magic};
BEGIN {
	# Magic variables taken from perlvar.
	# Several things added seperately to avoid warnings.
	foreach ( qw{
		$1 $2 $3 $4 $5 $6 $7 $8 $9
		$_ $& $` $' $+ @+ $* $. $/ $|
		$\\ $" $; $% $= $- @- $)
		$~ $^ $: $? $! %! $@ $$ $< $>
		$( $0 $[ $]

		$^L $^A $^E $^C $^D $^F $^H
		$^I $^M $^O $^P $^R $^S $^T
		$^V $^W $^X
	}, '$,', '$#', '$#+', '$#-' ) {
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
	if ( /^\$.*[\w:]$/ ) {

		if ( /^(\$(?:\_[\w:]|::))/ or /^\$\'[\w]/ ) {
			# It's actually a normal symbol in the style
			# $_foo or $::foo or $'foo. Overwrite the current token
			$t->{token} = PPI::Token::Symbol->new( $1 );
			return 0;
		}

		if ( /^\$\$\w/ ) {
			# This is really a referenced scalar ref. ( $$foo )
			# Add the current token as the cast...
			$t->{token} = PPI::Token::Cast->new( '$' );
			$t->_finalize_token;

			# ... and create a new token for the symbol
			$t->_new_token( 'Symbol', '$' ) or return undef;
			return 1;
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
	}

	# End the current magic token, and recheck
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# Casting operator

package PPI::Token::Cast;

use strict;
use base 'PPI::Token';

# A cast is always a single character
sub _on_char {
	$_[1]->_finalize_token->_on_char( $_[1] );
}





#####################################################################
# Subroutine prototype descriptor

package PPI::Token::SubPrototype;

use strict;
use base 'PPI::Token';

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
# A Dashed Bareword ( -foo )

package PPI::Token::DashedBareword;

# This should be a string... but I'm still musing on whether that's a good idea

use strict;
use base 'PPI::Token';

sub _on_char {
	my $t = $_[1];

	# Suck to the end of the dashed bareword
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(\w+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Finish the dashed bareword
	$t->_set_token_class( 'Bareword' ) or return undef;
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# All the quote and quote like operators

# Single Quote
package PPI::Token::Quote::Single;
use base 'PPI::Token::Quote::Simple';
sub DUMMY { 1 }

# Double Quote
package PPI::Token::Quote::Double;
use base 'PPI::Token::Quote::Simple';
sub DUMMY { 1 }

# Back Ticks
package PPI::Token::Quote::Execute;
use base 'PPI::Token::Quote::Simple';
sub DUMMY { 1 }

# Single Quote
package PPI::Token::Quote::OperatorSingle;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Double Quote
package PPI::Token::Quote::OperatorDouble;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Back Ticks
package PPI::Token::Quote::OperatorExecute;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Quote Words
package PPI::Token::Quote::Words;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Quote Regex Expression
package PPI::Token::Quote::Regex;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Operator or Non-Operator Match Regex
package PPI::Token::Regex::Match;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Operator Pattern Regex
package PPI::Token::Regex::Pattern;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Replace Regex
package PPI::Token::Regex::Replace;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }

# Transform regex
package PPI::Token::Regex::Transform;
use base 'PPI::Token::Quote::Full';
sub DUMMY { 1 }





#####################################################################
# Classes to support multi-line inputs

package PPI::Token::RawInput::Operator;
use base 'PPI::Token';
sub DUMMY { 1 }

package PPI::Token::RawInput::Terminator;
use base 'PPI::Token';
sub DUMMY { 1 }

package PPI::Token::RawInput::String;
use base 'PPI::Token';
sub DUMMY { 1 }

1;
