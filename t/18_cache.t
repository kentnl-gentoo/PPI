#!/usr/bin/perl -w

# Test compatibility with Storable

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
use PPI::Cache     ();
use PPI::Document  ();
use File::Remove   ();
use Scalar::Util   'refaddr';
use Test::More tests => 33;
use Test::SubCalls;

my $this_file = catdir( 't.data', '03_empiric', 'test.dat' );
my $cache_dir = catdir( 't.data', '18_cache' );

# Define, create and clear the test cache
File::Remove::remove( \1, $cache_dir ) if -e $cache_dir;
ok( ! -e $cache_dir, 'The cache path does not exist' );
END { File::Remove::remove( \1, $cache_dir ) if -e $cache_dir }
ok( scalar(mkdir $cache_dir), 'mkdir $cache_dir returns true' );
ok( -d $cache_dir, 'Verified the cache path exists' );
ok( -w $cache_dir, 'Can write to the cache path'    );






#####################################################################
# Basic Testing

# Create a basic cache object
my $Cache = PPI::Cache->new(
	path => $cache_dir,
	);
isa_ok( $Cache, 'PPI::Cache' );
is( scalar($Cache->path), $cache_dir, '->path returns the original path'    );
is( scalar($Cache->readonly), '',      '->readonly returns false by default' );

# Create a test document
my $doc = PPI::Document->new( \'print "Hello World!\n";' );
isa_ok( $doc, 'PPI::Document' );
my $doc_md5  = '64568092e7faba16d99fa04706c46517';
my $doc_file = catfile($cache_dir, '6', '64', '64568092e7faba16d99fa04706c46517.ppi');
my $bad_md5  = 'abcdef1234567890abcdef1234567890';
my $bad_file = catfile($cache_dir, 'a', 'ab', 'abcdef1234567890abcdef1234567890.ppi');

# Save to an arbitrary location
ok( $Cache->_store($bad_md5, $doc), '->_store returns true' );
ok( -f $bad_file, 'Created file where expected' );
my $loaded = $Cache->_load($bad_md5);
isa_ok( $loaded, 'PPI::Document' );
is_deeply( $doc, $loaded, '->_load loads the same document back in' );

# Store the test document in the cache in it's proper place
is( scalar( $Cache->store_document($doc) ), 1,
	'->store_document(Document) returns true' );
ok( -f $doc_file, 'The document was stored in the expected location' );

# Check the _md5hex method
is( PPI::Cache->_md5hex(\'print "Hello World!\n";'), $doc_md5,
	'->_md5hex returns as expected for sample document' );
is( PPI::Cache->_md5hex($doc_md5), $doc_md5,
	'->_md5hex null transform works as expected' );
is( $Cache->_md5hex(\'print "Hello World!\n";'), $doc_md5,
	'->_md5hex returns as expected for sample document' );
is( $Cache->_md5hex($doc_md5), $doc_md5,
	'->_md5hex null transform works as expected' );

# Retrieve the Document by content
$loaded = $Cache->get_document( \'print "Hello World!\n";' );
isa_ok( $loaded, 'PPI::Document' );
is_deeply( $doc, $loaded, '->get_document(\$source) loads the same document back in' );

# Retrieve the Document by md5 directly
$loaded = $Cache->get_document( $doc_md5 );
isa_ok( $loaded, 'PPI::Document' );
is_deeply( $doc, $loaded, '->get_document($md5hex) loads the same document back in' );






#####################################################################
# Empiric Testing

# Load a test document twice, and see how many tokenizer objects get
# created internally.
is( PPI::Document->get_cache, undef,    'PPI::Document cache initially undef' );
ok( PPI::Document->set_cache( $Cache ), 'PPI::Document->set_cache returned true' );
isa_ok( PPI::Document->get_cache, 'PPI::Cache' );
is( refaddr($Cache), refaddr(PPI::Document->get_cache),
	'->get_cache returns the same cache object' );

# Set the tracking on the Tokenizer constructor
ok( sub_track( 'PPI::Tokenizer::new' ), 'Tracking calls to PPI::Tokenizer::new' );
sub_calls( 'PPI::Tokenizer::new', 0 );
my $doc1 = PPI::Document->new( $this_file );
my $doc2 = PPI::Document->new( $this_file );
isa_ok( $doc1, 'PPI::Document' );
isa_ok( $doc2, 'PPI::Document' );
SKIP: {
	unless ( $doc1 and $doc2 ) {
		skip( "Skipping due to previous failures", 3 );
	}
	sub_calls( 'PPI::Tokenizer::new', 1,
		'Two calls to PPI::Document->new results in one Tokenizer object creation' );
	ok( refaddr($doc1) != refaddr($doc2),
		'PPI::Document->new with cache enabled does NOT return the same object' );
	is_deeply( $doc1, $doc2,
		'PPI::Document->new with cache enabled returns two identical objects' );
}

1;
