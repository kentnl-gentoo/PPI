package PPI::Statement::UnmatchedBrace;

# An unattached structural code such as ) ] } found incorrectly at
# the root level of a Document. We create a separate statement for it
# so that we can continue parsing the code.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.842';
}

1;
