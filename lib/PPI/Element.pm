package PPI::Element;

=pod

=head1 NAME

PPI::Element - The abstract Element class, a base for all source objects

=head1 INHERITANCE

  PPI::Base
  isa PPI::Element

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
use overload 'bool' => sub () { 1 },
             '""'   => 'content',
             '=='   => '__equals',
             'eq'   => '__eq';
             

use vars qw{$VERSION %_PARENT};
BEGIN {
	$VERSION = '0.841';

	# Master Child -> Parent index
	%_PARENT = ();
}





#####################################################################
# General Properties

=pod

=head2 significant

Because we treat whitespace and other non-code items as Tokens (in order to
be able to "round trip" the PPI::Document back to a file) the C<significant>
method allows us to distinguish between tokens that form a part of the code,
and tokens that arn't significant, such as whitespace, POD, or the portion
of a file after (and including) the __END__ token.

=cut

sub significant { 1 }

=pod

=head2 tokens

The C<tokens> method returns a list of PPI::Token objects for the
Element, essentially getting back that part of the document as if it had not
been lexed.

This also means there are no Statements and no Structures in the list, just
the Token classes.

=cut

sub tokens { $_[0] }

=pod

=head2 content

For B<any> PPI::Element, the C<content> method will reconstitute the raw source
code for it as a single string. This method is also the method used for
overloading stringification. When an Element is used in a double-quoted string
for example, this is the method that is called.

Returns the code as a string, or C<undef> on error.

=cut

sub content { defined $_[0]->{content} ? $_[0]->{content} : '' }





#####################################################################
# Naigation Methods

=pod

=head2 parent

Elements themselves are not intended to contain other Elements, that is left
to the L<PPI::Node|PPI::Node> abstract class, a subclass of PPI::Element.
However, all Elements can be contained B<within> a parent Node.

If an Element is within a parent Node, the C<parent> method returns the Node.

=cut

sub parent { $_PARENT{refaddr shift} }

=pod

=head2 statement

For a PPI::Element that is contained (at some depth) within a PPI::Statment,
the C<statement> method will return the first parent Statement object
lexically 'above' the Element.

Returns a L<PPI::Statement|PPI::Statement> object, which may be the same
Element if the Element is itself a PPI::Statement object. Returns false
if the Element is not within a Statement and is not itself a Statement.

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

For a PPI::Element that is contained within a PDOM tree, the C<top> method
will return the top-level Node in the tree. Most of the time this should be
a L<PPI::Document> object, however this will not always be so. For example,
if a subroutine has been removed from its Document, to be moved to another
Document.

Returns the top-most PDOM object, which may be the same Element, if it is
not within any parent PDOM object.

=cut

sub top {
	my $cursor = shift;
	while ( my $parent = $_PARENT{refaddr $cursor} ) {
		$cursor = $parent;
	}
	$cursor;
}

=pod

For an Element that is contained within a L<PPI::Document> object,
the C<document> method will return the top-level Document for the Element.

Returns the PPI::Document for this Element, or false if the Element is not
contained within a Document.

=cut

sub document {
	my $top = shift->top;
	isa($top, 'PPI::Document') and $top;
}

=cut

=pod

=head2 next_sibling

All L<PPI::Node> objects (specifically, our parent Node) contain a number of
PPI::Element objects. The C<next_sibling> method returns the PPI::Element
immediately after the current one, or false if there is no next sibling.

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

All L<PPI::Node> objects (specifically, our parent Node) contain a number of
PPI::Element objects. The C<previous_sibling> method returns the Element
immediately before the current one, or false if there is no 'previous'
PPI::Element object.

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

=head2 first_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<first_token> method finds the first
PPI::Token object within or equal to this one.

That is, if called on a L<PPI::Node> subclass, it will descend until it
finds a L<PPI::Token>. If called on a PPI::Token object, it will return the
same object.

Returns a PPI::Token object, or dies on error (which should be extremely rare
and only occur if an illegal empty L<PPI::Statement|PPI::Structure> exists
below the current Element somewhere.

=cut

sub first_token {
	my $cursor = shift;
	while ( $cursor->isa('PPI::Node') ) {
		$cursor = $cursor->first_element
			or die "Found empty PPI::Node while getting first token";
	}
	$cursor;
}


=pod

=head2 last_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<last_token> method finds the last
PPI::Token object within or equal to this one.

That is, if called on a L<PPI::Node> subclass, it will descend until it
finds a L<PPI::Token>. If called on a PPI::Token object, it will return the
itself.

Returns a L<PPI::Token> object, or dies on error (which should be extremely rare
and only occur if an illegal empty L<PPI::Statement|PPI::Structure> exists
below the current Element somewhere.

=cut

sub last_token {
	my $cursor = shift;
	while ( $cursor->isa('PPI::Node') ) {
		$cursor = $cursor->last_element
			or die "Found empty PPI::Node while getting first token";
	}
	$cursor;
}

=pod

=head2 next_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<next_token> method finds the PPI::Token
object that is immediately after the current Element, even if it is not within
the same parent L<PPI::Node|PPI::Node> as the one for which the method is
being called.

Note that this is B<not> defined as a PPI::Token-specific method, because it
can be useful to find the next token that is after, say, a
L<PPI::Statement|PPI::Statement>, although obviously it would be useless to
want the next token after a L<PPI::Document|PPI::Document>.

Returns a PPI::Token object, or false if there are no more token after
the Element.

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
	###       using it in a slightly unsafe context. Again though, in
	###       the class structure as of the time this method was written,
	###       this is safe.
	while ( ! isa($Element, 'PPI::Token') ) {
		defined($Element = $Element->first_element) or return '';
	}

	$Element;
}

=pod

=head2 previous_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<previous_token> method finds the
PPI::Token object that is immediately before the current Element, even if it
is not within the same parent L<PPI::Node|PPI::Node> as this one.

Note that this is not defined as a PPI::Token-only method, because it can be
useful to find the token is before, say, a PPI::Statement, although
obviously it would be useless to want the next token before a  PPI::Document

Returns a PPI::Token object, or false if there are no more tokens before
the Element.

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
an Element object. In the generic case, the implementation is done using
the Clone module's mechanism itself. In higher-order cases, such as for
Nodes, there is more work involved to keep the parent-child links intact.

=cut

BEGIN {
	Clone->import('clone');
}

=pod

=head2 insert_before @Elements

The C<insert_before> method allows you to insert lexical perl content, in
the form of PPI::Element objects, before the calling Element. You need to be
very careful when modifying perl code, as it's easy to break things.

B<This method is not yet implemented, mainly due to the difficulty in making
it Do What You Mean.>

=cut

sub insert_before {
	die "The ->insert_before method has not been implemented";
}

# The internal version, which trusts the data we are given
sub _insert_before {
	my $self = shift;
	
}

=pod

=head2 insert_after @Elements

The C<insert_after> method allows you to insert lexical perl content, in
the form of PPI::Element objects, after the calling Element. You need to be
very careful when modifying perl code, as it's easy to break things.

B<This method is not yet implemented, mainly due to the difficulty in making
it Do What You Mean.>

=cut

sub insert_after {
	die "The ->insert_after method has not been implemented";
}

# The internal version, which trusts the data we are given
sub _insert_after {
	my $self = shift;
	
}

=pod

=head2 remove

For a given PPI::Element, the C<remove> method will remove it from its
parent B<intact>, along with all of its children.

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

For a given Element, the C<remove> method will remove it from its
parent, immediately deleting the Element and all of its children (if it has
any).

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

=head2 replace $Element

Although some higher level class support more exotic forms of replace,
at the basic level the C<replace> method takes a single Element as
an argument and replaces the current Element with it.

To prevent accidental damage to code, in this initial implementation the
replacement element MUST be of exactly the same class as the one being
replaced.

=cut

sub replace {
	my $self = ref $_[0] ? shift : return undef;
	my $Element = isa(ref $_[0], ref $self) ? shift : return undef;

	die "CODE INCOMPLETE";
}

=pod

=head2 location

If the Element exists within a L<PPI::Document|PPI::Document> that has
indexed the Element locations using C<PPI::Document::index_locations>, the
C<location> method will return the location of the first character of the
Element within the Document.

Returns the location as a reference to a two-element array in the form
C<[ $line, $col ]>. The values are in a human format, with the first
character of the file located at C<[ 1, 1 ]>. Returns C<undef> on error,
or if the PPI::Document object has not been indexed.

=cut

sub location {
	my $self = shift;
	my $line = $self->_line or return undef; # Can never be 0
	my $col  = $self->_col  or return undef; # Can never be 0
	[ $line, $col ];
}

# Although flush_locations is only publically a Document-level method,
# we are able to implement it at an Element level, allowing us to
# selectively flush only the part of the document that occurs after the
# element for which the flush is called.
sub _flush_location {
	my $self  = shift;
	unless ( $self == $self->top ) {
		return $self->top->_flush_location( $self );
	}

	# Get the full list of all Tokens
	my @Tokens = $self->tokens;

	# Optionally allow starting from an arbitrary element (or rather,
	# the first Token equal-to-or-within an arbitrary element)
	if ( isa($_[0], 'PPI::Element') ) {
		my $start = shift->first_token;
		while ( my $Token = shift @Tokens ) {
			return 1 unless $Token->{_location};
			next unless refaddr($Token) == refaddr($start);

			# Found the start. Flush it's location
			delete $$Token->{_location};
			last;
		}
	}

	# Iterate over any remaining Tokens and flush their location
	foreach my $Token ( @Tokens ) {
		delete $_->{_location};
	}

	1;
}





# These should be implemented in the subclasses
sub _line { undef }
sub _col  { undef }





#####################################################################
# Internals

# Being DESTROYed in this manner, rather than by an explicit
# ->delete means our reference count has probably fallen to zero.
# Therefore we don't need to remove ourselves from our parent,
# just the index ( just in case ).
sub DESTROY { delete $_PARENT{refaddr shift} }

# Operator overloads
sub __equals { ref $_[1] and refaddr($_[0]) == refaddr($_[1]) }
sub __eq {
	my $self  = isa(ref $_[0], 'PPI::Element') ? shift->content : shift;
	my $other = isa(ref $_[0], 'PPI::Element') ? shift->content : shift;
	$self eq $other;
}

1;

=head1 TO DO

It would be nice if C<location> could be used in an ad-hoc manner. That is,
if called on an Element within a Document that has not been indexed, it will
do a one-off calculation to find the location. It might be very painful if
someone started using it a lot, without remembering to index the document,
but it would be handy for things that are only likely to use it once, such
as error handlers.

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
