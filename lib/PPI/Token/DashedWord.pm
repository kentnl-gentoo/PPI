package PPI::Token::DashedWord;

# Dashed Bareword

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.904';
}

sub __TOKENIZER__on_char {
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
		$t->_set_token_class( 'Word' ) or return undef;
	}

	$t->_finalize_token->__TOKENIZER__on_char( $t );
}

1;
