#!/usr/bin/perl

# Process and convert to html syntax highlighted pages a set of files and directories

use strict;
use warnings;
use diagnostics;

use FindBin;
use lib $FindBin::Bin, "$FindBin::Bin/../../modules";
use Perl;
use Perl::Batch;

sub error($);

# Create the batch processor
my $Batch = Perl::Batch->new() or error "Failed to create batch processor";
$Batch->setCallback( sub {
	print "Generating html for '$_[2]'...\n";
	return 1;
} );

# Go over each of the files and add them
unless ( scalar @ARGV ) {
	error "You did not enter any files or directories";
}
print "Adding files...\n";
foreach my $file ( @ARGV ) {
	if ( $file eq '-t' ) {
		$Batch->addTransform( 'tidy' );
		next;
	}
	
	# Strip possible trailing slashes
	$file =~ s!(.)/$!$1!;
	
	if ( ! -e $file ) {
		error "File '$file' does not exist";
	} elsif ( -d $file ) {
		# Add as a directory
		$Batch->loadDirectory( $file ) or error "Failed to add directory '$file'";
	} else {
		# Add as a normal file
		$Batch->load( $file ) or error "Failed to add file '$file'";
	}
}

# Done, now lets save them
my $saveas = sub {
	my $file = shift;
	$file =~ s/(\.\w+)$/$1.html/;
	$file =~ s/\.\./dotdot/g;
	return $file;
	};
my $rv = $Batch->save( './source', $saveas, 'htmlPage', 'syntax', { linenumbers => 1 } )
  or error "Error while trying to save batch";
  
# Done
print "Batch run completed\n";
exit(0);

sub error($) {
	my $msg = shift;
	print join '', map { "$_\n" } ($msg, Perl->errstrConsole);
	exit(1);
}
