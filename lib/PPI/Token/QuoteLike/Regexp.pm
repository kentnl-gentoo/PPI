package PPI::Token::QuoteLike::Regexp;

# Regexp-constructor quote

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::_QuoteEngine::Full',
         'PPI::Token::QuoteLike';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.846';
}

1;
