package PPI::Token::Prototype;

# Subroutine prototype

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.900';
}

sub _on_char {
	my $class = shift;
	my $t = shift;

	# Suck in until we find the closing bracket (or the end of line)
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(.*?(?:\)|$))/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Finish off the token and process the next char
	$t->_finalize_token->_on_char( $t );
}

sub prototype {
	my $self = shift;
	my $prototype = $self->content;
	$prototype =~ s/\(\)\s//g; # Strip brackets and whitespace
	$prototype;
}

1;
