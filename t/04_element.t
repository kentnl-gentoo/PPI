#!/usr/bin/perl -w

# Formal testing for PPI

# This does an empiric test that when we try to parse something,
# something ( anything ) comes out the other side.

use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec;
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		chdir ($FindBin::Bin = $FindBin::Bin); # Avoid a warning
		lib->import( File::Spec->catdir(
			File::Spec->updir,
			File::Spec->updir,
			'modules',
			) );
	}
}

use Scalar::Util ();
use Test::More tests => 84;
use PPI::Lexer ();

sub is_object {
	my ($left, $right, $message) = @_;
	$message ||= "Objects match";
	my $condition = (
		defined $left
		and ref $left,
		and defined $right,
		and ref $right,
		and Scalar::Util::refaddr($left) == Scalar::Util::refaddr($right)
		);
	ok( $condition, $message );
}





#####################################################################
# Prepare

# Build a basic source tree to test with
my $source   = 'my@foo =  (1,   2);';
my $Document = PPI::Lexer->lex_source( \$source );
isa_ok( $Document, 'PPI::Document' );
is( $Document->content, $source, "Document round-trips ok" );
is( scalar($Document->tokens), 12, "Basic source contains the correct number of tokens" );
is( scalar(@{$Document->{elements}}), 1, "Document contains one element" );
my $Statement = $Document->{elements}->[0];
isa_ok( $Statement, 'PPI::Statement' );
isa_ok( $Statement, 'PPI::Statement::Variable' );
is( scalar(@{$Statement->{elements}}), 7, "Statement contains the correct number of elements" );
my $Token1 = $Statement->{elements}->[0];
my $Token2 = $Statement->{elements}->[1];
my $Token3 = $Statement->{elements}->[2];
my $Braces = $Statement->{elements}->[5];
my $Token7 = $Statement->{elements}->[6];
isa_ok( $Token1, 'PPI::Token::Bareword'   );
isa_ok( $Token2, 'PPI::Token::Symbol'     );
isa_ok( $Token3, 'PPI::Token::Whitespace' );
isa_ok( $Braces, 'PPI::Structure::List'   );
isa_ok( $Token7, 'PPI::Token::Structure'  );
ok( $Token1->is_a('Bareword', 'my'), 'First token is correct'   );
ok( $Token2->is_a('Symbol', '@foo'), 'Second token is correct'  );
ok( $Token3->is_a('Whitespace', ' '), 'Third token is correct'  );
is( $Braces->braces, '()', 'Braces seem correct' );
ok( $Token7->is_a('Structure', ';'), 'Seventh token is correct' );





#####################################################################
# Testing of PPI::Element basic information methods

# Testing the ->content method
is( $Document->content,  $source,    "Document content is correct" );
is( $Statement->content, $source,    "Statement content is correct" );
is( $Token1->content,    'my',       "Token content is correct" );
is( $Token2->content,    '@foo',     "Token content is correct" );
is( $Token3->content,    ' ',        "Token content is correct" );
is( $Braces->content,    '(1,   2)', "Token content is correct" );
is( $Token7->content,    ';',        "Token content is correct" );

# Testing the ->tokens method
is( scalar($Document->tokens),  12, "Document token count is correct" );
is( scalar($Statement->tokens), 12, "Statement token count is correct" );
isa_ok( $Token1->tokens, 'PPI::Token',  "Token token count is correct" );
isa_ok( $Token2->tokens, 'PPI::Token',  "Token token count is correct" );
isa_ok( $Token3->tokens, 'PPI::Token',  "Token token count is correct" );
is( scalar($Braces->tokens),    6,  "Token token count is correct" );
isa_ok( $Token7->tokens, 'PPI::Token',  "Token token count is correct" );

# Testing the ->significant method
is( $Document->significant,  1, 'Document is significant' );
is( $Statement->significant, 1, 'Statement is significant' );
is( $Token1->significant,    1, 'Token is significant' );
is( $Token2->significant,    1, 'Token is significant' );
is( $Token3->significant,    0, 'Token is significant' );
is( $Braces->significant,    1, 'Token is significant' );
is( $Token7->significant,    1, 'Token is significant' );





#####################################################################
# Testing of PPI::Element navigation methods

# Test the ->parent method
is( $Document->parent, undef, "Document does not have a parent" );
is_object( $Statement->parent,  $Document,  "Statement sees document as parent" );
is_object( $Token1->parent,     $Statement, "Token sees statement as parent" );
is_object( $Token2->parent,     $Statement, "Token sees statement as parent" );
is_object( $Token3->parent,     $Statement, "Token sees statement as parent" );
is_object( $Braces->parent,     $Statement, "Braces sees statement as parent" );
is_object( $Token7->parent,     $Statement, "Token sees statement as parent" );

# Test the ->top method
is_object( $Document->top,  $Document, "Document sees itself as top" );
is_object( $Statement->top, $Document, "Statement sees document as top" );
is_object( $Token1->top,    $Document, "Token sees document as top" );
is_object( $Token2->top,    $Document, "Token sees document as top" );
is_object( $Token3->top,    $Document, "Token sees document as top" );
is_object( $Braces->top,    $Document, "Braces sees document as top" );
is_object( $Token7->top,    $Document, "Token sees document as top" );

# Test the ->document method
is_object( $Document->document,  $Document, "Document sees itself as document" );
is_object( $Statement->document, $Document, "Statement sees document correctly" );
is_object( $Token1->document,    $Document, "Token sees document correctly" );
is_object( $Token2->document,    $Document, "Token sees document correctly" );
is_object( $Token3->document,    $Document, "Token sees document correctly" );
is_object( $Braces->document,    $Document, "Braces sees document correctly" );
is_object( $Token7->document,    $Document, "Token sees document correctly" );

# Test the ->next_sibling method
is( $Document->next_sibling, '', "Document returns false for next_sibling" );
is( $Statement->next_sibling, '', "Statement returns false for next_sibling" );
is_object( $Token1->next_sibling, $Token2, "First token sees second token as next_sibling" );
is_object( $Token2->next_sibling, $Token3, "Second token sees third token as next_sibling" );
is_object( $Braces->next_sibling, $Token7, "Braces sees seventh token as next_sibling" );
is( $Token7->next_sibling, '', 'Last token returns false for next_sibling' );

# Test the ->previous_sibling method
is( $Document->previous_sibling, '', "Document returns false for previous_sibling" );
is( $Statement->previous_sibling, '', "Statement returns false for previous_sibling" );
is( $Token1->previous_sibling, '', "First token returns false for previous_sibling" );
is_object( $Token2->previous_sibling, $Token1, "Second token sees first token as previous_sibling" );
is_object( $Token3->previous_sibling, $Token2, "Third token sees second token as previous_sibling" );
is_object( $Token7->previous_sibling, $Braces, "Last token sees braces as previous_sibling" );

# Test the find method
is( $Document->find('PPI::Token::End'), '', '->find returns false if nothing found' );
isa_ok( $Document->find('PPI::Structure')->[0], 'PPI::Structure' );
my $found = $Document->find('PPI::Token::Number');
ok( $found, 'Multiple find succeeded' );
is( ref $found, 'ARRAY', '->find returned an array' );
is( scalar(@$found), 2, 'Multiple find returned expected number of items' );





#####################################################################
# Test the PPI::Element manipulation methods

# Delete the second token
ok( $Token2->delete, "Deletion of token 2 returns true" );
is( $Document->content, 'my =  (1,   2);', "Content is modified correctly" );
is( scalar($Document->tokens), 11, "Modified source contains the correct number of tokens" );
ok( ! defined $Token2->parent, "Token 2 is detached from parent" );

# Delete the braces
ok( $Braces->delete, "Deletion of braces returns true" );
is( $Document->content, 'my =  ;', "Content is modified correctly" );
is( scalar($Document->tokens), 5, "Modified source contains the correct number of tokens" );
ok( ! defined $Braces->parent, "Braces are detached from parent" );

1;
