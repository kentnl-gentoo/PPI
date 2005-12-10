#!/usr/bin/perl -w

# code/dump-style regression tests for known lexing problems.

# Some other regressions tests are included here for simplicity.

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
BEGIN { $PPI::XS_DISABLE = 1 }
use PPI::Lexer;
use PPI::Dumper;

sub pause {
	local $@;
	eval { require Time::HiRes; };
	$@ ? sleep(1) : Time::HiRes::sleep(0.1);
}





#####################################################################
# Prepare

use Test::More;

use vars qw{$testdir};
BEGIN {
	$testdir = catdir( 't.data', '20_tokenizer' );
}

opendir( TESTDIR, $testdir ) or die "opendir: $!";
my @code = map { catfile( $testdir, $_ ) } sort grep { /\.code$/ } readdir(TESTDIR);
closedir( TESTDIR ) or die "closedir: $!";

plan tests => (0+@code);

#####################################################################
# Code/Dump Testing

foreach my $codefile ( @code ) {
	# Create the lexer and get the Document object
        my $Tokenizer = PPI::Tokenizer->new($codefile);
        $Tokenizer->all_tokens;
        is( $PPI::Tokenizer::errstr, '',        "Parsed $codefile without errors" );
}

exit();
