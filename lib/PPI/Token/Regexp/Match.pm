package PPI::Token::Regexp::Match;

# m// or // - Pattern Match

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::_QuoteEngine::Full',
         'PPI::Token::Regexp';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.841';
}

1;
