#!/usr/bin/perl

use lib '../../modules';
use UNIVERSAL 'isa';
use PPI::Tokenizer ();
use PPI::Document ();

my $filename = (defined $ARGV[0] and -r $ARGV[0]) ? shift @ARGV : $INC{'PPI/Token/Classes.pm'};

# Create the tokenizer
my $Tokenizer = PPI::Tokenizer->load( $filename ) or die "Failed to create Tokenizer";
my $tokens = $Tokenizer->all_tokens or die( "Error getting tokens at line $Tokenizer->{line_count} ('$Tokenizer->{line_buffer}'): "
	. $Tokenizer->errstr  );
print "Found " . scalar(@$tokens) . " tokens\n";

if ( 0 ) {
	# Create the document
	my $Document = PPI::Document->new();
	$Document->lex( $Tokenizer ) or die "Error during lex";
}

if ( 0 ) {
	# Print the tokens
	my $counter = 0;
	my $digits = length $#$tokens;
	foreach ( @$tokens ) {
		$counter++;

		my $content = $_->content;
		$content =~ s/\n/\\n/g;
		$content =~ s/\t/\\t/g;

		my $class = ref $_;

		printf "%${digits}d: %-27s '%s'\n", $counter, $class, $content;
	}
}

1;
