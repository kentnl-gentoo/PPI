# This file contains a number of token classes

# The onLineStart and onLineEnd methods are passed the PPI::Tokenizer object
# as an argument. The tokenizer is normally used as $t, for convenience.

# Things to remember
# - return 0 in onLineStart signals to go to the next line

package PPI::Tokenizer::Token::Base;

# The 'Base' class represents the normal default state of the parser.
# That is, the whitespace area 'outside' the code.

use strict;
use base 'PPI::Tokenizer::Token';
use PPI::RegexLib qw{%RE};

sub onLineStart {
	my $t = $_[1];
	
	# Can we classify the entire line in one go
	# This is heavily dependant on PPI::RegexLib
	$_ = $t->{line_buffer};
	if ( /$RE{perl}{line}{pod}/ ) {
		# A Pod tag... change to pod mode
		$t->newToken( 'Pod', $t->{line_buffer} ) or return undef;
		if ( $1 eq 'cut' ) {
			# This is an error, but one we'll ignore
			# Don't go into Pod mode, since =cut normally
			# signals the end of Pod mode
		} else {
			$t->setClass( 'Pod' ) or return undef;
		}
		$t->{stats}->{lines}->{pod}++;		
		return 0;

	} elsif ( /$RE{perl}{line}{blank}/ ) {
		# A whitespace line
		$t->newToken( 'Base', $t->{line_buffer} ) or return undef;
		$t->{stats}->{lines}->{whitespace}++;
		return 0;

	} elsif ( /$RE{perl}{line}{comment}/ ) {
		# Add the comment token, and finalize it immediately
		$t->newToken( 'Comment', $_ ) or return undef;
		$t->{token}->tag( 'line' );
		$t->finalizeToken or return undef;
		$t->{stats}->{lines}->{comment}++;
		return 0;
	
	} elsif ( /^\s*__(END|DATA)__\s*$/ ) {
		# Preprocessor end of file signal
		if ( $1 eq 'END' ) {
			# Content off the end of the file
			$t->newToken( 'End', $t->{line_buffer} );
			$t->setClass( 'End' );
			$t->setZone( 'End' );
			return 0;
		} else {
			# Data at the end of the file
			$t->newToken( 'Data', $t->{line_buffer} );
			$t->setClass( 'Data' );
			$t->setZone( 'Data' );
			return 0;
		}
	}
	
	# Not a special line, continue as normal
	$t->{stats}->{lines}->{code}++;
	return 1;
}

use vars qw{%charMap};
BEGIN {
	%charMap = (
		"'" => 'Quote::Single',
		'"' => 'Quote::Double',
		'`' => 'Quote::Execute',
		';' => 'Structure',
		'{' => 'Structure',
		'}' => 'Structure',
#		'(' => 'Structure', Alternate behaviours, see below
		')' => 'Structure',
		'[' => 'Structure',
		']' => 'Structure',
		',' => 'Operator',
		'*' => 'Unknown',
		'$' => 'Unknown',
		'@' => 'Unknown',
		'&' => 'Unknown',
		'=' => 'Operator',
		'?' => 'Operator',
		':' => 'Unknown',
		'-' => 'Unknown',
		'#' => 'Comment',
		'|' => 'Operator',
		'+' => 'Operator',
		'%' => 'Unknown',
		'\\' => 'Cast',
#		'/' => 'Operator',   Alternate behaviours, see below
		'>' => 'Operator',
		'<' => 'Operator',
		'.' => 'Operator',
		'!' => 'Operator',
		'_' => 'Bareword',
		'~' => 'Operator',
		);
	
	# Add the alphanumericals to cut down on regexs,
	# and hopefully speed things up a little.
	$charMap{$_} = 'Bareword' foreach ( 'a' .. 'z' );
	$charMap{$_} = 'Bareword' foreach ( 'A' .. 'Z' );
	$charMap{$_} = 'Number' foreach ( 0 .. 9 );
}
sub onChar {
	my $t = $_[1];
	$_ = $t->{char};
	
	if ( exists $charMap{$_} ) {
		return $charMap{$_};
		
	} elsif ( $_ eq '(' ) {
		# Is this the beginning of a sub prototype?\
		# We are a sub prototype IF
		# 1. The previous significant token is a bareword.
		# 2. The one before that is the word 'sub'.
		# 3. The one before that is a 'structure'
		
		# Get the three previous significant tokens
		my $tokens = $t->previousSignificantTokens( 3 );
		if ( $tokens
		     and $tokens->[0]->{class} eq 'Bareword'
		     and $tokens->[1]->is_a( 'Bareword', 'sub' )
		     and (
		 	$tokens->[2]->{class} eq 'Structure'
		 	or $tokens->[2]->is_a( 'Bareword', '' )
		     )
		) {
			# This is a sub prototype
			return 'SubPrototype';
		} else {
			# This is a normal open bracket
			return 'Structure';
		}
		
	} elsif ( $_ eq '/' ) {
		# This is either a "divided by" or a "start regex"
		# Do some context stuff to guess ( ack ) which.
		# Hopefully the guess will be good enough.
		my $previous = $t->lastSignificantToken;
		
		# Explicit regex
		return 'Regex::Match' if $previous->is_a( 'Operator', '=~' );
		return 'Regex::Match' if $previous->is_a( 'Operator', '!~' );
		return 'Regex::Match' if $previous->is_a( 'Operator', '!' );

		# After a symbol 
		return 'Operator' if $previous->is_a( 'Symbol' );
		return 'Operator' if $previous->is_a( 'Structure', ']' );
		return 'Operator' if $previous->is_a( 'Structure', '}' );
		
		# After another number
		return 'Operator' if $previous->is_a( 'Number' );
		
		# After going into scope/brackets
		return 'Regex::Match' if $previous->is_a( 'Structure', '(' );
		return 'Regex::Match' if $previous->is_a( 'Structure', '{' );
	
		# Functions that use regexs as an argument
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'split' );
	
		# After a keyword
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'if' );
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'unless' );		
		return 'Regex::Match' if $previous->is_a( 'Bareword', 'grep' );
		
		# Otherwise... erm... assume operator?
		# I expect we will have to add more tests here
		return 'Operator';
	} else {
		return 'Base';
	}
}


	


#####################################################################
# POD

package PPI::Tokenizer::Token::Pod;

use strict;
use base 'PPI::Tokenizer::Token';

# Import the regex
use PPI::RegexLib qw{%RE};

sub onLineStart {
	my $t = $_[1];
	
	# Add the line to the token
	$t->{token}->add( $t->{line_buffer} );
	
	# Check the line to see if it is a =cut line
	$_ = $t->{line_buffer};
	if ( /$RE{perl}{line}{pod}/ ) {
		if ( lc $1 eq 'cut' ) {
			# End of the token
			$t->finalizeToken;
		}
	}
	
	# Next line
	return 0;
}			





#####################################################################
# After the __DATA__ tag

package PPI::Tokenizer::Token::Data;

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar { 1 }




#####################################################################
# After the __END__ tag

package PPI::Tokenizer::Token::End;

use strict;
use base 'PPI::Tokenizer::Token';
use PPI::RegexLib qw{%RE};

sub onChar { 1 }

sub onLineStart {
	my $t = $_[1];
	
	# Can we classify the entire line in one go
	# This is heavily dependant on PPI::RegexLib
	$_ = $t->{line_buffer};
	if ( /$RE{perl}{line}{pod}/ ) {
		# A Pod tag... change to pod mode
		$t->newToken( 'Pod', $_ ) or return undef;
		if ( $1 eq 'cut' ) {
			# This is an error, but one we'll ignore
			# Don't go into Pod mode, since =cut normally
			# signals the end of Pod mode
		} else {
			$t->setClass( 'Pod' ) or return undef;
		}
		$t->{stats}->{lines}->{pod}++;		
	} else {
		if ( defined $t->{token} ) {
			$t->{token}->{content} .= $t->{line_buffer};
		} else {
			$t->newToken( 'End', $t->{line_buffer} );
		}
	}
	return 0;
}





#####################################################################
# Comments

package PPI::Tokenizer::Token::Comment;

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar { 1 }

# Comments end at the end of the line
sub onLineEnd {
	my $t = $_[1];
	if ( defined $t->{token} ) {
		$t->finalizeToken() or return undef;
	}
	return 1;
}
	
sub tag {
	my $self = shift;
	foreach my $tag ( @_ ) {
		$self->{tags}->{$tag} = 1;
	}
	return 1;
}



#####################################################################
# Bareword

package PPI::Tokenizer::Token::Bareword;

use strict;
use base 'PPI::Tokenizer::Token';

# Import the regex
use PPI::RegexLib qw{%RE};

use vars qw{$quotelike};
BEGIN {
	$quotelike = {		
		'q'  => 'Quote::OperatorSingle',
		'qq' => 'Quote::OperatorDouble',
		'qx' => 'Quote::OperatorExecute',
		'qw' => 'Quote::Words',
		'qr' => 'Quote::Regex',
		'm'  => 'Regex::Match',
		's'  => 'Regex::Replace',
		'tr' => 'Regex::Transform',
		'y'  => 'Regex::Transform',
		};
}
sub onChar {
	my $class = shift;
	my $t = shift;
	
	# Is the new character from the bareword
	$_ = $t->{char};
	return 1 if /[a-zA-Z0-9_:]/;
	
	# Check for a quote like operator
	my $bareword = $t->{token}->{content};
	if ( $quotelike->{$bareword} ) {
		# Turn it into the appropriate class
		$t->setTokenClass( $quotelike->{$bareword} );
	
	} elsif ( $PPI::Tokenizer::Token::Operator::operators->{$bareword} ) {
	 	# Turn it into an operator
	 	$t->setTokenClass( 'Operator' );
	 	
	} else {
		# Normal bareword. Finalize it
		$t->finalizeToken();
	}
	return $t->onChar();
}

	

#####################################################################
# Characters used to create heirachal structure

package PPI::Tokenizer::Token::Structure;

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar {
	my $class = shift;
	my $t = shift;
	$t->finalizeToken() or return undef;
	return $t->onChar();
}





#####################################################################
# A number

package PPI::Tokenizer::Token::Number;

# We should eventually be able to support the following ( from perlnumber )
#
#    $n = 1234;       # decimal integer
#    $n = 0b1110011;  # binary integer
#    $n = 01234;      # octal integer
#    $n = 0x1234;     # hexadecimal integer
#    $n = 12.34e-56;  # exponential notation
#
# We currently support decimal, real, and octal ( by accident :) )

use strict;
use base 'PPI::Tokenizer::Token';

# Using a hash is faster than a regex for detecting things
use vars qw{%numbers %hexidecimal};
BEGIN {
	%numbers = ();
	%hexidecimal = ();
	$numbers{$_} = 1 foreach 0 .. 9;
	$hexidecimal{$_} = 1 foreach 0 .. 9;
	$hexidecimal{$_} = 1 foreach 'a' .. 'f';
	$hexidecimal{$_} = 1 foreach 'A' .. 'F';
}

sub onChar {
	my $class = shift;
	my $t = shift;
	my $char = $t->{char};
	
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
		} elsif ( $numbers{ $char } ) {
			$token->{_subtype} = 'octal';
			return 1;
		} elsif ( $char eq '.' ) {
			return 1;
		} else {
			# End of the number... it's just 0
			$t->finalizeToken();
			return $t->onChar();
		}
	}

	if ( ! $token->{_subtype} or $token->{_subtype} eq 'base256' ) {
		# Handle the easy case, integer or real.
		return 1 if $numbers{$char};

		if ( $char eq '.' ) {
			if ( $token->{content} =~ /\.$/ ) {
				# We have a .., which is an operator.
				# Take the . off the end of the token..
				# and finish it, then make the .. operator.
				chop $t->{token}->{content};
				$t->newToken( 'Operator', '..' ) or return undef;
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
			return $class->andError( "Illegal 9 in octal number" );
		}
		
		# Any other number is ok
		return 1 if $numbers{$char};
	
	} elsif ( $token->{_subtype} eq 'hex' ) {
		return 1 if $hexidecimal{$char};
		
		# Error on other word chars
		if ( $char =~ /\w/ ) {
			return $class->andError( "Illegal character in hexidecimal" );
		}
				
	} elsif ( $token->{_subtype} eq 'binary' ) {
		# Does anyone use this?
		if ( $char eq '1' or $char eq '0' ) {
			return 1;
		}
		
		# Other bad characters
		if ( $char =~ /[\w\d]/ ) {
			return $class->andError( "Illegal character in binary number" );
		}

	} else {
		return $class->andError( "Unknown number type '$token->{_subtype}'" );
	}
	
	# Doesn't fit a special case, or is in the token.
	# End of token.
	$t->finalizeToken();
	return $t->onChar();	
}





#####################################################################
# Symbol

package PPI::Tokenizer::Token::Symbol;

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar {
	my $class = shift;
	my $t = shift;
	
	# Is the new character from the bareword
	$_ = $t->{char};
	return 1 if /[a-zA-Z0-9_:']/;

	# Check for magic
	my $content = $t->{token}->{content};
	if ( $content eq '@_'
	  or $content eq '$_'
	  # or $content eq       # etc
	) {
		$t->setTokenClass( 'Magic' );
	}
	
	$t->finalizeToken() or return undef;
	return $t->onChar();
}
	



#####################################################################
# An array index thingy

package PPI::Tokenizer::Token::ArrayIndex;

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar {
	my $class = shift;
	my $t = shift;
	
	# Is the new character from the bareword
	$_ = $t->{char};
	return 1 if /[a-zA-Z0-9_:]/;
	
	# End of token
	$t->finalizeToken() or return undef;
	return $t->onChar();
}





#####################################################################
# Operator 

package PPI::Tokenizer::Token::Operator;

use strict;
use base 'PPI::Tokenizer::Token';

use vars qw{$operators};
INIT {
	# Make the operator index.
	# Comma added seperately to avoid warning
	$operators = PPI::Tokenizer->makeIndex( qw{
		-> ++ -- ** ! ~ + - 
		=~ !~ * / % x + - . << >> 
		< > <= >= lt gt le ge
		== != <=> eq ne cmp
		& | ^ && || .. ...
		? : = += -= *= .=
		=> 
		and or not
		}, ',' );
	
}		
sub onChar {
	my $class = shift;
	my $t = shift;
	if ( $operators->{ $t->{token}->{content} . $t->{char} } ) {
		return 1;
	} else {
		# Handle weird operator options
		if ( $t->{token}->{content} eq '<<'
		 and $t->{char} =~ /[a-zA-Z_'"]/ 
		) {
			# OK, so this is a raw input string type thing.
			# Finalize the operator under a different class...
			$t->setTokenClass( 'RawInput::Operator' );
			$t->finalizeToken() or return undef;

			# ... and add a marker to the multiline input queue
			push @{ $t->{rawinput_queue} }, $#{ $t->{tokens} };
			
			# to signal that we need to be looked at at the end
			# of the line.
			
			# Now deal with what will ( hopefully )be either a 
			# normal single quoted string, or a bareword, normally.
			return $t->onChar();
			
		} else {
			# Handle normally
			$t->finalizeToken() or return undef;
			return $t->onChar();
		}
	}
}

# Method for other packages to use
sub isAnOperator { $operators->{$_[1]} }




#####################################################################
# Magic variable

package PPI::Tokenizer::Token::Magic;

use strict;
use base 'PPI::Tokenizer::Token';

# Import the regexs
use PPI::RegexLib qw{%RE};

use vars qw{%magic};
BEGIN {
	# Magic variables taken from perlvar.
	# Several things added seperately to avoid warnings.
	foreach ( qw{
		$1 $2 $3 $4 $5 $6 $7 $8 $9 
		$_ $& $` $' $+ @+ $* $. $/ $|
		$\\ $" $; $% $= $- @- $)
		$~ $^ $: $? $! $@ $$ $< $> $(
		$0 $[ $]
		
		$^L $^A $^E $^C $^D $^F $^H 
		$^I $^M $^O $^P $^R $^S $^T
		$^V $^W $^X
	}, '$,', '$#' ) {
		$magic{$_} = 1;
	}		
}
sub onChar {
	my $class = shift;
	my $t = shift;
	my $current = $t->{token}->{content};
	$_ = $t->{char};
	
	# If you are here, you are one of the above magic vars.
	# Some will need special parse rules. Let's do them now.
	if ( $current eq '$_' and /$RE{CLASS}/ ) {
		# It's actually a normal symbol
		$t->setTokenClass( 'Symbol' );
		return 1;
	}
	if ( $current eq '$^' and /[A-Z]/ ) {
		# It's an escaped char magic... maybe
		return 1;
	} 
	if ( $current eq '$$' ) {
		if ( /$RE{SYMBOL}{FIRST}/ ) {
			# This is really a referenced scalar ref.
			# Add the current token as the cast...
			$t->{token}->{content} = '$';
			$t->setTokenClass( 'Cast' );
			$t->finalizeToken();
			
			# ... and create a new token for the symbol
			$t->newToken( 'Symbol', '$' ) or return undef;
			return 1;
		}	
	}
	if ( $current eq '$#' ) {
		if ( /$RE{SYMBOL}{FIRST}/ ) {
			# This is really an array index thingy
			$t->setTokenClass( 'ArrayIndex' );
			return 1;
		}
	}
	if ( $current eq '$:' ) {
		if ( $_ eq ':' ) {
			# This is really a $::foo style symbol
			$t->setTokenClass( 'Symbol' );
			return 1;
		}
	}

	# Normal magic token finished
	$t->finalizeToken();
	return $t->onChar();
}





#####################################################################
# Casting operator

package PPI::Tokenizer::Token::Cast;

use strict;
use base 'PPI::Tokenizer::Token';

# A cast is always a single character
sub onChar {
	my $class = shift;
	my $t = shift;
	$t->finalizeToken() or return undef;
	return $t->onChar();
}





#####################################################################
# Subroutine prototype descriptor

package PPI::Tokenizer::Token::SubPrototype;

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar {
	my $class = shift;
	my $t = shift;
	
	# Keep going until we find a close round bracket ')'.
	# We can use the fast _scanForCharacter for this.
	my $string = $class->_scanForCharacterOnThisLine( $t, ')' );
	return undef unless defined $string;
	
	# Finish off the token
	$t->{token}->{content} .= $string;
	$t->finalizeToken();
	
	# Go to the next character
	return 0;
}

# Scan for a single character on the same line.
# Expect to find something after a low number of characters.
sub _scanForCharacterOnThisLine {
	my $class = shift;
	my $t = shift;
	my $lookFor = shift;
	
	### FIXME - Why can't we do this as a regex match?
	# There's something you can do with manipulating 
	# match positions, using a magic global...
	
	# Loop as long as we can get new lines
	my $start = $t->{line_position};
	my $line = $t->{line_buffer};
	for ( my $p = $start; $p < length($line); $p++ ) {
		if ( substr( $line, $p, 1 ) eq $lookFor ) {
			# Correct incorrect state
			$t->{line_position} = $p;
			$t->{char} = substr( $line, $p, 1 );
			
			# Done, return the string
			return substr( $line, $start, ($p - $start + 1) )
		}
	}
	
	# End of the line, we should have found this by now
	return $class->andError( "Sub prototype pattern not terminated by end of line" );
}




#####################################################################
# A Dashed Bareword    -likethis

package PPI::Tokenizer::Token::DashedBareword;

# This should be a string... but I'm still musing

use strict;
use base 'PPI::Tokenizer::Token';

sub onChar {
	my $class = shift;
	my $t = shift;
	$_ = $t->{char};
	
	# Does it look more like a dashed bareword
	if ( /\w+/ ) {
		return 1;
	} else {
		# Finish the dashed bareword
		$t->setTokenClass( 'Bareword' ) or return undef;
		$t->finalizeToken() or return undef;
		return $t->onChar();
	}
}





#####################################################################
# All the quote and quote likes

# Single Quote
package PPI::Tokenizer::Token::Quote::Single;
use base 'PPI::Tokenizer::Quote::Simple';
sub DUMMY { 1 }
	
# Double Quote
package PPI::Tokenizer::Token::Quote::Double;
use base 'PPI::Tokenizer::Quote::Simple';
sub DUMMY { 1 }

# Back Ticks
package PPI::Tokenizer::Token::Quote::Execute;
use base 'PPI::Tokenizer::Quote::Simple';
sub DUMMY { 1 }

# Single Quote
package PPI::Tokenizer::Token::Quote::OperatorSingle;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }
	
# Double Quote
package PPI::Tokenizer::Token::Quote::OperatorDouble;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Back Ticks
package PPI::Tokenizer::Token::Quote::OperatorExecute;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Quote Words
package PPI::Tokenizer::Token::Quote::Words;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Quote Regex Expression
package PPI::Tokenizer::Token::Quote::Regex;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Operator or Non-Operator Match Regex
package PPI::Tokenizer::Token::Regex::Match;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Operaator Pattern Regex
package PPI::Tokenizer::Token::Regex::Pattern;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Replace Regex
package PPI::Tokenizer::Token::Regex::Replace;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }

# Transform regex
package PPI::Tokenizer::Token::Regex::Transform;
use base 'PPI::Tokenizer::Quote::Full';
sub DUMMY { 1 }





#####################################################################
# Classes to support multi-line inputs

package PPI::Tokenizer::Token::RawInput::Operator;
use strict;
use base 'PPI::Tokenizer::Token';
sub dummy { 1 }

package PPI::Tokenizer::Token::RawInput::Terminator;
use strict;
use base 'PPI::Tokenizer::Token';
sub dummy { 1 }

package PPI::Tokenizer::Token::RawInput::String;
use strict;
use base 'PPI::Tokenizer::Token';
sub dummy { 1 }

1;
