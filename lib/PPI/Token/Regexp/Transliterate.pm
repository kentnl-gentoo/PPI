package PPI::Token::Regexp::Transliterate;

# tr// - Transliteration

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::_QuoteEngine::Full',
         'PPI::Token::Regexp';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.842';
}

1;
