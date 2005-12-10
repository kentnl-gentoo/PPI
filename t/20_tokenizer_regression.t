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
use Carp 'croak';

sub pause {
	local $@;
	eval { require Time::HiRes; };
	$@ ? sleep(1) : Time::HiRes::sleep(0.1);
}





#####################################################################
# Prepare

use Test::More tests => 303;

my @FAILURES = (
	# Failed cases 3 chars or less
	'!%:', '!%:',  '!%:',  '!%:',  '!*:', '!@:',  '%:',  '%:,',
	'%:;', '*:',   '*:,',  '*::',  '*:;', '+%:',  '+*:', '+@:',
	'-%:', '-*:',  '-@:',  ';%:',  ';*:', ';@:',  '@:',  '@:,',
	'@::', '@:;',  '\%:',  '\&:',  '\*:', '\@:',  '~%:', '~*:',
	'~@:', '(<',   '(<',   '=<',   'm(',  'm(',   'm<',  'm[',
	'm{',  'q(',   'q<',   'q[',   'q{',  's(',   's<',  's[',
	's{',  'y(',   'y<',   'y[',   'y{',  '$\'0', '009', '0bB',
	'0xX', '009;', '0bB;', '0xX;', "<<'", '<<"',  '<<`', '&::',
	'<<a', '<<V',  '<<s',  '<<y',  '<<_',

	# Failed cases 4 chars long.
	# This isn't the complete set, as they tend to fail in groups
	# of 50 or so, but I've used a representative sample.
	'm;;_', 'm[]_', 'm]]_', 'm{}_', 'm}}_', 'm--_', 's[]a', 's[]b',
	's[]0', 's[];', 's[]]', 's[]=', 's[].', 's[]_', 's{}]', 's{}?',
	's<>s', 's<>-',
	'*::0', '*::1', '*:::', '*::\'', '$::0',  '$:::', '$::\'',
	'@::0', '@::1', '@:::', '&::0',  '&::\'', '%:::', '%::\'',
	);





#####################################################################
# Code/Dump Testing

foreach my $code ( @FAILURES ) {
	test_code( $code );
}

exit();

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

        is( $PPI::Tokenizer::errstr, '',
        	"'$quotable': Tokenized without errors" );
        is( ref($tokens), 'ARRAY',
        	"'$quotable': Tokenizer returns an ARRAY ref" );
        SKIP: {
        	skip("No tokens to round-trip test", 1) unless $tokens;
		is( join( '', map { $_->content } @$tokens ), $code,
			"'$quotable': Tokens naively round-trip ok" );
	}
}
