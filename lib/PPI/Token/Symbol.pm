package PPI::Token::Symbol;

# A symbol

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.825';
}

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

# Returns the normalised, canonical symbol name.
# For example, converts '$ ::foo'bar::baz' to '$main::foo::bar::baz'
sub canonical {
	my $self = shift;
	my $name = $self->content;
	$name =~ s/\s+//;
	$name =~ s/(?<=[\$\@\%\&\*])::/main::/;
	$name =~ s/\'/::/g;
	$name;
}

1;
