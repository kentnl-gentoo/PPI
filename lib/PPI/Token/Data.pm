package PPI::Token::Data;

# After the __DATA__ tag

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840';
}

sub _on_char { 1 }

1;