package PPI::Token::Structure;

# Characters used to create heirachal structure

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION @MATCH};
BEGIN {
	$VERSION = '0.841';

	# Populate the matches
	$MATCH[ord '{'] = '}';
	$MATCH[ord '}'] = '{';
	$MATCH[ord '['] = ']';
	$MATCH[ord ']'] = '[';
	$MATCH[ord '('] = ')';
	$MATCH[ord ')'] = '(';
}





#####################################################################
# Tokenizer Methods

sub _on_char {
	# Structures are one character long, always.
	# Finalize and process again.
	$_[1]->_finalize_token->_on_char( $_[1] );
}

sub _commit {
	my $t = $_[1];
	$t->_new_token( 'Structure', substr( $t->{line}, $t->{line_cursor}, 1 ) );
	$t->_finalize_token;
	0;
}

# For a given brace, find its opposing pair
sub _opposite { $MATCH[ord $_[0]->{content} ] }

1;
