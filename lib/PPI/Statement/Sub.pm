package PPI::Statement::Sub;

# Subroutine declaration for forward declaration

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.823';
}

# Lexer clue
sub __LEXER__normal { '' }





#####################################################################
# PPI::Statement::Sub analysis methods

sub name {
	my $self = shift;

	# The second token should be the name, if we have one
	my $Token = $self->schild(1) or return undef;
	$Token->is_a('Bareword') ? $Token->content : undef;
}

# If we don't have a block at the end, this is a forward declaration
sub forward {
	my $self = shift;
	! $self->schild(-1)->isa('PPI::Structure::Block');
}

1;
