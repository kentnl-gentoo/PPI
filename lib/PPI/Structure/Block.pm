package PPI::Structure::Block;

# The general block curly braces

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Structure';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.904';
}





#####################################################################
# PPI::Element Methods

# This is a scoping boundary
sub scope { 1 }

1;
