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
use overload '=='   => '__equals';
use overload 'eq'   => '__eq';
use overload 'bool' => sub () { 1 };

use vars qw{$VERSION %_PARENT};
BEGIN {
	$VERSION = '0.828';

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

=head2 statement

For a PPI::Element that is contained (at some depth) within a PPI::Statment,
the C<statement> method will return the first parent PPI::Statement object
'above' the PPI::Element.

Returns a L<PPI::Statement|PPI::Statement> object, which may be the same
PPI::Element if the element is itself a PPI::Statement object. Returns false
if the Element is not within a PPI::Statement, or is not itself a
PPI::Statement.

=cut

sub statement {
	my $cursor = shift;
	while ( ! isa($cursor, 'PPI::Statement') ) {
		$cursor = $_PARENT{refaddr $cursor} or return '';
	}
	$cursor;
}

=pod

=head2 top

For a PPI::Element that is contained within other ::Elements,
the C<top> method will return the top-level ::Element in the tree that this
is part of.

Returns the top-most PPI::Element object, which may be the same PPI::Element
if it is not within any other ::Elements.

=cut

sub top {
	my $cursor = shift;
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
	my $top = shift->top;
	isa($top, 'PPI::Document') ? $top : '';
}

=cut

=pod

=head2 next_sibling

All PPI::Node objects contain a number of PPI::Elements. The C<next_sibling>
method returns the PPI::Element immediately after the current one, or false
if there is no next sibling.

=cut

sub next_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	$elements->[$position + 1] || '';
}

=cut

=pod

=head2 snext_sibling

As per the other 's' methods, the C<snext_sibling> method returns the next
B<significant> sibling of the PPI::Element object.

Returns a PPI::Element object, or false if there is no 'next' significant
sibling.

=cut

sub snext_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	while ( defined(my $it = $elements->[++$position]) ) {
		return $it if $it->significant;
	}
	'';
}

=pod

=head2 previous_sibling

All PPI::Node objects contain a number of PPI::Element object. The
C<previous_sibling> method returns the PPI::Element immediately before the
current one, or false if there is no previous PPI::Element object.

=cut

sub previous_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	$position and $elements->[$position - 1] or '';
}

=pod

=head2 sprevious_sibling

As per the other 's' methods, the C<sprevious_sibling> method returns
the previous B<significant> sibling of the PPI::Element object.

Returns a PPI::Element object, or false if there is no 'previous' significant
sibling.

=cut

sub sprevious_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	while ( defined(my $it = $elements->[--$position]) ) {
		return $it if $it->significant;
	}
}

=pod

=head2 next_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<next_token> method finds the PPI::Token
object that is immediately after the current PPI::Element object, even if it
is not within the same parent PPI::Node object as this one.

Note that this is not defined as a PPI::Token-only method, because it can be
useful to find the next token that is after, say, a PPI::Statement, although
obviously it would be useless to want the next token after a PPI::Document.

Returns a PPI::Token object, or false if there are no more tokens after
the PPI::Element.

=cut

sub next_token {
	my $cursor = shift;

	# Start with the next Element. Go up via our parents if needed.
	my $Element;
	while ( defined($Element = $cursor->next_sibling) ) {
		$cursor = $_PARENT{refaddr $cursor} or return '';
	}

	# If the Element is not itself a Token, work our way downwards
	# through the first child of each level till we find one
	### Note: There's a few potential problems with this part of the
	###       algorithm, but it will be safe as long as PPI::Token
	###       is the ONLY class to inherit from PPI::Element other
	###       than PPI::Node. This is because first_element is really
	###       a PPI::Node method, NOT a PPI::Element method, so we are
	###       using it in a slightly unsafe context.
	while ( ! isa($Element, 'PPI::Token') ) {
		defined($Element = $Element->first_element) or return '';
	}

	$Element;
}

=pod

=head2 previous_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<previous_token> method finds the
PPI::Token object that is immediately before the current PPI::Element object,
even if it is not within the same parent PPI::Node object as this one.

Note that this is not defined as a PPI::Token-only method, because it can be
useful to find the token is before, say, a PPI::Statement, although
obviously it would be useless to want the next token before a  PPI::Document

Returns a PPI::Token object, or false if there are no more tokens before
the PPI::Element.

=cut

sub previous_token {
	my $cursor = shift;

	# Start with the next Element. Go up via our parents if needed.
	my $Element;
	while ( defined($Element = $cursor->previous_sibling) ) {
		$cursor = $_PARENT{refaddr $cursor} or return '';
	}

	# If the Element is not itself a Token, work our way downwards
	# through the last child of each level till we find one
	while ( ! isa($Element, 'PPI::Token') ) {
		defined($Element = $Element->last_element) or return '';
	}

	$Element;
}





#####################################################################
# Manipulation

=pod

=head2 clone

As per the Clone module, the C<clone> method makes a perfect copy of
an Element object. In the generic case, the implementation if done using
the Clone module's mechanism itself.

=cut

BEGIN {
	Clone->import('clone');
}

=pod

=head2 insert_before @Elements

The C<insert_before> method allows you to insert lexical perl content, in
the form of PPI::Element objects, before the calling Element. You need to be
very careful when modifying perl code, as it's easy to break things.

This method is not yet implemented, mainly due to the difficulty in making
it just DWYM.

=cut

sub insert_before {
	die "The ->insert_before method has not been implemented";
}

# The internal version, which trust the data we are given
sub _insert_before {
	my $self = shift;
	
}

=pod

=head2 insert_after @Elements

The C<insert_after> method allows you to insert lexical perl content, in
the form of PPI::Element objects, before the calling Element. You need to be
very careful when modifying perl code, as it's easy to break things.

This method is not yet implemented, mainly due to the difficulty in making
it just DWYM.

=cut

sub insert_after {
	die "The ->insert_after method has not been implemented";
}

# The internal version, which trust the data we are given
sub _insert_after {
	my $self = shift;
	
}

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

# Operator overloads
sub __equals { ref $_[1] and refaddr $_[0] == refaddr $_[1] }
sub __eq {
	my $self  = isa(ref $_[0], 'PPI::Element') ? shift->content : shift;
	my $other = isa(ref $_[0], 'PPI::Element') ? shift->content : shift;
	$self eq $other;
}

1;
