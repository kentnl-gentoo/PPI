#!/usr/bin/perl -w

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

use Test::More tests => 9;

sub good_ok {
	my $source  = shift;
	my $message = shift;
	my $doc = PPI::Document->new( \$source );
	ok( isa(ref $doc, 'PPI::Document'), $message );
}

sub bad_ok {
	my $source  = shift;
	my $message = shift;
	my $doc = PPI::Document->new( \$source );
	ok( ! $doc, $message );
}





#####################################################################
# Begin Tests

# Testing accented characters in Latin-1
good_ok( 'sub func { }',           "Parsed code without accented chars"   );
bad_ok ( 'rätselhaft();',          "Function with umlaut (not supported)" );
bad_ok ( 'ätselhaft()',            "Starting with umlaut (not supported)" );
good_ok( '"rätselhaft"',           "In double quotes (supported)"         );
good_ok( "'rätselhaft'",           "In single quotes (supported)"         );
good_ok( 'sub func { s/a/ä/g; }',  "Regex with umlaut (supported)"        );
bad_ok ( 'sub func { $ä=1; }',     "Variable with umlaut (not supported)" );
good_ok( '$a=1; # ä is an umlaut', "Comment with umlaut (supported)"      );
good_ok( <<'END_CODE',             "POD with umlaut (supported)"          );
sub func { }

=pod

=head1 Umlauts like ä

} 
END_CODE
