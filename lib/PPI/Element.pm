package PPI::Element;

# The abstract parent class for all lexer elements.
# It contains large sections of common code, accessible by all.

use strict;
use PPI ();
BEGIN {
	@PPI::Element::ISA = 'PPI::Common';
}





#####################################################################
# Tree related code

use vars qw{%_PARENT};
BEGIN {
	%_PARENT = ();
}

# Find our parent
sub parent {
	my $self = ref $_[0] ? shift : return undef;
	return $_PARENT{ $self =~ /([^=]+)$/ } || '';
}

# Remove us from our parent.
# You should be reasonably carefull with this. If you remove something
# in a way that isn't safe ( imagine remove -> from foo->bar ), you will
# break the code.
sub extract {
	my $self = ref $_[0] ? shift : return undef;
	my $key = $self =~ /([^=]+)$/;

	# Do we have a parent
	my $parent = $_PARENT{$key} or return 1;

	# Remove us from our parent
	return $parent->remove_element( $self );
}

# Deleting an element involves removing ourselves, from our
# parent ( if any ) and then destroying ourself.
sub delete {
	my $self = ref($_[0]) ? shift : return undef;
	my $key = $self =~ /([^=]+)$/;

	# Do we have a parent
	if ( $_PARENT{$key} ) {
		# Remove from our parent's element array
		$_PARENT{$key}->_remove( $self ) or return undef;

		# Remove the parent index entry
		delete $_PARENT{$key};
	}

	# Delete ourselves in what I'm told is the mod_perl
	# friendly way.
	$self = {}; undef $self;

	return 1;
}

# Being DESTROYed in this manner, rather than by an explicit
# ->delete means our reference count has fallen to zero.
# Therefore we don't need to remove ourselves from our parent,
# just the index ( just in case ).
sub DESTROY {
	delete $_PARENT{ $_[0] =~ /([^=]+)$/ };
}





#####################################################################
# Getting information out

# The element's class
sub class { ref $_[0] }

# The element's content
sub content { $_[0]->{content} or '' }

# Returns a flat list of tokens inside the element
sub tokens { $_[0] }









#####################################################################
# PPI::ParentElement is an element that can have child elements
#####################################################################

package PPI::ParentElement;

use strict;
BEGIN {
	@PPI::ParentElement::ISA = 'PPI::Element';
}





#####################################################################
# Internal tree related code

# Delay the addition of an element
sub _delay_element {
	my $self = shift;
	return undef unless defined $_[0];

	if ( exists $self->{delayed} ) {
		push @{$self->{delayed}}, shift;
	} else {
		$self->{delayed} = [ shift ];
	}

	return 1;
}

# Just add anything delayed to the elements
### IS THIS USED?
sub _add_delayed {
	my $self = shift;

	if ( exists $self->{delayed} ) {
		while ( shift @{$self->{delayed}} ) {
			push @{$self->{elements}}, $_;
			$PPI::Element::_PARENT{ /([^=]+)$/ } = $self;
		}
		delete $self->{delayed};
	}

	return 1;
}

# Our reference count has hit zero...
# As above, but don't call the super.
sub DESTROY {
	my $self = shift;

	# Delete our children
	foreach ( @{$self->{elements}} ) {
		delete $PPI::Element::_PARENT{ /([^=]+)$/ };
		$_->DESTROY;
	}
	$self->{elements} = [];
	delete $self->{elements};

	# Delete ourselves
	delete $PPI::Element::_PARENT{ $self =~ /([^=]+)$/ };
	$self = {};
	undef $self;
}





#####################################################################
# Public tree related methods

# Add an element.
# This also means we add anything that was before us, and delayed.
sub add_element {
	my $self = shift;
	my $element = UNIVERSAL::isa( $_[0], 'PPI::Element' )
		? shift : return undef;

	# If there is anything delayed, move it to the elements
	if ( exists $self->{delayed} ) {
		while ( shift @{$self->{delayed}} ) {
			push @{$self->{elements}}, $_;
			$PPI::Element::_PARENT{ /([^=]+)$/ } = $self;
		}
		delete $self->{delayed};
	}

	# Add the argument to the elements
	push @{$self->{elements}}, $element;
	$PPI::Element::_PARENT{ $element =~ /([^=]+)$/ } = $self;

	return 1;
}

# Remove an element, given the child element we want to remove.
sub remove_element {
	my $self = shift;
	my $child = isa( $_[0], 'PPI::Element' )
		? shift : return undef;

	# Find the child in our element list
	my $elements = $self->{elements};
	my $element_count = scalar @$elements;
	for ( my $i = 0; $i < $element_count; $i++ ) {
		if ( $elements->[$i] eq $child ) {
			# Splice it out
			splice( @$elements, $i, 1 );

			# Remove it's parent entry
			delete $PPI::Element::_PARENT{ $self =~ /([^=]+)$/ };
			return 1;
		}
	}

	# Not found
	return undef;
}

# Remove a given element from our
# Remove and decrement the tokenizer cursor for anything in the delated
# queue and for any tokens passed
sub rollback_tokenizer {
	my $self = shift;
	my $tokenizer = $self->{tokenizer} or return undef;

	# Handle anything passed
	foreach ( @_ ) {
		if ( UNIVERSAL::isa( $_, 'PPI::Token' ) ) {
			$tokenizer->decrement_cursor();
		}
	}

	# Handle our delayed queue
	if ( exists $self->{delayed} ) {
		foreach ( @{$self->{delayed}} ) {
			$tokenizer->decrement_cursor();
		}
		delete $self->{delayed};
	}

	return 1;
}

# Overload the PPI::Element::delete method
sub delete {
	my $self = ref($_[0]) ? shift : return undef;

	# Remove our element's parent index entry, and
	# call delete on them
	foreach ( @{$self->{elements}} ) {
		delete $PPI::Element::_PARENT{ /([^=]+)$/ };
		$_->DESTROY;
	}

	# Clean up
	$self->{elements} = [];
	delete $self->{elements};

	# Now delete ourselves like a normal element
	return $self->SUPER::delete();
}






####################################################################
# Getting information out

# Overload to merge from our children
sub content {
	return join '', map { $_->content } @{$_[0]->{elements}}
}

# Merge from our children
sub tokens {
	return map { $_->tokens } @{$_[0]->{elements}}
}





#####################################################################
# Utilities

sub _clean {
	my $self = shift;

	# Clean up everything
	delete $self->{tokenizer} if exists $self->{tokenizer};
	$self->rollback_delayed() if exists $self->{delayed};

	# Return with the argument passed
	return @_ ? $_[0] : ();
}

1;
