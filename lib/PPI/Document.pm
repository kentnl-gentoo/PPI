package PPI::Document;

# The Document lexer element is a relatively useless top-level
# element that contains the various elements in the file.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use PPI            ();
use PPI::Statement ();
use PPI::Structure ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.817';
}


1;
