package PPI::Token::ArrayIndex;

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.900';
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

1;
