package PPI::Node;

use strict;
use UNIVERSAL 'isa';
use Scalar::Util 'refaddr';
use base 'PPI::Element';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.818';
}





#####################################################################
# The basic constructor

sub new {
	my $class = ref($_[0]) || $_[0];
	bless { elements => [] }, $class;
}






#####################################################################
# Internal tree related code

# Our reference count has hit zero...
sub DESTROY {
	# DESTROY from the bottom up
	foreach ( @{$_[0]->{elements}} ) {
		$_->DESTROY if isa( $_, 'PPI::Node' );
	}

	# Remove us from our parent node
	delete $PPI::Element::_PARENT{ refaddr $_[0] };

	# Clean up the last bits
	%{$_[0]} = ();
}





#####################################################################
# Public tree related methods

# Return the list of all elements in the Node
sub elements {
	@{$_[0]->{elements}};
}

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

# Add an element to the end of the node

sub add_element {
	my $self = shift;
	my $Element = isa( $_[0], 'PPI::Element' ) ? shift : return undef;
	$PPI::Element::_PARENT{ refaddr $Element } and return undef;

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

	'';
}

# Search for one or more elements based on a condition
sub find {
	my $self = shift;
	my $condition = $self->_condition(shift) or return undef;

	# Use a queue based search, rather than a recursive one
	my @found = ();
	my @queue = $self->elements;
	while ( my $node = shift @queue ) {
		# Depth-first search keeps the queue size down,
		# and provides a better logical order.
		unshift @queue, $node->elements;
		push @found, $node if &$condition( $self, $node );
	}

	@queue ? \@queue : '';
}

sub prune {
	my $self = shift;
	my $condition = $self->_condition(shift) or return undef;

	# Use a queue search, rather than a recursive search
	my $pruned = 0;
	my @queue = ( @{$self->{elements}} );
	while ( my $node = shift @queue ) {
		if ( &$condition( $self, $node ) ) {
			# Delete the child
			$node->delete or return undef;
			$pruned++;
		} else {
			# Depth-first keeps the queue size down
			unshift @queue, $node->elements;
		}
	}

	1;
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
# Getting information out

# Merge from our children
sub tokens { map { $_->tokens } @{$_[0]->{elements}} }

# Overload to merge from our children
sub content { join '', map { $_->content } @{$_[0]->{elements}} }

1;
