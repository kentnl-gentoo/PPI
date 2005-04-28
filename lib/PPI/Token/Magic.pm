package PPI::Token::Magic;

# Magic variables

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::Symbol';

use vars qw{$VERSION %magic};
BEGIN {
	$VERSION = '0.906';

	# Magic variables taken from perlvar.
	# Several things added separately to avoid warnings.
	foreach ( qw{
		$1 $2 $3 $4 $5 $6 $7 $8 $9
		$_ $& $` $' $+ @+ $* $. $/ $|
		$\\ $" $; $% $= $- @- $)
		$~ $^ $: $? $! %! $@ $$ $< $>
		$( $0 $[ $] @_ @*

		$^L $^A $^E $^C $^D $^F $^H
		$^I $^M $^N $^O $^P $^R $^S
		$^T $^V $^W $^X

		$::|
	}, '$}', '$,', '$#', '$#+', '$#-' ) {
		$magic{$_} = 1;
	}
}

sub __TOKENIZER__on_char {
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
			$t->_set_token_class('Symbol');
			return PPI::Token::Symbol->__TOKENIZER__on_char( $t );
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
			return $t->_finalize_token->__TOKENIZER__on_char( $t );
		}

		if ( /^(\$\#)\w/ ) {
			# This is really an array index thingy ( $#array )
			$t->{token} = PPI::Token::ArrayIndex->new( $1 );
			return PPI::Token::ArrayIndex->__TOKENIZER__on_char( $t );
		}

		if ( /^\$\^\w/o ) {
			# It's an escaped char magic... maybe ( like $^M )
			return 1;
		}

		if ( /^\$\#\{/ ) {
			# The $# is actually a case, and { is its block
			# Add the current token as the cast...
			$t->{token} = PPI::Token::Cast->new( '$#' );
			$t->_finalize_token;

			# ... and create a new token for the block
			$t->_new_token( 'Structure', '{' ) or return undef;
			return 1;
		}
	}

	# End the current magic token, and recheck
	$t->_finalize_token->__TOKENIZER__on_char( $t );
}

# Our version is canonical is much simple
sub canonical { $_[0]->content }

1;
