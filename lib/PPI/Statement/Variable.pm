package PPI::Statement::Variable;

=pod

=head1 NAME

PPI::Statement::Variable - Variable declaration statements

=head1 DESCRIPTION

The main intent of the PPI::Statement::Variable class is to describe
simple statements that explicitly declare new local or global variables.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.903';
}

=pod

=head2 type

The C<type> method checks and returns the declaration type of the statement,
which will be one of either 'my', 'local' or 'our'.

Returns a string or the type, or C<undef> if the type cannot be detected

=cut

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

=pod

=head2 variables

As for several other PDOM Element types that can declare variables, the
C<variables> method returns a list of the canonical forms of the variables
defined by the statement.

Returns a list of the canonical string forms of variables, or the null list
if it is unable to find any variables.

=cut

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
		my $symbols = $schild[1]->find('PPI::Token::Symbol') or return ();
		return map { $_->canonical } @$symbols;
	}

	# erm... this is unexpected
	();
}

1;

=pod

=head1 TO DO

- Write unit tests for this

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
