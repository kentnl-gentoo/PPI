package PPI::Element;

# The abstract parent class for all lexer elements.
# It contains large sections of common code, accessible by all.

use strict;
use base 'PPI::Common';
use Scalar::Util qw{refaddr};

use vars qw{$VERSION %_PARENT};
BEGIN {
	$VERSION = '0.804';
	
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
	@PPI::ParentElement::ISA = 'PPI::Element';
}





#####################################################################
# Internal tree related code

# Delay the addition of an element
sub _delay_element {
	my $self = shift;
	my $element = defined $_[0] ? shift : return undef;

	if ( exists $self->{delayed} ) {
		push @{$self->{delayed}}, $element;
	} else {
		$self->{delayed} = [ $element ];
	}

	1;
}

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
	for ( 0 .. $#$elements ) {
		return $_ if $elements->[$_] eq $child;
	}

	return undef;
}

# Add an element.
# This also means we add anything that was before us, and delayed.
sub add_element {
	my $self = shift;
	my $element = isa( $_[0], 'PPI::Element' ) ? shift : return undef;

	# If there is anything delayed, move it to the elements
	if ( exists $self->{delayed} ) {
		foreach ( @{$self->{delayed}} ) {
			$PPI::Element::_PARENT{ refaddr $_ } = $self;
		}
		push @{$self->{elements}}, @{$self->{delayed}};
		delete $self->{delayed};
	}

	# Add the argument to the elements
	push @{$self->{elements}}, $element;
	$PPI::Element::_PARENT{ refaddr $element } = $self;

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

# Remove a given element from our
# Remove and decrement the tokenizer cursor for anything in the delated
# queue and for any tokens passed
sub rollback_tokenizer {
	my $self = shift;
	my $tokenizer = $self->{tokenizer} or return undef;

	# Handle anything passed
	foreach ( @_ ) {
		if ( isa( $_, 'PPI::Token' ) ) {
			$tokenizer->decrement_cursor;
		}
	}

	# Handle our delayed queue
	if ( exists $self->{delayed} ) {
		foreach ( @{$self->{delayed}} ) {
			$tokenizer->decrement_cursor;
		}
		delete $self->{delayed};
	}

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

# Start from the end, find the nth ( default 1st ) significant 
# child element. Returns the element, 0 if none, or undef or error.
sub last_significant_child {
	my $self = shift;
	my $number = ($_[0] > 0) ? shift : 1;

	# Start with the index of the last element
	my $i = $#{$self->{elements}};
	while ( $i >= 0 ) {
		if ( $self->{elements}->[$i]->significant ) {
			if ( $number > 1 ) {
				# More
				$number--;
			} else {
				# Found it
				return $self->{elements}->[$i];
			}
		}

		$i--;
	}

	# Didn't find it
	0;
}





####################################################################
# Getting information out

# Overload to merge from our children
sub content { join '', map { $_->content } @{$_[0]->{elements}} }

# Merge from our children
sub tokens { map { $_->tokens } @{$_[0]->{elements}} }





#####################################################################
# Utilities

sub _clean {
	my $self = shift;

	# Clean up everything
	delete $self->{tokenizer} if exists $self->{tokenizer};
	$self->rollback_tokenizer if exists $self->{delayed};

	# Return with the argument passed
	@_ and $_[0];
}

1;
