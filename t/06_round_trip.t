#!/usr/bin/perl -w

# Load ALL of the PPI files, lex them in, dump them
# out, and verify that the code goes in and out cleanly.

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
use PPI;
use PPI::Lexer;

use Test::More; # Plan comes later
use File::Slurp ();






#####################################################################
# Prepare

# Find all of the files to be checked
my %tests = map { $_ => $INC{$_} } grep { ! /\bXS\.pm/ } grep { /^PPI\b/ } keys %INC;
unless ( %tests ) {
	Test::More::plan( tests => 1 );
	ok( undef, "Failed to find any files to test" );
	exit();
}

# Declare our plan
Test::More::plan( tests => scalar(keys %tests) * 4 );





#####################################################################
# Run the Tests

foreach my $key ( sort keys %tests ) {
	# Load and clean the file
	my $file = $tests{$key};
	my $source = File::Slurp::read_file( $file );
	ok( length $source, "$key: Loaded cleanly" );
	$source =~ s/(?:\015{1,2}\012|\015|\012)/\n/g;

	# Load the file as a Document
	my $Document = PPI::Document->new( $file );
	ok( isa(ref $Document, 'PPI::Document' ), "$key: PPI::Document object created" );

	# Serialize it back out, and compare with the raw version
	my $content = $Document->content;
	ok( length($content), "$key: PPI::Document serializes" );
	is( $content, $source, "$key: Round trip was successful" );
}

1;
