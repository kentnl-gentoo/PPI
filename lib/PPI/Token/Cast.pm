package PPI::Token::Cast;

# A cast is a symbol-like character than precedes another symbol
# to do something to it, such as dereference.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.900';
}

# A cast is either % @ $ or $#
sub _on_char {
	$_[1]->_finalize_token->_on_char( $_[1] );
}

1;
