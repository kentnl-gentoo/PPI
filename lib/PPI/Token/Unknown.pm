package PPI::Token::Unknown;

# This large, seperate class is used when we have a limited
# number of characters that could yet mean a variety of
# different things.
#
# All the unknown cases are character by character problems,
# so this class only needs to implement _on_char()

use strict;
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.829';
}





sub _on_char {
	my $t = $_[1];                                    # Tokenizer object
	my $c = $t->{token}->{content};                   # Current token contents
	$_ = substr( $t->{line}, $t->{line_cursor}, 1 );  # Current character


	# Now, we split on the different values of the current content


	if ( $c eq '*' ) {
		if ( /(?:[^\W\d]|\:)/ ) {
			# Symbol
			return $t->_set_token_class( 'Symbol' ) ? 1 : undef;
		}

		if ( $_ eq '{' or $_ eq '$' ) {
			# GLOB cast
			$t->_set_token_class( 'Cast' ) or return undef;
			return $t->_finalize_token->_on_char( $t );
		}

		$t->_set_token_class( 'Operator' ) or return undef;
		return $t->_finalize_token->_on_char( $t );



	} elsif ( $c eq '$' ) {
		if ( /[a-z_]/i ) {
			# Symbol
			return $t->_set_token_class( 'Symbol' ) ? 1 : undef;
		}

		if ( $PPI::Token::Magic::magic{ $c . $_ } ) {
			# Magic variable
			return $t->_set_token_class( 'Magic' ) ? 1 : undef;
		}

		# Must be a cast
		$t->_set_token_class( 'Cast' ) or return undef;
		return $t->_finalize_token->_on_char( $t );



	} elsif ( $c eq '@' ) {
		if ( /[\w:]/ ) {
			# Symbol
			return $t->_set_token_class( 'Symbol' ) ? 1 : undef;
		}

		if ( /[\-\+\*]/ ) {
			# Magic variable
			return $t->_set_token_class( 'Magic' ) ? 1 : undef;
		}

		# Must be a cast
		$t->_set_token_class( 'Cast' ) or return undef;
		return $t->_finalize_token->_on_char( $t );



	} elsif ( $c eq '%' ) {
		# Is it a symbol?
		if ( /[\w:]/ ) {
			return $t->_set_token_class( 'Symbol' ) ? 1 : undef;
		}

		if ( /[\$@%{]/ ) {
			# It's a cast
			$t->_set_token_class( 'Cast' ) or return undef;
			return $t->_finalize_token->_on_char( $t );

		}

		# Probably the mod operator
		$t->_set_token_class( 'Operator' ) or return undef;
		return $t->{class}->_on_char( $t );



	} elsif ( $c eq '&' ) {
		# Is it a symbol
		if ( /[\w:]/ ) {
			return $t->_set_token_class( 'Symbol' ) ? 1 : undef;
		}

		if ( /[\$@%{]/ ) {
			# The ampersand is a cast
			$t->_set_token_class( 'Cast' ) or return undef;
			return $t->_finalize_token->_on_char( $t );
		}

		# Probably the binary and operator
		$t->_set_token_class( 'Operator' ) or return undef;
		return $t->{class}->_on_char( $t );



	} elsif ( $c eq '-' ) {
		if ( /\d/o ) {
			# Number
			return $t->_set_token_class( 'Number' ) ? 1 : undef;
		}

		if ( /[a-zA-Z]/ ) {
			return $t->_set_token_class( 'Quote::Dashed' ) ? 1 : undef;
		}

		# The numeric negative operator
		$t->_set_token_class( 'Operator' ) or return undef;
		return $t->{class}->_on_char( $t );



	} elsif ( $c eq ':' ) {
		if ( $_ eq ':' ) {
			# ::foo style bareword
			return $t->_set_token_class( 'Word' ) ? 1 : undef;
		}

		# Now, : acts very very differently in different contexts.
		# Mainly, we need to find out if this is a subroutine attribute.
		# We'll leave a hint in the token to indicate that, if it is.
		if ( $_[0]->_is_an_attribute( $t ) ) {
			# This : is an attribute indicator
			$t->_set_token_class( 'Operator' ) or return undef;
			$t->{token}->{_attribute} = 1;
			return $t->_finalize_token->_on_char( $t );
		}

		# It MIGHT be a label, but it's probably the ?: trinary operator
		$t->_set_token_class( 'Operator' ) or return undef;
		return $t->{class}->_on_char( $t );
	}

	### erm...
	die 'Unknown value in PPI::Token::Unknown token';
}

# Are we at a location where a ':' would indicate a subroutine attribute
sub _is_an_attribute {
	my $t = $_[1]; # Tokenizer object
	my $tokens = $t->_previous_significant_tokens( 3 ) or return undef;

	# If we just had another attribute, we are also an attribute
	if ( $tokens->[0]->_isa('Attribute') ) {
		return 1;
	}

	# If we just had a prototype, then we are an attribute
	if ( $tokens->[0]->_isa('Prototype') ) {
		return 1;
	}

	# Other than that, we would need to have had a bareword
	unless ( $tokens->[0]->_isa('Word') ) {
		return '';
	}

	# We could be an anonymous subroutine
	if ( $tokens->[0]->_isa('Word', 'sub') ) {
		return 1;
	}

	# Or, we could be a named subroutine
	if ( $tokens->[1]->_isa('Word', 'sub')
		and ( $tokens->[2]->_isa('Structure')
			or $tokens->[2]->_isa('Whitespace','')
		)
	) {
		return 1;
	}

	# We arn't an attribute
	'';	
}

1;
