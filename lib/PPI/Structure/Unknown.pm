package PPI::Structure::Unknown;

# The Unknown class has been added to handle situations where we do
# not immediately know the class we are, and need to wait for more
# clues.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Structure';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.903';
}

1;
