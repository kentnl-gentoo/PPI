package PPI::Token::Quote::Literal;

# Single Quote

use strict;
use base 'PPI::Token::_QuoteEngine::Full',
         'PPI::Token::Quote';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.902';
}

1;
