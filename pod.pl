#!/usr/bin/perl

use lib '../../modules';
use UNIVERSAL 'isa';
use PPI;

my $filename = (defined $ARGV[0] and -r $ARGV[0]) ? shift @ARGV : 'input.pl';

# Load the test source
my $source;
{
	$/ = undef;
	open( FILE, $filename ) or die "open: $!";
	$source = <FILE>;
	close FILE;
}

# Create the tokenizer
my $Tokenizer = new PPI::Tokenizer( source => $source ) or die "Failed to create Tokenizer";
my $tokens = $Tokenizer->all_tokens;

# Create a merged pod document
my $Pod = PPI::Token::Pod->merge( grep { isa( $_, 'PPI::Token::Pod' ) } @$tokens );
if ( $Pod ) {
	print $Pod->content;
} else {
	print "Failed to find and merge pod\n";
}

1;

