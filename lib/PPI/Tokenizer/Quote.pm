package PPI::Tokenizer::Quote;

# The PPI::Tokenizer::Quote package is designed hold functionality
# for processing quotes and quote like operators, including regex's.
# These have special requirements in parsing.
# 
# The PPI::Tokenizer::Quote package itself provides various parsing
# methods, which the PPI::Tokenizer::Quote::* and 
# PPI::Tokenizer::Regex::* can inherit from. In this sense, it serves
# as a base class.
# 
# This file also contains the token classes for all the quotes, and
# quote like operators.
#
# To use these, you should initialize them as normal 'Class->new',
# and then call the 'fill' method, which will cause the specialised
# parser to parse the quote to it's end point.
#
# If ->fill returns true, should should then ->_finalize_token to 
# commit the token.

use strict;
use Class::Autouse;

use base 'PPI::Tokenizer::Token';

# Hook for the on_char token call
sub on_char {
	my $class = shift;
	my $t = shift;
	return undef unless $t->{token};
	
	# Call the fill method to process the quote
	my $rv = $t->{token}->fill( $t );
	return undef unless defined $rv;
	
	# Finalize the token
	$t->_finalize_token();
		
	# Done, return 0 to tell the tokenizer to go to the next character
	return 0;
}





#####################################################################
# Optimised character processors, used for quotes 
# and quote like stuff, and accessible to the child classes
#
# More memory to load the code, but hopefully much faster for string 
# processing. These try to drastically cut down the number of
# method calls, which are relatively more expensive.
# 
# I live in hope that someone will replace these will equally accurate
# and super fast regex based methods, but these will do for now.

# An outright scan, raw and fast
sub _scan_for_character {
	my $class = shift;
	my $t = shift;
	my $lookFor = shift;
	my ($line, $len, $p, $rv);
	
	# Loop as long as we can get new lines
	my $string = '';
	my $start = $t->{line_position};
	while ( 1 ) {
		$line = $t->{line_buffer};
		$len = length $line;
		for ( $p = $start; $p < $len; $p++ ) {
			if ( substr( $line, $p, 1 ) eq $lookFor ) {
				# Correct incorrect state
				$t->{line_position} = $p;
				$t->{char} = substr( $line, $p, 1 );
				
				# Done, return the string
				return $string . substr( $line, $start, ($p - $start + 1) )
			}
		}	
		
		# End of line, add it to the string
		$string .= substr( $line, $start );
	
		# Load the next line
		$rv = $t->_fill_next_line;
		unless ( $rv ) {
			# Handle end and error states
			return defined $rv ? \$string : undef;
		}
		$start = 0;
	}
}

# Scan for a character, but not if it is escaped
sub _scan_for_unescaped_character {
	my $class = shift;
	my $t = shift;
	my $lookFor = shift;
	my ($char, $p, $rv, $len, $line);
	
	# Loop as long as we can get new lines
	my $string = '';
	my $start = $t->{line_position};
	while ( 1 ) {
		$line = $t->{line_buffer};
		$len = length $line;
		for ( $p = $start; $p < $len; $p++ ) {
			$char = substr( $line, $p, 1 );
			# Note: When you are using \ as a seperator,
			# don't treat \ as an escape.
			if ( $char eq '\\' and $lookFor ne '\\' ) {
				unless ( $p == $len - 1 ) {
					$p++; # Skip the next char
				}
			} elsif ( $char eq $lookFor ) {
				# Correct incorrect state
				$t->{line_position} = $p;
				$t->{char} = $char;
				
				# Done, return the string
				return $string . substr( $line, $start, ($p - $start + 1) )
			}
		}	
		
		# End of line, add it to the string
		$string .= substr( $line, $start );
	
		# Load the next line
		$rv = $t->_fill_next_line;
		unless ( $rv ) {
			# Handle end and error states
			return defined $rv ? \$string : undef;
		}
		$start = 0;
	}
}

use vars qw{%rightToLeftBrace};
BEGIN {
	%rightToLeftBrace = (
		'>' => '<',
		')' => '(',
		'}' => '{',
		']' => '[',
		);
}

# Scan for a close braced, and take into account both escaping,
# and open close bracket pairs in the string.
sub _scan_for_brace_character {
	my $class = shift;
	my $t = shift;
	my $lookFor = shift;
	my $increment = $rightToLeftBrace{$lookFor} or return undef;
	my ($char, $p, $rv, $len, $line);
	
	# Loop as long as we can get new lines
	my $string = '';
	my $depth = 0;
	my $start = $t->{line_position};	
	while ( 1 ) {
		$line = $t->{line_buffer};
		$len = length($line);
		for ( $p = $start; $p < $len; $p++ ) {
			$char = substr( $line, $p, 1 );
			if ( $char eq '\\' ) {
				unless ( $p == $len - 1 ) {
					$p++; # Skip the next char
				}
			} elsif ( $char eq $increment ) {
				$depth++;
			} elsif ( $char eq $lookFor ) {
				next unless --$depth < 0;
				
				# Fix the processor state
				$t->{line_position} = $p;
				$t->{char} = $char;
				
				# Done, return the string
				return $string . substr( $line, $start, ($p - $start + 1) );
			}
		}	
		
		# End of line, add it to the string
		$string .= substr( $line, $start );
	
		# Load the next line
		$rv = $t->_fill_next_line;
		unless ( $rv ) {
			# Handle end and error states
			return defined $rv ? \$string : undef;
		}
		$start = 0;
	}
}

# Find all spaces and comments, up to, but not including
# the first non-whitespace character.
#
# Although it doesn't return it, it leaves the cursor
# on the character following the gap
sub _scan_quote_like_operator_gap {	
	my $class = shift;
	my $t = shift;
	my ($len, $char, $p, $rv, $line);
	
	# Loop over lines
	my $string = '';
	my $start = $t->{line_position};	
	while ( 1 ) {
		$line = $t->{line_buffer};
		$len = length($line);
		for ( $p = $start; $p < $len; $p++ ) {
			$char = substr( $line, $p, 1 );

			# Go to the next line on comment
			last if $char eq '#';

			if ( $char =~ /\S/ ) {
				# Fix the processor state
				$t->{line_position} = $p;
				$t->{char} = $char;
				
				# Done, return the string
				return $string . substr( $line, $start, ($p - $start) );
			}
		}
		
		# End of line, add it to the string
		$string .= substr( $line, $start );
	
		# Load the next line
		$rv = $t->_fill_next_line;
		unless ( $rv ) {
			# Handle end and error states
			return defined $rv ? \$string : undef;
		}
		$start = 0;
	}
}

1;
