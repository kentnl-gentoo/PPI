#!/usr/bin/perl

# Demo syntax highlighting script for PPI

use strict;
# use warnings;
# use diagnostics;

# In development, get the devel versions of modules
use FindBin;
use lib "$FindBin::Bin/../../../modules";
use lib '.';
use File::Spec;
use File::Find::Rule;
use CGI; BEGIN { $CGI::DEBUG = 2 }
use CGI::Carp qw{fatalsToBrowser};
use List::Util 'first';
use AppLib::CGI;
use AppLib::Page;
use AppLib::PageFactory;
use AppLib::Parser;
use AppLib::HTML::Form;
use PPI ();
use PPI::Format::HTML ();

# Initialise globals and modules
use vars qw{%in $message $cmd};
use vars qw{$errstr};
BEGIN {
	# Set the page path
	AppLib::Page->setBasePath( 
		File::Spec->catdir( File::Spec->curdir, 'html' )
		);
}

# Main application logic
initialise();
unless ( keys %in ) {
	viewFront();
} else {
	cmdProcess();
}
exit();

# Stuff to do on every call
sub initialise {
	# Get the CGI data
	CGI::ReadParse();
}







#####################################################################
# Main action

sub cmdProcess {
	# Step 1 - Aquire the source code and create the processor
	my $PPI;
	if ( $in{source} eq 'file' ) {
		$PPI = PPI->load( $in{source_file} );
		Error( "Failed to load file '$in{source_file}'" ) unless $PPI;

	} elsif ( $in{source} eq 'upload' ) {
		# Get the contents of the file
		Error( "You did not upload a file" ) unless $in{source_file};
		my $contents = AppLib::CGI->slurpUpload( $in{source_file} );
		ASError( "Could not get file contents" ) unless $contents;

		# Create the processor
		$PPI = PPI->new( $$contents );
		Error( "Failed to create processor from uploaded file" ) unless $PPI;

	} elsif ( $in{source} eq 'direct' ) {
		Error( "You did not enter any source code" ) unless $in{source_direct};

		# Create the processor
		$PPI = PPI->new( $in{source_direct} );
		Error( "Failed to create processor from direct input" ) unless $PPI;


	} elsif ( $in{source} eq 'stress' ) {
		Error( "You did not select a stress test" ) unless $in{source_stress};

		# Find the module
		my $file = File::Spec->catfile( split /::/, $in{source_stress} ) . '.pm';
		$file = first { -f $_ and -r $_ } map { File::Spec->catfile( $_, $file ) } @INC;
		Error( "Could not find module '$in{source_stress}' on the system" ) unless $file;

		# Load the module
		$PPI = PPI->load( $file );
		Error( "Failed to load module '$in{source_stress}' ($file)" ) unless $PPI;

	} else {
		Error( "Unknown data source option '$in{source}'" );
	}





	# Step 2 - Transforms
	if ( 0 ) {
	if ( $in{transform} eq 'tidy' ) {
		$PPI->add_transform( 'tidy' ) or Error( "Error adding tidy transform command" );
	} elsif ( $in{transform} eq 'passthrough' ) {
		# Run the Document through the lexer/delexer to test it
		my $Lexer = PPI::Lexer->new( $PPI->document )
			or Error( "Error creating lexer" );
		my $Tree = $Lexer->get_tree
			or Error( "Failed to get parse tree" );
		my $Document = $Tree->Document
			or Error( "Failed to convert Tree into Document" );

		# Set the document back into the source code handler the hacky way
		$PPI->{Document} = $Document;
	} elsif ( $in{transform} eq 'none' ) {
		# Do nothing
	} else {
		Error( "That transform is not available at this time" );
	}
	}





	# Handle the special "download the plain file" case
	if ( $in{display} eq 'plain'
	 and $in{delivery} eq 'download'
	) {
		AppLib::Client->send( 'plain.txt', $PPI->toString );
		exit();
	}


	# Step 3 - Display layout
	my $output;
	if ( $in{display} eq 'syntax'
	  or $in{display} eq 'debug'
	  or $in{display} eq 'plain'
	) {
		# Create the options
		my $options = {};
		$options->{linenumbers} = 1 if $in{line_numbers};

		# Generate the html
		$output = $PPI->html( $in{display}, $options );
		Error( "Error getting html page version of Perl Source Document" ) unless $output;

		# Wrap in a page
		$output = PPI::Format::HTML->wrap_page( $in{display}, $output );
		$output =~ s/^\s+//gm;
	} else {
		Error( "Unknown display format '$in{display}'" );
	}



	# Deliver the output
	if ( $in{delivery} eq 'browser' ) {
		print AppLib::CGI->header;
		print $output;

	} elsif ( $in{delivery} eq 'download' ) {
		# Send it to their browser
		AppLib::Client->send( 'formatted.html', $output );

	} else {
		Error( "Unknown display method '$in{display}'" );
	}

	exit();
}

#####################################################################
# Views

sub viewFront {
	my $parser = new_parser();

	# Determine all the installed modules
	my $modules = all_modules();
	if ( $modules ) {
		$modules = [ map { [ $_, $_ ] } grep { ! /^(?:5\.|i386\-)/ } @$modules ];
		$parser->{module_selector} = AppLib::HTML::Form->dropbox( 'source_stress', $modules );
	} else {
		$parser->{module_selector} = qq~<input type="text" name="source_stress">~;
	}

	show_page( 'Front', $parser );
}








#####################################################################
# Copied in from the AppLib scripts

sub new_parser { AppLib::Parser->new() }

# Displays an error
sub viewError {
	# Establish the error message
	my $message = shift;
	$message = $errstr unless $message;
	$message = "Unknown error" unless $message;

	# Create a fresh parser
	my $parser = new_parser();
	$parser->{message} = $message;

	# Load the page
	return AppLib::Page->show( 'Error', $parser );

}

# Write an error message using nothing outside this function
# and nothing that can fail
sub viewErrorSafe {
	my $message = shift;
	print "Content-type: text/html\n\n";
	print "<HTML><HEAD><TITLE>Error</TITLE></HEAD>\n";
	print "<BODY><H1>Error</H1>\n";
	print "<i>$message</i>\n";
	print "</BODY></HTML>\n";
}


sub show_page {
	# Show the templated page
	return if AppLib::Page->show( @_ );
	Error( "Error trying to show page<br>" . AppLib::Error->errstrHTML );
}

# Handle errors
sub Error {
	my $message = join "<br>", ( @_, PPI->errstr_console );
	$message =~ s/\n/<br>/g;

	# Try to show the error page
	unless ( viewError( $message ) ) {
		# First error call didn't work, try the simple one
		viewErrorSafe( $message
			. '<br><br>In addition, an error occurred while trying to display the error page<br>'
			. AppLib::Page->errstr );
	}
	exit;
}

sub ASError {
	my @message = @_, AppLib->errstrConsole;
	Error( @message );
}

sub andError {
	$errstr = shift;
	return undef;
}

# Determine all the modules installed on the system
sub all_modules {
	my %modules = ();
	foreach my $dir ( @INC ) {
		# Get the files
		my @files = File::Find::Rule->file()
			->name('*.pm')
			->in( $dir );

		# Trim to relative path
		@files = map { File::Spec->abs2rel( $_, $dir ) } @files;

		# Make into module names
		@files = grep { s!/!::!g; s/\.pm$//; 1 } @files;

		# Apply to the hash
		$modules{$_} = 1 foreach @files;
	}

	return scalar keys %modules
		? [ sort keys %modules ]
		: 0;
}

1;
