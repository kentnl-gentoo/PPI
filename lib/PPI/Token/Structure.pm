package PPI::Token::Structure;

# Characters used to create heirachal structure

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.905';
}





#####################################################################
# Parsing Methods

# Set the matching braces, done as an array
# for slightly faster lookups.
use vars qw{@MATCH};
BEGIN {
	$MATCH[ord '{'] = '}';
	$MATCH[ord '}'] = '{';
	$MATCH[ord '['] = ']';
	$MATCH[ord ']'] = '[';
	$MATCH[ord '('] = ')';
	$MATCH[ord ')'] = '(';
}

sub __TOKENIZER__on_char {
	# Structures are one character long, always.
	# Finalize and process again.
	$_[1]->_finalize_token->__TOKENIZER__on_char( $_[1] );
}

sub __TOKENIZER__commit {
	my $t = $_[1];
	$t->_new_token( 'Structure', substr( $t->{line}, $t->{line_cursor}, 1 ) );
	$t->_finalize_token;
	0;
}

# For a given brace, find its opposing pair
sub __LEXER__opposite {
	$MATCH[ord $_[0]->{content} ];
}

1;
