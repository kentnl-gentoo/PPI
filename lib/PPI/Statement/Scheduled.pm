package PPI::Statement::Scheduled;

# Code that is scheduled to run at a particular time/phase.
# BEGIN/INIT/LAST/END blocks

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.827';
}

sub type {
	my $self = shift;
	my @children = $self->schildren or return undef;
	$children[0]->content eq 'sub'
		? $children[1]->content
		: $children[0]->content;
}

sub __LEXER__normal { '' }

1;
