package PPI::Structure::Condition;

# The round-braces condition structure from an if, elsif or unless
# if ( ) { ... }

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Structure';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.845';
}

1;
