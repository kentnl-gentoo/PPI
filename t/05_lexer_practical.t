#!/usr/bin/perl -w

# Compare a large number of specific constructs
# with the expected Lexer dumps.

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
use PPI::Lexer::Dump;





#####################################################################
# Prepare

use Test::More tests => 51;
use File::Slurp ();

use vars qw{$testdir};
BEGIN {
	$testdir = catdir( 't.data', '05_lexer_practical' );
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
	my $Dumper = PPI::Lexer::Dump->new( $Document );
	ok( isa( $Dumper, 'PPI::Lexer::Dump' ), "$codefile: Dumper created" );
	my $array_ref = $Dumper->dump_array_ref;
	ok( isa( $array_ref, 'ARRAY' ),         "$codefile: Got dump array ref from dumper" );

	# Try to get the .dump file array
	open( DUMP, $dumpfile ) or die "open: $!";
	my @content = <DUMP>;
	close( DUMP ) or die "close: $!";
	chomp @content;

	# Compare the two
	is_deeply( $array_ref, \@content,      "$codefile: Generated dump matches stored dump" );

	# Also, do a round-trip check
	my $source = File::Slurp::read_file( $codefile );
	$source =~ s/(?:\015{1,2}\012|\015|\012)/\n/g;

	is( $Document->content, $source, "$codefile: Round-trip back to source was ok" );
}

exit();
