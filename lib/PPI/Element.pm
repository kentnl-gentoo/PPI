package PPI::Element;

=pod

=head1 NAME

PPI::Element - The abstract Element class, a base for all source objects

=head1 INHERITANCE

  PPI::Base
  \--> PPI::Element

=head1 DESCRIPTION

The abstract PPI::Element serves as a base class for all source-related
objects, from a single whitespace token to an entire document. It provides
a basic set of methods to provide a common interface and basic
implementations.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use Scalar::Util 'refaddr';
use base 'PPI::Base';
use PPI::Node       ();
use Clone           ();
use List::MoreUtils ();

use vars qw{$VERSION %_PARENT};
BEGIN {
	$VERSION = '0.823';

	# Master Child -> Parent index
	%_PARENT = ();
}





#####################################################################
# General Properties

=pod

=head2 significant

Because we treat whitespace and other non-code items as tokens (in order to
be able to "round trip" the PPI::Document back to a file) the C<significant>
allows us to distinguish between tokens that form a part of the code, and
tokens that arn't significant, such as whitespace, POD, or the portion of 
a file after the __END__ token.

=cut

sub significant { 1 }

=pod

=head2 tokens

The C<tokens> method returns a flat list of PPI::Token object for the
PPI::Element, essentially undoing the lexing of the document.

=cut

sub tokens { $_[0] }

=pod

=head2 content

For ANY PPI::element, the C<content> method will reconstitute the raw source
code for it as a single string.

Returns the code as a string, or C<undef> on error.

=cut

sub content { defined $_[0]->{content} ? $_[0]->{content} : '' }





#####################################################################
# Naigation Methods

=pod

=head2 parent

Elements themselves are not intended to contain other elements, that is left
to the L<PPI::Node|PPI::Node> abstract class, a subclass of PPI::Element.
However, all elements can be contained within a higher ::Node object.

If an ::Element object is within a ::Node, the C<parent> method returns the
patent ::Node object.

=cut

sub parent { $_PARENT{refaddr shift} }

=pod

=head2 top

For an PPI::Element that is contained within other ::Elements,
the C<top> method will return the top-level ::Element in the tree that this
is part of.

Returns the top-most PPI::Element object, which may be the same PPI::Element
if it is not within any other ::Elements.

=cut

sub top {
	my $self = shift;
	my $cursor = $self;
	while ( my $parent = $_PARENT{refaddr $cursor} ) {
		$cursor = $parent;
	}
	$cursor;
}

=pod

For a PPI::Element that is contained within a PPI::Document object,
the C<top> method will return the top-level Document for the Element.

Returns the PPI::Document for this Element, or false if the Element is not
contained within a Document.

=cut

sub document {
	my $self = shift;
	my $top  = $self->top;
	isa($top, 'PPI::Document') ? $top : '';
}

=cut

=pod

=head2 next_sibling

All ::Node objects contain a number of ::Elements. The C<next_sibling>
method returns the ::Element immediately after it, false if there is no
next ::Element, or C<undef> if the ::Element does not have a parent ::Node,
or some other error occurs.

=cut

sub next_sibling {
	my $self     = shift;
	my $parent   = $self->parent or return '';
	my $key      = refaddr $self;
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @{$parent->{elements}};
	$parent->{elements}->[$position + 1] || '';
}

=pod

=head2 previous_sibling

All ::Node objects contain a number of ::Elements. The C<previous_sibling>
method returns the ::Element immediately before it, false if there is no
previous ::Element, or C<undef> if the ::Element does not have a parent
::Node, or some other error occurs.

=cut

sub previous_sibling {
	my $self     = shift;
	my $parent   = $self->parent or return '';
	my $key      = refaddr $self;
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @{$parent->{elements}};
	$position and $parent->{elements}->[$position - 1] or '';
}





#####################################################################
# Manipulation

=pod

=head2 clone

As per the Clone module, the C<clone> method makes a perfect copy of
an Element object. In the generic case, the implemtation if done using
the Clone module's mechanism itself.

=cut

use Clone 'clone';

=pod

=head2 remove

For a given PPI::Element, the C<remove> method will remove it from it's
parent INTACT, along with all of it's children.

Returns the Element itself as a convenience, or C<undef> if an error
occurs while trying to remove the Element.

=cut

sub remove {
	my $self = ref $_[0] ? shift : return undef;
	my $parent = $self->parent or return $self;
	$parent->remove_child( $self );
}

=pod

=head2 delete

For a given PPI::Element, the C<remove> method will remove it from it's
parent, deleting the Element and all of it's children.

Returns true if the Element was successfully deleted, or C<undef> if
an error occurs while trying to remove the Element.

=cut

sub delete {
	my $self = ref $_[0] ? shift : return undef;
	$self->remove or return undef;
	$self->DESTROY;
	1;
}

=pod

=head2 location

If the Element exists within a L<PPI::Document|PPI::Document> that has
indexed the Element locations, the C<location> method will return the
location of the Element.

Returns the location as a reference to a two-element array in the form
C<[ $line, $col ]>. The values are in a human format, with the first
character of the file located at C<[ 1, 1 ]>. Returns undef on error,
or if the PPI::Document object has not been indexed.

=cut

sub location {
	my $self = shift;
	my $line = $self->_line or return undef; # Can never be 0
	my $col  = $self->_col  or return undef; # Can never be 0
	[ $line, $col ];
}

# These should be implemented in the subclasses
sub _line { undef }
sub _col  { undef }

# Being DESTROYed in this manner, rather than by an explicit
# ->delete means our reference count has probably fallen to zero.
# Therefore we don't need to remove ourselves from our parent,
# just the index ( just in case ).
sub DESTROY { delete $_PARENT{refaddr shift} }

1;
