package PPI::Node;

=pod

=head1 NAME

PPI::Node - Abstract PPI Node class, an Element that can contain other Elements

=head1 INHERITANCE

  PPI::Base
  \--> PPI::Element
       \--> PPI::Node

=head1 SYNOPSIS

  # Create a typical node (a Document in this case)
  my $Node = PPI::Document->new;
  
  # Add an element to the node( in this case, a token )
  my $Token = PPI::Token::Word->new('my');
  $Node->add_element( $Token );
  
  # Get the elements for the Node
  my @elements = $Node->children;
  
  # Find all the barewords within a Node
  my @barewords = $Node->find( 'PPI::Token::Word' );
  
  # Find by more complex criteria
  my @my_tokens = $Node->find( sub { $_[1]->content eq 'my' } );
  
  # Remove all the whitespace
  $Node->prune( 'PPI::Token::Whitespace' );
  
  # Remove by more complex criteria
  $Node->prune( sub { $_[1]->content eq 'my' } );

=head1 DESCRIPTION

The PPI::Node class privides an abstract base class for the Element classes
that are able to contain other elements, L<PPI::Document|PPI::Document>,
L<PPI::Statement|PPI::Statement>, and L<PPI::Structure|PPI::Structure>.

As well as those listed below, all of the methods that apply to
L<PPI::Element|PPI::Element> objects also apply to PPI::Node objects.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Element';
use Scalar::Util 'refaddr';
use List::MoreUtils ();

use vars qw{$VERSION *_PARENT};
BEGIN {
	$VERSION = '0.828';
	*_PARENT = *PPI::Element::_PARENT;
}





#####################################################################
# The basic constructor

sub new {
	my $class = ref $_[0] || $_[0];
	bless { children => [] }, $class;
}





#####################################################################
# Public tree related methods

=pod

=head2 add_element $Element

The C<add_element> method adds a PPI::Element object to the end of a
PPI::Node. Because Elements maintain links to their parent, an
Element can only be added to a single Node.

Returns true if the PPI::Element was added. Returns C<undef> if the
Element was already within another Node, or the method is not passed 
a PPI::Element object.

=cut

sub add_element {
	my $self = shift;

	# Check the element
	my $Element = isa($_[0], 'PPI::Element') ? shift : return undef;
	$_PARENT{refaddr $Element} and return undef;

	# Add the argument to the elements
	push @{$self->{children}}, $Element;
	$_PARENT{refaddr $Element} = $self;

	1;
}

# In a typical run profile, add_element is the number 1 resource drain.
# This is a highly optimised unsafe version, for internal use only.
sub __add_element {
	push @{($_PARENT{refaddr $_[1]} = $_[0])->{children}}, $_[1];
}

=pod

=head2 elements

The C<elements> method accesses all child elements B<structurally> within
the PPI::Node object. Note that in the base of the PPI::Structure classes,
this C<DOES> include the brace tokens at either end of the structure.

Returns a list of zero or more PPI::Element objects.

Alternatively, if called in the scalar context, the C<elements> method
returns a count of the number of elements.

=cut

sub elements {
	wantarray ? @{$_[0]->{children}} : scalar @{$_[0]->{children}};
}

=pod

=head2 first_element

The C<first_element> method accesses the first element structurally within
the PPI::Node object. As for the C<elements> method, this does include the
brace tokens for PPI::Structure objects.

Returns a PPI::Element object, or C<undef> if for some reason the PPI::Node
object does not contain any elements.

=cut

# Normally the first element is also the first child
sub first_element {
	$_[0]->{children}->[0];
}

=pod

=head2 last_element

The C<last_element> method accesses the last element structurally within
the PPI::Node object. As for the C<elements> method, this does include the
brace tokens for PPI::Structure objects.

Returns a PPI::Element object, or C<undef> if for some reason the PPI::Node
object does not contain any elements.

=cut

# Normally the last element is also the last child
sub last_element {
	$_[0]->{children}->[-1];
}

=pod

=head2 children

The C<children> method accesses all child elements lexically within the
PPI::Node object. Note that in the case of the PPI::Structure classes, this
does B<NOT> include the brace tokens at either end of the structure.

Returns a list of zero of more PPI::Element objects.

Alternatively, if called in the scalar context, the C<children> method
returns a count of the number of lexical children.

=cut

# In the default case, this is the same as for the elements method
sub children {
	wantarray ? @{$_[0]->{children}} : scalar @{$_[0]->{children}};
}

=pod

=head2 schildren

The C<schildren> method is really just a convenience, the significant-only
variation of the normal C<children> method.

In list context, returns a list of significant children. In scalar context,
returns the number of significant children.

=cut

sub schildren {
	my $self = shift;
	my @schildren = grep { $_->significant } $self->children;
	wantarray ? @schildren : scalar(@schildren);
}

=pod

=head2 child $index

The C<child> method accesses a child PPI::Element object by it's
position within the Node.

Returns a PPI::Element object, or C<undef> if there is no child
element at that node.

=cut

sub child {
	$_[0]->{children}->[$_[1]];
}

=pod

=head2 schild $index

The lexical structure of the Perl language ignores 'insignificant' items,
such as whitespace and comments, while PPI treats these items as valid
tokens so that it can reassemble the file at any time. Because of this,
in many situations there is a need to find an Element within a Node by
index, only counting lexically significant Elements.

The C<schild> method returns a child Element by index, ignoring
insignificant Elements. The index of a child Element is specified in the
same way as for a normal array, with the first Element at index 0, and
negative indexes used to identify a "from the end" position.

=cut

sub schild {
	my $self = shift;
	my $idx  = 0 + shift;
	unless ( defined $self->{children} ) {
		$DB::single = 1;
	}
	my @el   = @{$self->{children}};
	if ( $idx < 0 ) {
		my $cursor = 0;
		while ( exists $el[--$cursor] ) {
			return $el[$cursor] if $el[$cursor]->significant and ++$idx >= 0;
		}
	} else {
		my $cursor = -1;
		while ( exists $el[++$cursor] ) {
			return $el[$cursor] if $el[$cursor]->significant and --$idx < 0;
		}
	}
	undef;
}

=pod

=head2 contains $Element

The C<contains> method is used to determine if another PPI::Element object
is logically "within" a PPI::Node. For the special case of the brace tokens
at either side of a PPI::Structure object, they are generally considered
"within" a PPI::Structure object, even if they are not actually in the
elements for the PPI::Structure.

Returns true if the PPI::Element is within us, false if not, or C<undef>
on error.

=cut

sub contains {
	my $self = shift;
	my $Element = isa($_[0], 'PPI::Element') ? shift : return undef;

	# Iterate up the Element's parent chain until we either run out
	# of parents, or get to ourself.
	while ( $Element = $Element->parent ) {
		return 1 if refaddr($self) == refaddr($Element);
	}

	'';
}

=pod

=head2 find $class | \&condition

The C<find> method is used to search within a code tree for PPI::Element
objects that meet a particular condition. To specify the condition, the
method can be provided with either a simple class name, or an anonymous
subroutine.

The anonymous subroutine will be passed two arguments, the top-level
Node being searched within and the current Element that the condition is
testing. The anonymous subroutine should return a simple true/false
value incating match or no match.

The C<find> method returns a reference to an array of PPI::Element object
that match the condition, false if no Elements match the condition, or
C<undef> if an error occurs during the search process.

=cut

sub find {
	my $self = shift;
	my $condition = $self->_condition(shift) or return undef;

	# Use a queue based search, rather than a recursive one
	my @found = ();
	my @queue = $self->children;
	while ( my $Element = shift @queue ) {
		push @found, $Element if &$condition( $self, $Element );

		# Depth-first keeps the queue size down and provides a
		# better logical order.
		if ( $Element->isa('PPI::Structure') ) {
			unshift @queue, $Element->finish if $Element->finish;
			unshift @queue, $Element->children;
			unshift @queue, $Element->start if $Element->start;
		} elsif ( $Element->isa('PPI::Node') ) {
			unshift @queue, $Element->children;
		}
	}

	@found ? \@found : '';
}

=pod

=head2 find_any $class | \&condition

The C<find_any> is a short-circuiting true/false method that behaves like
the normal C<find> method, but returns true as soon as it finds any Elements
that match the search condition.

See the C<find> method for details on the format of the search condition.

Returns true if any Elements that match the condition can be found, false if
not, or C<undef> if given an invalid condition, or an error occurs.

=cut

sub find_any {
	my $self = shift;
	my $condition = $self->_condition(shift) or return undef;

	# Use a queue based search, rather than a recursive one
	my @queue = $self->children;
	while ( my $Element = shift @queue ) {
		return 1 if &$condition( $self, $Element );

		# Depth-first keeps the queue size down and provides a
		# better logical order.
		if ( $Element->isa('PPI::Structure') ) {
			unshift @queue, $Element->finish if $Element->finish;
			unshift @queue, $Element->children;
			unshift @queue, $Element->start if $Element->start;
		} elsif ( $Element->isa('PPI::Node') ) {
			unshift @queue, $Element->children;
		}
	}

	'';
}

=pod

=head2 remove_child $Element

If passed a L<PPI::Element|PPI::Element> object that is a direct child of
the Node, the C<remove_element> method will remove the Element intact,
along with any of it's children. As such, this method acts essentially as
a lexical 'cut' function.

=cut

sub remove_child {
	my $self  = shift;
	my $child = isa($_[0], 'PPI::Element') ? shift : return undef;

	# Find the position of the child
	my $key      = refaddr $child;
	my $position = List::MoreUtils::firstidx { refaddr $_ == $key } @{$self->{children}};
	return undef unless defined $position;

	# Splice it out, and remove the child's parent entry
	splice( @{$self->{children}}, $position, 1 );
	delete $_PARENT{refaddr $child};

	# Return the child as a convenience
	$child;
}

=pod

=head2 prune $class | \&condition

The C<prune> method is used to strip PPI::Element objects out of a code tree.
The argument is the same as for the C<find> method, either a class name, or
an anonymous subroutine which returns true/false. Any Element that matches
the class|condition will be deleted from the code tree, along with any
of it's children.

The C<prune> method returns the number of Element objects that matched and
were removed, B<NOT> including the child Elements of those that matched
the condition. This might also be zero, so avoid a simple true/false test
on the return false of the C<prune> method. It returns C<undef> on error,
which you probably B<SHOULD> test for.

=cut

sub prune {
	my $self = shift;
	my $condition = $self->_condition(shift) or return undef;

	# Use a depth-first queue search
	my $pruned = 0;
	my @queue = $self->children;
	while ( my $element = shift @queue ) {
		if ( &$condition( $self, $element ) ) {
			# Delete the child
			$element->delete or return undef;
			$pruned++;
		} elsif ( isa($element, 'PPI::Node') ) {
			# Depth-first keeps the queue size down
			unshift @queue, $element->children;
		}
	}

	$pruned;
}

sub _condition {
	my $self = shift;
	my $it   = defined $_[0] ? shift : return undef;

	# conditions should normally be CODE refs
	return $it if ref $it eq 'CODE';

	# Looking for a particular catagory of elements
	if ( ! ref and isa( $it, 'PPI::Element' ) ) {
		my $code = eval "sub { UNIVERSAL::isa( \$_[1], '$it' ) }";
		return (ref $code eq 'CODE') ? $code : undef;
	}

	undef;
}





####################################################################
# PPI::Element overloaded methods

sub tokens {
	map { $_->tokens } @{$_[0]->{children}}
}

sub content {
	join '', map { $_->content } @{$_[0]->{children}}
}

# Clone as normal, but then go down and relink all the _PARENT entries
sub clone {
	my $self = shift;
	my $clone = $self->SUPER::clone;

	# Relink all our children ( depth first )
	my @queue = ( $clone );
	while ( my $Node = shift @queue ) {
		# Link our immediate children
		foreach my $Element ( @{$Node->{children}} ) {
			$_PARENT{refaddr($Element)} = $Node;
			unshift @queue, $Element if isa($Element, 'PPI::Node');
		}

		# If it's a structure, relink the open/close braces
		next unless isa($Node, 'PPI::Structure');
		$_PARENT{refaddr($Node->start)}  = $Node if $Node->start;
		$_PARENT{refaddr($Node->finish)} = $Node if $Node->finish;
	}

	$self;
}


sub _line {
	my $self = shift;
	my $first = $self->{children}->[0] or return undef;
	$first->_line;
}

sub _col {
	my $self = shift;
	my $first = $self->{children}->[0] or return undef;
	$first->_col;
}

sub DESTROY {
	if ( $_[0]->{children} ) {
		my @queue = $_[0];
		while ( defined($_ = shift @queue) ) {
			unshift @queue, @{delete $_->{children}} if $_->{children};

			# Remove all internal/private weird crosslinking so that
			# the cascading DESTROY calls will get called properly.
			%$_ = ();
		}
	}

	# Remove us from our parent node as normal
	delete $_PARENT{refaddr $_[0]};
}

1;

=pod

=head1 TO DO

Not much left to do here, by and large this can be considered stable.

Most additional methods are being added on-demand.

=head1 SUPPORT

See the L<support section|PPI::Manual/SUPPORT> in the main PPI Manual

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Thank you to Phase N (L<http://phase-n.com/>) for permitting
the open sourcing and release of this distribution.

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
