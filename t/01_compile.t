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

use Test::More tests => 2;
use Class::Autouse qw{:devel};
use Class::Handle;




# Check their perl version
BEGIN {
        ok( $] >= 5.005, "Your perl is new enough" );
}

# Does the module load
use_ok( 'PPI' );

exit();
