package PPI::Structure::ForLoop;

# The special round braces at the beginning of a for or foreach loop that
# describes the loop.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Structure';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.842';
}

1;
