package PPI::Statement::Null;

# A null statement is a useless statement.
# Usually, just an extra ; on its own.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.903';
}

1;
