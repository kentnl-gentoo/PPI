package PPI::Statement::Sub;

# Subroutine declaration for forward declaration

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';
use List::Util ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.829';
}

# Lexer clue
sub __LEXER__normal { '' }





#####################################################################
# PPI::Statement::Sub analysis methods

sub name {
	my $self = shift;

	# The second token should be the name, if we have one
	my $Token = $self->schild(1) or return undef;
	isa($Token, 'PPI::Token::Word') ? $Token->content : '';
}

sub prototype {
	my $self = shift;
	my $Prototype = List::Util::first { isa($_, 'PPI::Token::Prototype') } $self->children;
	defined($Prototype) ? $Prototype->prototype : '';
}

sub block {
	my $self = shift;
	my $lastchild = $self->schild(-1);
	isa($lastchild, 'PPI::Structure::Block') and $lastchild;
}

# If we don't have a block at the end, this is a forward declaration
sub forward {
	! shift->block;
}

1;
