package PPI::Element;

# The abstract parent class for all lexer elements.
# It contains large sections of common code, accessible by all.

use strict;
use base 'PPI::Common';
use Scalar::Util qw{refaddr};

use vars qw{$VERSION %_PARENT};
BEGIN {
	$VERSION = '0.814';
	
	# Child -> Parent links
	%_PARENT = ()
}





#####################################################################
# Tree related code

# Find our parent
sub parent { $_PARENT{ refaddr $_[0] } }

sub previous_sibling {
	my $self = shift;
	my $parent = $self->parent or return '';

	# Find our position
	my $position = $parent->position( $self );
	return undef unless defined $position;

	# Is there a previous?
	$parent->{elements}->[$position - 1] || '';
}

sub next_sibling {
	my $self = shift;
	my $parent = $self->parent or return '';

	# Find our position
	my $position = $parent->position( $self );
	return undef unless defined $position;

	# Is there a next?
	$parent->{elements}->[$position + 1] || '';
}





#####################################################################
# Manipulation

# Remove us from our parent.
# You should be reasonably carefull with this. If you remove something
# in a way that isn't safe ( imagine remove -> from foo->bar ), you will
# break the code.
sub extract {
	my $self = ref $_[0] ? shift : return undef;

	# Do we have a parent
	my $parent = $_PARENT{ refaddr $self } or return 1;

	# Remove us from our parent
	$parent->remove_element( $self );
}

# Deleting an element involves removing ourselves, from our
# parent ( if any ) and then destroying ourself.
sub delete {
	my $self = ref($_[0]) ? shift : return undef;
	my $key = refaddr $self;

	# Do we have a parent
	if ( $_PARENT{$key} ) {
		# Remove from our parent's element array
		$_PARENT{$key}->_remove( $self ) or return undef;

		# Remove the parent index entry
		delete $_PARENT{$key};
	}

	# Delete ourselves in a friendly way.
	$self = {}; undef $self;

	1;
}

# Being DESTROYed in this manner, rather than by an explicit
# ->delete means our reference count has fallen to zero.
# Therefore we don't need to remove ourselves from our parent,
# just the index ( just in case ).
sub DESTROY { delete $_PARENT{ refaddr $_[0] } }





#####################################################################
# Getting information out

# The element's class
sub class { ref $_[0] }

# The element's content
sub content { $_[0]->{content} or '' }

# Returns a flat list of tokens inside the element
sub tokens { $_[0] }

# Is an element significant, and form a useful part of the code
sub significant { 1 }








#####################################################################
# PPI::ParentElement is an element that can have child elements
#####################################################################

package PPI::ParentElement;

use UNIVERSAL 'isa';

BEGIN {
	@PPI::ParentElement::VERSION = '0.814';
	@PPI::ParentElement::ISA     = 'PPI::Element';
}





#####################################################################
# Internal tree related code

# Our reference count has hit zero...
# As above, but don't call the super.
sub DESTROY {
	my $self = shift;

	# Delete our children
	foreach ( @{$self->{elements}} ) {
		next unless defined $_;
		delete $PPI::Element::_PARENT{ refaddr $_ };
		$_->DESTROY;
	}
	$self->{elements} = [];
	delete $self->{elements};

	# Delete ourselves
	delete $PPI::Element::_PARENT{ refaddr $self };
	$self = {}; 
	undef $self;
}





#####################################################################
# Public tree related methods

# Find the position within us of a child element.
sub position {
	my $self = shift;
	my $child = isa( $_[0], 'PPI::Element' ) or return undef;

	my $elements = $self->{elements};
	for my $i ( 0 .. $#$elements ) {
		return $i if $elements->[$i] eq $child;
	}

	undef;
}

# Add an element.
# This also means we add anything that was before us, and delayed.
sub add_element {
	my $self = shift;
	my $Element = isa( $_[0], 'PPI::Element' ) ? shift : return undef;

	# Add the argument to the elements
	push @{$self->{elements}}, $Element;
	$PPI::Element::_PARENT{ refaddr $Element } = $self;

	1;
}

# Remove an element, given the child element we want to remove.
sub remove_element {
	my $self = shift;
	my $child = isa( $_[0], 'PPI::Element' ) ? shift : return undef;

	# Where is the child
	my $position = $self->position( $child );
	return undef unless defined $position;

	# Splice it out
	splice( @{$self->{elements}}, $position, 1 );

	# Remove it's parent entry
	delete $PPI::Element::_PARENT{ refaddr $self };

	1;
}

# Overload the PPI::Element::delete method
sub delete {
	my $self = ref($_[0]) ? shift : return undef;

	# Remove our element's parent index entry, and
	# call delete on them
	foreach ( @{$self->{elements}} ) {
		delete $PPI::Element::_PARENT{ refaddr $_ };
		$_->DESTROY;
	}

	# Clean up
	$self->{elements} = [];
	delete $self->{elements};

	# Now delete ourselves like a normal element
	$self->SUPER::delete;
}

# Gets and returns a significant child as indicated by the position.
# A positive position number returns the nth significant child from the
# beginning. A negative position number returns the nth significant 
# child from the end.
sub nth_significant_child {
	my $elements = shift->{elements};
	my ($number, $fromend) = ($_[0] > 0) ? (shift, 0) 
		: ($_[0] < 0) ? (0 - shift(), 1)
		: return undef;

	# Start with the index of the last element
	my $last_index = $#$elements;
	foreach my $p ( 0 .. $last_index ) {
		# Work out the actual position to test
		my $i = $fromend ? ($last_index - $p) : $p;

		if ( $elements->[$i]->significant ) {
			# Is this the nth?
			return $elements->[$i] unless --$number;
		}
	}

	# Not found
	0;
}

# Search for one or more elements based on a coderef
sub find {
	my $self = shift;
	my $condition = isa( $_[0], 'CODE' ) ? shift : return;

	# Do we match the condition?
	$_ = $self;
	my @found = &$condition() ? ($self) : ();

	# Test each of our children, recursing as needed
	foreach my $child ( @{$self->{children}} ) {
		if ( isa( $child, 'PPI::ParentElement' ) ) {
			push @found, $child->find($condition);
		} elsif ( &$condition() ) {
			push @found, $_;
		}
	}

	@found;
}





####################################################################
# Getting information out

# Merge from our children
sub tokens { map { $_->tokens } @{$_[0]->{elements}} }

# Overload to merge from our children
sub content { join '', map { $_->content } @{$_[0]->{elements}} }

1;
