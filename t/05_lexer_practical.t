#!/usr/bin/perl

# Test the API for PPI
use strict;
use UNIVERSAL 'isa';
use File::Spec::Functions qw{catdir catfile updir};
use Test::More tests => 31;
use lib catdir( updir(), updir(), 'modules' );
use Class::Autouse qw{:devel};

use vars qw{$testdir};
BEGIN {
	$testdir = catdir( 'testdata', 'lexer', 'practical' );
}





#####################################################################
# Prepare

# Load the PPI componants we need
use_ok( 'PPI::Lexer' );
use_ok( 'PPI::Lexer::Dump' );

# Does the test directory exist?
ok( (-e $testdir and -d $testdir and -r $testdir), "Test directory $testdir found" );

# Find the .code test files
opendir( TESTDIR, $testdir ) or die "opendir: $!";
my @code = map { catfile( $testdir, $_ ) } sort grep { /\.code$/ } readdir(TESTDIR);
closedir( TESTDIR ) or die "closedir: $!";
ok( scalar @code, 'Found at least one code file' );





#####################################################################
# Testing

foreach my $codefile ( @code ) {
	# Does the .code file have a matching .dump file
	my $dumpfile = $codefile;
	$dumpfile =~ s/\.code$/\.dump/;
	ok( (-f $dumpfile and -r $dumpfile), "$codefile: Found matching .dump file" );

	# Create the lexer and get the Document object
	my $Lexer = PPI::Lexer->new( $codefile );
	ok( $Lexer,                             "$codefile: PPI::Lexer->new returns true" );
	ok( isa( $Lexer, 'PPI::Lexer' ),        "$codefile: PPI::Lexer object created" );
	ok( $Lexer->load,                       "$codefile: Lexer loads the file OK" );
	my $Document = $Lexer->Document;
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
}

exit();
