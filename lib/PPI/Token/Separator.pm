package PPI::Token::Separator;

# The __END__ and __DATA__ "separator" tokens

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::Word';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.844';
}

1;
