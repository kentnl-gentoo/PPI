#!/usr/bin/perl -w

# Formal testing for PPI

# This does an empiric test that when we try to parse something,
# something ( anything ) comes out the other side.


use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec::Functions ':ALL';
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		chdir ($FindBin::Bin = $FindBin::Bin); # Avoid a warning
		lib->import( catdir( updir(), updir(), 'modules') );
	}
}

# Load the API to test
use Class::Autouse ':devel';
use PPI;

# Execute the tests
use Test::More tests => 3;





# Get the lexer
my $Lexer = PPI::Lexer->new;
ok( $Lexer, 'PPI::Lexer->new() returns true' );
isa_ok( $Lexer, 'PPI::Lexer' );

# Parse a file
my $Document = $Lexer->lex_file('./data/test.dat');
isa_ok( $Document, 'PPI::Document' );

1;
