package PPI::Statement::Variable;

=pod

=head1 NAME

PPI::Statement::Variable - Variable declaration statements

=head1 DESCRIPTION

The main intent of the PPI::Statement::Variable class is to describe
simple statements that explicitly declare new local or global variables.

=head1 METHODS

=cut

# Explicit variable decleration ( my, our, local )

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.841';
}

# What type of variable declaration is it? ( my, local, our )
sub type {
	my $self = shift;

	# Get the children we care about
	my @schild = grep { $_->significant } $self->children;
	shift @schild if isa($schild[0], 'PPI::Token::Label');

	# Get the type
	(isa($schild[0], 'PPI::Token::Word') and $schild[0]->content =~ /^(my|local|our)$/)
		? $schild[0]->content
		: undef;
}

# What are the variables declared
sub variables {
	my $self = shift;

	# Get the children we care about
	my @schild = grep { $_->significant } $self->children;
	shift @schild if isa($schild[0], 'PPI::Token::Label');

	# If the second child is a symbol, return its name
	if ( isa($schild[1], 'PPI::Token::Symbol') ) {
		return $schild[1]->canonical;
	}

	# If it's a list, return as a list
	if ( isa($schild[1], 'PPI::Statement::List') ) {
		my $symbols = $schild[1]->find('PPI::Token::Symbol') or return undef;
		return map { $_->canonical } @$symbols;
	}

	# erm... this is unexpected
	undef;
}

1;
