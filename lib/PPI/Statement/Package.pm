package PPI::Statement::Package;

# A package declaration

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.825';
}

sub namespace {
	my $self = shift;
	my $namespace = $self->child(1) or return '';
	isa($namespace, 'PPI::Token::Bareword') ? $namespace->content : '';
}

1;
