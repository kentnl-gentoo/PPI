package PPI::Token::Symbol;

# A symbol

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.829';
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

# Returns the normalised, canonical symbol.
# For example, converts '$ ::foo'bar::baz' to '$main::foo::bar::baz'
# However, this does not resolve the symbol
sub canonical {
	my $symbol = shift->content;
	$symbol =~ s/\s+//;
	$symbol =~ s/(?<=[\$\@\%\&\*])::/main::/;
	$symbol =~ s/\'/::/g;
	$symbol;
}

# Returns the actual symbol this token refers to.
# A token of '$foo' might actually be refering to '@foo' if there is
# a '[1]' after it. This method attempts to resolve these issues.
sub symbol {
	my $self = shift;
	my $symbol = $self->canonical;

	# Immediately return the cases where it can't be anything else
	my $type   = substr( $symbol, 0, 1 );
	return $symbol if $type eq '%';
	return $symbol if $type eq '&';

	# Unless the next significant Element is a structure, it's correct.
	my $after  = $self->snext_sibling;
	return $symbol unless isa( $after, 'PPI::Structure' );

	# Process the rest for cases where it might actually be somethign else
	my $braces = $after->braces;
	return $symbol unless defined $braces;
	if ( $type eq '$' ) {
		return substr( $symbol, 0, 1, '@' ) if $braces eq '[]';
		return substr( $symbol, 0, 1, '%' ) if $braces eq '{}';

	} elsif ( $type eq '@' ) {
		return substr( $symbol, 0, 1, '%' ) if $braces eq '{}';

	}

	$symbol;
}

sub raw_type {
	my $self = shift;
	substr( $self->content, 0, 1 );
}

sub symbol_type {
	my $self = shift;
	substr( $self->symbol, 0, 1 );
}

1;
