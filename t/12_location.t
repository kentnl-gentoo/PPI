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
BEGIN { $PPI::XS_DISABLE = 1 }
use PPI;

# Execute the tests
use Test::More tests => 333;

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

sub bar {
    baz();

    #Note that there are leading 4 x space, not 1 x tab in the sub bar

    bas();
}

=head2 fluzz()

Print "fluzz". Return 1.

=cut
sub fluzz {
    print "fluzz";
}

1;
END_PERL
my @test_locations = (
	[ 1,  1  ],
	[ 1,  3  ],  #
	[ 1,  4  ],  #$foo
	[ 1,  8  ],  #
	[ 1,  9  ],  #=
	[ 1,  10 ],  #
	[ 1,  11 ],  #'bar'
	[ 1,  16 ],  #;

	[ 1,  17 ],  #\n
	[ 2,  1  ],  #\n

	[ 3,  1  ],  # # comment

	[ 4,  1  ],  #sub
	[ 4,  4  ],  #
	[ 4,  5  ],  #foo
	[ 4,  8  ],  #
	[ 4,  9  ],  #{
	[ 4,  10 ],  #\n

	[ 5,  1  ],  # tab
	[ 5,  2  ],  #my
	[ 5,  4  ],  #
	[ 5,  5  ],  #(
	[ 5,  6  ],  #$this
	[ 5,  11 ],  #,
	[ 5,  12 ],  #
	[ 5,  13 ],  #$that
	[ 5,  18 ],  #)
	[ 5,  19 ],  #
	[ 5,  20 ],  #=
	[ 5,  21 ],  #
	[ 5,  22 ],  #(
	[ 5,  23 ],  #<<'THIS'
	[ 5,  31 ],  #,
	[ 5,  32 ],  #
	[ 5,  33 ],  #<<"THAT"
	[ 5,  41 ],  #)
	[ 5,  42 ],  #;
	[ 5,  43 ],  #\n

	[ 13, 1  ],  #}
	[ 13, 2  ],  #\n

	[ 14, 1  ],  #\n

	[ 15, 1  ],  #sub
	[ 15, 4  ],  #
	[ 15, 5  ],  #bar
	[ 15, 8  ],  #
	[ 15, 9  ],  #{
	[ 15, 10 ],  #\n 

	[ 16, 1  ],  # whitespace
	[ 16, 5  ],  #baz
	[ 16, 8  ],  #(
	[ 16, 9  ],  #)
	[ 16, 10 ],  #;
	[ 16, 11 ],  #\n 

	[ 17, 1  ],  #\n

	[ 18, 1  ],  #comment

	[ 19, 1  ],  #\n whitespace

	[ 20, 5  ],  #bas
	[ 20, 8  ],  #(
	[ 20, 9  ],  #)
	[ 20, 10 ],  #;
	[ 20, 11 ],  #\n

	[ 21, 1  ],   #}
	[ 21, 2  ],   #\n

	[ 22, 1  ],   #\n

	[ 23, 1  ],   #=head2

	[ 28, 1  ],   #sub
	[ 28, 4  ],   #
	[ 28, 5  ],   #fluzz
	[ 28, 10  ],   #
	[ 28, 11 ],   #{
	[ 28, 12 ],   #\n

	[ 29, 1  ],   #
	[ 29, 5  ],   #print
	[ 29, 10 ],   #
	[ 29, 11 ],   #"fluzz"
	[ 29, 18 ],   #;
	[ 29, 19 ],   #\n

	[ 30, 1  ],   #}
	[ 30, 2  ],   #\n

	[ 31, 1  ],   #\n

	[ 32, 1  ],  #1
	[ 32, 2  ],  #;
	[ 32, 3  ],  #\n
	);





#####################################################################
# Test the locations of everything in the test code

# Prepare
my $Document = PPI::Document->new( \$test_source );
isa_ok( $Document, 'PPI::Document' );
ok( $Document->index_locations, '->index_locations returns true' );

# Now check the locations of every token
my @tokens = $Document->tokens;
is( scalar(@tokens), scalar(@test_locations), 'Number of tokens matches expected' );
foreach my $i ( 0 .. $#test_locations ) {
	my $location = $tokens[$i]->location;
	is( ref($location), 'ARRAY', "Token $i: ->location returns an ARRAY ref" );
	is( scalar(@$location), 2, "Token $i: ->location returns a 2 element ARRAY ref" );
	ok( ($location->[0] > 0 and $location->[1] > 0), "Token $i: ->location returns two positive positions" );
	is_deeply( $tokens[$i]->location, $test_locations[$i], "Token $i: ->location matches expected" );
}

ok( $Document->flush_locations, '->flush_locations returns true' );
is( scalar(grep { defined $_->{_location} } $Document->tokens), 0, 'All _location attributes removed' );

1;
