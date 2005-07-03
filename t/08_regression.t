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
use Class::Autouse ':devel';
BEGIN { $PPI::XS_DISABLE = 1 }
use PPI::Lexer;
use PPI::Dumper;





#####################################################################
# Prepare

use Test::More tests => 49;
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
# Code/Dump Testing

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

	# Are there any unknown things?
	is( $Document->find_any('Token::Unknown'), '',
		"$codefile: Contains no PPI::Token::Unknown elements" );
	is( $Document->find_any('Structure::Unknown'), '',
		"$codefile: Contains no PPI::Structure::Unknown elements" );
	is( $Document->find_any('Statement::Unknown'), '',
		"$codefile: Contains no PPI::Statement::Unknown elements" );

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





#####################################################################
# Regression Test for rt.cpan.org #11522

# Check that objects created in a foreach don't leak circulars.
is( scalar(keys(%PPI::Element::_PARENT)), 0, 'No parent links initially' );
foreach ( 1 .. 3 ) {
	sleep 1;
	is( scalar(keys(%PPI::Element::_PARENT)), 0, 'No parent links at start of loop time' );
	my $Document = PPI::Document->new(\q[print "Foo!"]);
	is( scalar(keys(%PPI::Element::_PARENT)), 4, 'Correct number of keys created' );
}

exit();
