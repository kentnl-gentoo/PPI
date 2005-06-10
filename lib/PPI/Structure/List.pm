package PPI::Structure::List;

# An explicit list, primarily for subroutine arguments or
# contexts in which you want to explicitly describe a list.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Structure';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.991';
}

1;
