#!/usr/bin/perl -w

# Formal testing for PPI

# This does an empiric test that when we try to parse something,
# something ( anything ) comes out the other side.


use strict;
use lib '../../modules'; # Development testing
use lib '../lib';           # Installation testing
use UNIVERSAL 'isa';
use Test::More tests => 3;
use PPI;

# Set up any needed globals
BEGIN {
        $| = 1;
}




# Get the lexer
my $Lexer = PPI::Lexer->new;
ok( $Lexer, 'PPI::Lexer->new() returns true' );
isa_ok( $Lexer, 'PPI::Lexer' );

# Parse a file
my $Document = $Lexer->lex_file('./data/test.dat');
isa_ok( $Document, 'PPI::Document' );

1;
