#!/usr/bin/perl

# code/dump-style regression tests for known lexing problems.

# Some other regressions tests are included here for simplicity.

use strict;
BEGIN {
	$| = 1;
	$PPI::XS_DISABLE = 1;
	$PPI::XS_DISABLE = 1; # Prevent warning
}

# For each new item in t/data/08_regression add another 14 tests
use Test::More tests => 3381;
use Test::NoWarnings;
use File::Spec::Functions ':ALL';
use Params::Util '_INSTANCE';
use PPI::Lexer;
use PPI::Dumper;
use t::lib::PPI;





#####################################################################
# Code/Dump Testing
# ntests = 2 + 14 * nfiles

t::lib::PPI->increment_testdir(qw{ t data 08_regression });
