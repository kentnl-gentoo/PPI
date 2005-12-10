#!/usr/bin/perl -w

# Exhaustively test all possible Perl programs to a particular length

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
use Carp 'croak';

use vars qw{$MAX_CHARS @ALL_CHARS};
BEGIN {
	# When distributing, keep this in to verify the test script
	# is working correctly, but limit to 2 (maaaaybe 3) so we
	# don't slow the install process down too much.
	$MAX_CHARS = 2;
	@ALL_CHARS = (
		qw{a b c f g m q r s t w x y z V W X 0 1 8 9},
		';', '[', ']', '{', '}', '(', ')', '=', '?', '|', '+', '<', '>', '.',
		'!', '~', '^', '*', '$', '@', '&', ':', '%', '#', ',', "'", '"', '`',
		'\\', '/', '_', ' ', "\n", "\t", '-',
		);
	#my @ALL_CHARS = (
	#	qw{a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H
	#	I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9},
	#	';', '[', ']', '{', '}', '(', ')', '=', '?', '|', '+', '<', '>', '.',
	#	'!', '~', '^', '*', '$', '@', '&', ':', '%', '#', ',', "'", '"', '`',
	#	'\\', '/', '_', ' ', "\n", "\t", '-',
	#	);
}





#####################################################################
# Prepare

use Test::More tests => $MAX_CHARS;





#####################################################################
# Code/Dump Testing

my $failures   = 0;
my $last_index = scalar(@ALL_CHARS) - 1;
LENGTHLOOP:
foreach my $len ( 1 .. $MAX_CHARS ) {
	# Initialise the char array and failure count
	my $failures = 0;
	my @chars    = (0) x $len;

	# The main test loop
	CHARLOOP:
	while ( 1 ) {
		# Test the current set of chars
		my $code = join '', map { $ALL_CHARS[$_] } @chars;
		unless ( length($code) == $len ) {
			die "Failed sanity check. Error in the code generation mechanism";
		}
		test_code( $code );

		# Increment the last character
		$chars[$len - 1]++;

		# Cascade the wrapping as needed
		foreach ( reverse( 0 .. $len - 1 ) ) {
			next CHARLOOP unless $chars[$_] > $last_index;
			if ( $_ == 0 ) {
				# End of the iterations, move to the next length
				last CHARLOOP;
			}

			# Carry to the previous char
			$chars[$_] = 0;
			$chars[$_ - 1]++;
		}
	}
	is( $failures, 0, "No tokenizer failures for all $len-length programs" );
}

exit(0);

sub test_code {
	my $code      = shift;
	my $Tokenizer = PPI::Tokenizer->new(\$code);
	my $tokens    = eval {
		$SIG{__WARN__} = sub { croak('Triggered a warning') };
		$Tokenizer->all_tokens;
	};

	# Version of the code for use in error messages
	my $quotable = $code;
	$quotable =~ s/\t/\\t/g;
	$quotable =~ s/\n/\\n/g;

	if ( $PPI::Tokenizer::errstr ) {
		$failures++;
		diag( "'$quotable': Tokenizer returned an error" );
		return;
	}
	unless ( ref($tokens) eq 'ARRAY' ) {
		$failures++;
		diag( "'$quotable': Tokenizer did not return an ARRAY" );
		return;
	}
	my $joined = join '', map { $_->content } @$tokens;
	unless ( $joined eq $code ) {
		$failures++;
		diag( "'$quotable': Tokens naively round-trip ok" );
		return;
	}
}
