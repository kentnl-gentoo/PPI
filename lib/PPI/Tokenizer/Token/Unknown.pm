package PPI::Tokenizer::Token::Unknown;

# This large, seperate class is used when we have a limited
# number of characters that could yet mean a variety of
# different things.
#
# All the unknown cases are character by character problems,
# so this class only needs to implement on_char()

use strict;
use base 'PPI::Tokenizer::Token';

# Import the regexs
use PPI::RegexLib qw{%RE};

sub on_char {
	my $class = shift;
	my $t = shift;                  # Tokenizer object
	my $c = $t->{token}->{content}; # Current token contents
	$_ = $t->{char};                # Current character


	# Now, we split on the different values of the current content
	
	
	if ( $c eq '*' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->_set_token_class( 'Symbol' ) or return undef;
			return 1;
		}
		
		if ( $_ eq '{' or $_ eq '$' ) {
			# GLOB cast
			$t->_set_token_class( 'Cast' ) or return undef;
			$t->_finalize_token();
			return $t->on_char();

		} else {
			$t->_set_token_class( 'Operator' ) or return undef;
			$t->_finalize_token();
			return $t->on_char();
		}		
	
	
	
	} elsif ( $c eq '$' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ ) {
			$t->_set_token_class( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( $PPI::Tokenizer::Token::Magic::magic{ $t->{token}->{content} . $_ } ) {
			# Magic variable
			$t->_set_token_class( 'Magic' ) or return undef;
			return 1;
			
		} else {
			# It can't be anything other than a cast now...?
			$t->_set_token_class( 'Cast' ) or return undef;
			$t->_finalize_token() or return undef;
			return $t->on_char();
		}		
		
		

	} elsif ( $c eq '@' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->_set_token_class( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( /-+/ ) {
			# Magic variable
			$t->_set_token_class( 'Magic' ) or return undef;
			return 1;
		
		} else {
			# Can this be anything other than a cast...?
			$t->_set_token_class( 'Cast' ) or return undef;
			$t->_finalize_token() or return undef;
			return $t->on_char();
		}		



	} elsif ( $c eq '%' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->_set_token_class( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( /[\$@%{]/ ) {
			# Percent is a cast
			$t->_set_token_class( 'Cast' ) or return undef;
			$t->_finalize_token() or return undef;
			return $t->on_char();
			
		} else {
			# The mod operator?
			$t->_set_token_class( 'Operator' ) or return undef;
			return $t->on_char();
		}



	} elsif ( $c eq '&' ) {
		# Is it a symbol
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->_set_token_class( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( /[\$@%{]/ ) {
			# And is a cast...?
			$t->_set_token_class( 'Cast' ) or return undef;
			$t->_finalize_token() or return undef;
			return $t->on_char();

		} else {
			# Operator?
			$t->_set_token_class( 'Operator' ) or return undef;
			return $t->on_char();
		}



	} elsif ( $c eq '-' ) {
		# Is it a number
		if ( /\d/ ) {
			$t->_set_token_class( 'Number' ) or return undef;
			return 1;
			
		} elsif ( /[a-zA-Z]/ ) {
			$t->_set_token_class( 'DashedBareword' ) or return undef;
			return 1;
			
		} else {
			$t->_set_token_class( 'Operator' ) or return undef;
			return $t->on_char();
		}



	} elsif ( $c eq ':' ) {
		if ( $_ eq ':' ) {
			# ::foo style bareword
			$t->_set_token_class( 'Bareword' ) or return undef;
			return 1;
		
		} else {
			# It's an operator
			$t->_set_token_class( 'Operator' ) or return undef;
			return $t->on_char();
		}



	} else {
		### erm... shit
		die 'Unknown value in PPI::Tokenizer::Token::Unknown token';

	}
}

1;
