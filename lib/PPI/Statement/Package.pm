package PPI::Statement::Package;

=pod

=head1 NAME

PPI::Statement::Package - A package statement

=head1 INHERITANCE

  PPI::Statement::Package
  is a PPI::Statement
  is a PPI::Node
  is a PPI::Element
  is a PPI::Base

=head1 DESCRIPTION

Most L<PPI::Statement|PPI::Statement> subclasses are assigned based on the
value of the first token or word found in the statement. When PPI encounters
a statement starting with 'package', it converts it to a
PPI::Statement::Package object.

When working with package statements, please remember that packages only
exist within their scope, and proper support for scoping has yet to be
completed in PPI.

However, if the immediate parent of the package statement is the
top level L<PPI::Document|PPI::Document> object, then it can be considered
to define everything found until the next top-level "file scoped" package
statement.

A file may, however, contain nested temporary package, in which case you
are mostly on your own :)

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.845';
}

=pod

=head2 namespace

Most package declarations are simple, and just look something like

  package Foo::Bar;

The C<namespace> method returns the name of the declared package, in the
above case 'Foo::Bar'. It returns this exactly as written and does not
attempt to clean up or resolve things like ::Foo to main::Foo.

If the package statement is done any different way, it returns false.

=cut

sub namespace {
	my $self = shift;
	my $namespace = $self->child(1) or return '';
	isa($namespace, 'PPI::Token::Word') ? $namespace->content : '';
}

=pod

=head2 file_scoped

Regardless of whether it is named or not, the C<file_scoped> method will
test to see if the package declaration is a top level "file scoped"
statement or not, based on its location.

In general, returns true if it is a "file scoped" package declaration with
an immediate parent of the top level Document, or false if not.

Note that if the PPI DOM tree B<does not> have a PPI::Document object at
as the root element, this will return false. Likewise, it will also return
false if the root element is a L<PPI::Document::Fragment>, as a fragment of
a file does not represent a scope.

=cut

sub file_scoped {
	my $self     = shift;
	my ($Parent, $Document) = ($self->parent, $self->top);
	$Parent and $Document and $Parent == $Document
	and isa($Document, 'PPI::Document')
	and ! isa($Document, 'PPI::Document::Fragment');
}

1;

=pod

=head1 TO DO

- Write unit tests for this package

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main PPI Manual

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

Thank you to Phase N (L<http://phase-n.com/>) for permitting
the open sourcing and release of this distribution.

=head1 COPYRIGHT

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
