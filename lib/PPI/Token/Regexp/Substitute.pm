package PPI::Token::Regexp::Substitute;

# s// - Match and Replace

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::_QuoteEngine::Full',
         'PPI::Token::Regexp';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840';
}

1;
