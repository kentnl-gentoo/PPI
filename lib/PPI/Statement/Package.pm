package PPI::Statement::Package;

# A package declaration

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.829';
}

sub namespace {
	my $self = shift;
	my $namespace = $self->child(1) or return '';
	isa($namespace, 'PPI::Token::Word') ? $namespace->content : '';
}

1;
