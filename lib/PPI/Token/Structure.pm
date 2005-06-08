package PPI::Token::Structure;

=pod

=head1 NAME

PPI::Token::Structure - Token class for characters that define code structure

=head1 INHERITANCE

  PPI::Token::Structure
  isa PPI::Token
      isa PPI::Element

=head1 DESCRIPTION

The C<PPI::Token::Structure> class is used for tokens that control the
generaly tree structure or code.

This consists of seven characters. These are the six brace characters from
the "round", "curly" and "square" pairs, plus the semi-colon statement
separator C<";">.

=head1 METHODS

This class has no methods beyond what is provided by its
L<PPI::Token> and L<PPI::Element> parent classes.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.990';
}

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





#####################################################################
# Tokenizer Methods

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





#####################################################################
# Lexer Methods

# For a given brace, find its opposing pair
sub __LEXER__opposite {
	$MATCH[ord $_[0]->{content} ];
}

1;

=pod

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy, L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
