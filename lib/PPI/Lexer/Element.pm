package PPI::Lexer::Element;

# A PPI::Lexer::Element is not used directly.
# It is inherited by several other classes, and is used
# primarily to check for valid objects inside the lexer.
#
# All Elements contain three properties.
#
# parent   - The element containing the element
# class    - The class of element, a general type across all elements

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';

# Simple and fast constructor
sub new { return bless { parent => undef, class => undef }, $_[0] }

# Parent
sub setParent {
	return undef unless isa( $_[1], 'PPI::Lexer::Block' );
	$_[0]->{parent} = $_[1];
}
sub parent { $_[0]->{parent} }

# Class
sub setClass { $_[0]->{class} = $_[1] }
sub class { $_[0]->{class} }

# Detach an element from it's parent
sub detach { delete $_[0]->{parent}; 1 }

# All elements are significant by default
sub significant { 1 }

# Get the rule match string
sub getSummaryStrings { [ $_[0]->{class}, undef ] }

1;
