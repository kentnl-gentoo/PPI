package PPI::Tokenizer::Token::Unknown;

# This large, seperate class is used when we have a limited
# number of characters that could yet mean a variety of
# different things.
#
# All the unknown cases are character by character problems,
# so this class only needs to implement onChar()

use strict;
use base 'PPI::Tokenizer::Token';

# Import the regexs
use PPI::RegexLib qw{%RE};

sub onChar {
	my $class = shift;
	my $t = shift;                  # Tokenizer object
	my $c = $t->{token}->{content}; # Current token contents
	$_ = $t->{char};                # Current character


	# Now, we split on the different values of the current content
	
	
	if ( $c eq '*' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->setTokenClass( 'Symbol' ) or return undef;
			return 1;
		}
		
		if ( $_ eq '{' or $_ eq '$' ) {
			# GLOB cast
			$t->setTokenClass( 'Cast' ) or return undef;
			$t->finalizeToken();
			return $t->onChar();

		} else {
			$t->setTokenClass( 'Operator' ) or return undef;
			$t->finalizeToken();
			return $t->onChar();
		}		
	
	
	
	} elsif ( $c eq '$' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ ) {
			$t->setTokenClass( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( $PPI::Tokenizer::Token::Magic::magic{ $t->{token}->{content} . $_ } ) {
			# Magic variable
			$t->setTokenClass( 'Magic' ) or return undef;
			return 1;
			
		} else {
			# It can't be anything other than a cast now...?
			$t->setTokenClass( 'Cast' ) or return undef;
			$t->finalizeToken() or return undef;
			return $t->onChar();
		}		
		
		

	} elsif ( $c eq '@' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->setTokenClass( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( /-+/ ) {
			# Magic variable
			$t->setTokenClass( 'Magic' ) or return undef;
			return 1;
		
		} else {
			# Can this be anything other than a cast...?
			$t->setTokenClass( 'Cast' ) or return undef;
			$t->finalizeToken() or return undef;
			return $t->onChar();
		}		



	} elsif ( $c eq '%' ) {
		# Is it a symbol?	
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->setTokenClass( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( /[\$@%{]/ ) {
			# Percent is a cast
			$t->setTokenClass( 'Cast' ) or return undef;
			$t->finalizeToken() or return undef;
			return $t->onChar();
			
		} else {
			# The mod operator?
			$t->setTokenClass( 'Operator' ) or return undef;
			return $t->onChar();
		}



	} elsif ( $c eq '&' ) {
		# Is it a symbol
		if ( /$RE{SYMBOL}{FIRST}/ or $_ eq ':' ) {
			$t->setTokenClass( 'Symbol' ) or return undef;
			return 1;
			
		} elsif ( /[\$@%{]/ ) {
			# And is a cast...?
			$t->setTokenClass( 'Cast' ) or return undef;
			$t->finalizeToken() or return undef;
			return $t->onChar();

		} else {
			# Operator?
			$t->setTokenClass( 'Operator' ) or return undef;
			return $t->onChar();
		}



	} elsif ( $c eq '-' ) {
		# Is it a number
		if ( /\d/ ) {
			$t->setTokenClass( 'Number' ) or return undef;
			return 1;
			
		} elsif ( /[a-zA-Z]/ ) {
			$t->setTokenClass( 'DashedBareword' ) or return undef;
			return 1;
			
		} else {
			$t->setTokenClass( 'Operator' ) or return undef;
			return $t->onChar();
		}



	} elsif ( $c eq ':' ) {
		if ( $_ eq ':' ) {
			# ::foo style bareword
			$t->setTokenClass( 'Bareword' ) or return undef;
			return 1;
		
		} else {
			# It's an operator
			$t->setTokenClass( 'Operator' ) or return undef;
			return $t->onChar();
		}



	} else {
		### erm... shit
		die 'Unknown value in PPI::Tokenizer::Token::Unknown token';

	}
}

1;
