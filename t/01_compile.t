#!/usr/bin/perl -w

# Formal testing for PPI

# This test script only tests that the tree compiles

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

use Test::More tests => 7;
use Class::Autouse ':devel';





# Check their perl version
ok( $] >= 5.005, "Your perl is new enough" );

# Does the module load
use_ok( 'PPI'               );
use_ok( 'PPI::Tokenizer'    );
use_ok( 'PPI::Lexer'        );
use_ok( 'PPI::Dumper'       );
use_ok( 'PPI::Find'         );
use_ok( 'PPI::Transform'    );

exit();
