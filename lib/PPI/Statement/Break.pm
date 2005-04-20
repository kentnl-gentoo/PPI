package PPI::Statement::Break;

# Break out of a flow control block.
# next, last, return.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.905';
}

1;
