#!/usr/bin/perl -w

# Test the PPI::Util package

use strict;
use lib ();
use UNIVERSAL 'isa';
use File::Spec::Functions ':ALL';
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		$FindBin::Bin = $FindBin::Bin; # Avoid a warning
		chdir catdir( $FindBin::Bin, updir() );
		lib->import('blib', 'lib');
	}
}

# Load the code to test
use Class::Autouse ':devel';
BEGIN { $PPI::XS_DISABLE = 1 }
use PPI::Lexer ();
use PPI;
use PPI::Util '_Document';

# Execute the tests
use Test::More tests => 7;

my $testfile   = catfile( 't.data', '11_util', 'test.pm' );
my $testsource = 'print "Hello World!\n"';





#####################################################################
# Test PPI::Util

my $Document = PPI::Document->new( $testsource );
isa_ok( $Document, 'PPI::Document' );

# Good things
foreach my $thing ( $testfile, \$testsource, $Document ) {
	isa_ok( _Document( $thing ), 'PPI::Document' );
}

# Bad things
### erm...

# Evil things
foreach my $thing ( [], {}, sub () { 1 } ) {
	is( _Document( $thing ), undef, '_Document(evil) returns undef' );
}

1;
