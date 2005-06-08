#!/usr/bin/perl -w

# Tests the accuracy and features for location functionality

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

# Execute the tests
use Test::More tests => 105;

my $test_source = <<'END_PERL';
my $foo = 'bar';

# comment
sub foo {
	my ($this, $that) = (<<'THIS', <<"THAT");
foo
bar
baz
THIS
foo
bar
THAT
}

1;
END_PERL
my @test_locations = (
	[ 1,  1  ],
	[ 1,  4  ],
	[ 1,  9  ],
	[ 1,  11 ],
	[ 1,  16 ],
	[ 3,  1  ],
	[ 4,  1  ],
	[ 4,  5  ],
	[ 4,  9  ],
	[ 5,  2  ],
	[ 5,  5  ],
	[ 5,  6  ],
	[ 5,  11 ],
	[ 5,  13 ],
	[ 5,  18 ],
	[ 5,  20 ],
	[ 5,  22 ],
	[ 5,  23 ],
	[ 5,  31 ],
	[ 5,  33 ],
	[ 5,  41 ],
	[ 5,  42 ],
	[ 13, 1  ],
	[ 15, 1  ],
	[ 15, 2  ],
	);





#####################################################################
# Test the locations of everything in the test code

# Prepare
my $Document = PPI::Document->new( \$test_source );
isa_ok( $Document, 'PPI::Document' );
ok( $Document->index_locations, '->index_locations returns true' );

# Now check the locations of every token
my @tokens = grep { ! $_->isa('PPI::Token::Whitespace') } $Document->tokens;
is( scalar(@tokens), scalar(@test_locations), 'Number of non-whitespace tokens matches expected' );
foreach my $i ( 0 .. $#test_locations ) {
	my $location = $tokens[$i]->location;
	is( ref($location), 'ARRAY', "Token $i: ->location returns an ARRAY ref" );
	is( scalar(@$location), 2, "Token $i: ->location returns a 2 element ARRAY ref" );
	ok( ($location->[0] > 0 and $location->[1] > 0), "Token $i: ->location returns two positive positions" );
	is_deeply( $test_locations[$i], $tokens[$i]->location, "Token $i: ->location matches expected" );
}

ok( $Document->flush_locations, '->flush_locations returns true' );
is( scalar(grep { defined $_->{_location} } $Document->tokens), 0, 'All _location attributes removed' );

1;
