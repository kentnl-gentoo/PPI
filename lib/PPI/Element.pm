package PPI::Element;

# The abstract parent class for all lexer elements.
# It contains large sections of common code, accessible by all.

use strict;
use base 'PPI::Base';
use Scalar::Util qw{refaddr};

use vars qw{$VERSION %_PARENT};
BEGIN {
	$PPI::Element::VERSION = '0.818';
	
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

1;
