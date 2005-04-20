package PPI::Statement::Unknown;

# We are unable to definitely categorize the statement from the first
# token alone. Do additional checks when adding subsequent tokens.

# Currently, the only time this happens is when we start with a label

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.905';
}

1;
