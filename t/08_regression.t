#!/usr/bin/perl -w

# code/dump-style regression tests for known problems

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

# Load the code to test
use Class::Autouse ':devel';
use PPI::Lexer;
use PPI::Dumper;





#####################################################################
# Prepare

use Test::More tests => 30;
use File::Slurp ();

use vars qw{$testdir};
BEGIN {
	$testdir = catdir( 't.data', '08_regression' );
}

# Does the test directory exist?
ok( (-e $testdir and -d $testdir and -r $testdir), "Test directory $testdir found" );

# Find the .code test files
opendir( TESTDIR, $testdir ) or die "opendir: $!";
my @code = map { catfile( $testdir, $_ ) } sort grep { /\.code$/ } readdir(TESTDIR);
closedir( TESTDIR ) or die "closedir: $!";
ok( scalar @code, 'Found at least one code file' );





#####################################################################
# Testing

my $Lexer = PPI::Lexer->new;
foreach my $codefile ( @code ) {
	# Does the .code file have a matching .dump file
	my $dumpfile = $codefile;
	$dumpfile =~ s/\.code$/\.dump/;
	ok( (-f $dumpfile and -r $dumpfile), "$codefile: Found matching .dump file" );

	# Create the lexer and get the Document object
	my $Document = $Lexer->lex_file( $codefile );
	ok( $Document,                          "$codefile: Lexer->Document returns true" );
	ok( isa( $Document, 'PPI::Document' ),  "$codefile: Lexer creates Document object" );

	# Get the dump array ref for the Document object
	my $Dumper = PPI::Dumper->new( $Document );
	ok( isa( $Dumper, 'PPI::Dumper' ), "$codefile: Dumper created" );
	my @dump_list = $Dumper->list;
	ok( scalar @dump_list, "$codefile: Got dump content from dumper" );

	# Try to get the .dump file array
	open( DUMP, $dumpfile ) or die "open: $!";
	my @content = <DUMP>;
	close( DUMP ) or die "close: $!";
	chomp @content;

	# Compare the two
	is_deeply( \@dump_list, \@content, "$codefile: Generated dump matches stored dump" );

	# Also, do a round-trip check
	my $source = File::Slurp::read_file( $codefile );
	$source =~ s/(?:\015{1,2}\012|\015|\012)/\n/g;

	is( $Document->serialize, $source, "$codefile: Round-trip back to source was ok" );
}

exit();
