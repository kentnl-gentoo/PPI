package PPI::Statement::Compound;

=pod

=head1 NAME

PPI::Statement::Compound - Describes all compound statements

=head1 INHERITANCE

  PPI::Statement::Compound
  isa PPI::Statement
      isa PPI::Node
          isa PPI::Element

=head1 DESCRIPTION

PPI::Statement::Compound objects are used to describe all current forms of
compound statements, as described in L<perlsyn>.

This covers blocks using C<if>, C<unless>, C<for>, C<foreach>, C<while>, and
C<continue>. Please note this does B<not> cover "simple" statements with
trailing conditions. Please note also that "do" is also not part of a
compound statement.

  # This is NOT a compound statement
  my $foo = 1 if $condition;
  
  # This is also not a compound statement
  do { ... } until $condition;

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION %TYPES};
BEGIN {
	$VERSION = '0.901';

	# Keyword type map
	%TYPES = (
		'if'      => 'if',
		'unless'  => 'if',
		'while'   => 'while',
		'for'     => 'for',
		'foreach' => 'foreach',
		);
}

# Lexer clues
sub __LEXER__normal { '' }





#####################################################################
# PPI::Statement::Compound analysis methods

=pod

=head2 type

The C<type> method returns the fundamental type of the compound statement.

There are three basic compound statement types.

The 'if' type includes all vatiations of the if and unless statements,
including any 'elsif' or 'else' parts of the compount statement.

The 'while' type describes the standard while statement, but again does
B<not> describes simple statements with a trailing while.

The 'for' type covers both of 'for' and 'foreach' statements.

All of the compounds are a variation on one of these three.

Returns the simple string 'if', 'for' or 'while', or C<undef> if the type
cannot be determined.

=cut

sub type {
	my $self    = shift;
	my $Element = $self->schild(0);

	# A labelled statement
	if ( isa($Element, 'PPI::Token::Label') ) {
		$Element = $self->schild(1) or return 'label';
	}

	# Most simple cases
	return $TYPES{$Element->content} if isa($Element, 'PPI::Token::Word');
	return 'continue'                if isa($Element, 'PPI::Structure::Block');

	# Unknown (shouldn't exist?)
	undef;
}

1;

=pod

=head1 TO DO

- Write unit tests for this package

=head1 SUPPORT

See the L<support section|PPI::Manual/SUPPORT> in the PPI Manual

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
