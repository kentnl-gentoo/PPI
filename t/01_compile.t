#!/usr/bin/perl -w

# Formal testing for PPI

# This test only tests that the tree compiles


use strict;
use lib '../../modules'; # Development testing
use lib '../lib';           # Installation testing
use UNIVERSAL 'isa';
use Test::More tests => 3;
use Class::Autouse qw{:devel};
use Class::Handle;

# Set up any needed globals
BEGIN {
        $| = 1;
}




# Check their perl version
BEGIN {
        ok( $] >= 5.005, "Your perl is new enough" );
}





# Does the module load
BEGIN { use_ok( 'PPI' ) }
require_ok( 'PPI');


