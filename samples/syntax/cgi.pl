#!/usr/bin/perl

# Demo syntax highlighting script for PPI ( Parse::Perl::Isolated )

use strict;
# use warnings;
# use diagnostics;

use FindBin;
use lib $FindBin::Bin, "$FindBin::Bin/../../modules";
use File::Spec;
use File::Find::Rule;
use AppLib;
use PPI;
use CGI;
BEGIN { $CGI::DEBUG = 2 }

# Initialise globals and modules
use vars qw{$fin $message $cmd};
use vars qw{$errstr};
BEGIN { 
	# Set the page path
	AppLib::Page->setBasePath( './html' );	
}

# Main application logic
initialise();
unless ( keys %$fin ) {
	viewFront();
} else {
	cmdProcess();
}
exit();

# Stuff to do on every call
sub initialise {
	# Get the CGI data
	$fin = AppLib::CGI->ReadParse;
}







#####################################################################
# Main action

sub cmdProcess {
	# Step 1 - Aquire the source code and create the processor
	my $PPI;
	if ( $fin->{source} eq 'file' ) {		
		$PPI = PPI->load( $fin->{source_file} );
		Error( "Failed to load file '$fin->{source_file}'" ) unless $PPI;
	
	} elsif ( $fin->{source} eq 'upload' ) {
		# Get the contents of the file
		Error( "You did not upload a file" ) unless $fin->{source_file};
		my $contents = AppLib::CGI->slurpUpload( $fin->{source_file} );
		ASError( "Could not get file contents" ) unless $contents;
		
		# Create the processor
		$PPI = PPI->new( $$contents );
		Error( "Failed to create processor from uploaded file" ) unless $PPI;
	
	} elsif ( $fin->{source} eq 'direct' ) {
		Error( "You did not enter any source code" ) unless $fin->{source_direct};
		
		# Create the processor
		$PPI = PPI->new( $fin->{source_direct} );
		Error( "Failed to create processor from direct input" ) unless $PPI;
	
	
	} elsif ( $fin->{source} eq 'stress' ) {
		Error( "You did not select a stress test" ) unless $fin->{source_stress};
		
		# Find the module ( Dodgy hack into Class::Autouse )
		my $file = &Class::Autouse::_class_file( $fin->{source_stress} );
		Error( "'$fin->{source_stress}' does not appear to be a valid module" ) unless $file;
		$file = &Class::Autouse::_file_exists( $file );
		Error( "Could not find module '$fin->{source_stress}' on the system" ) unless $file;

		# Load the module
		$PPI = PPI->load( $file );
		Error( "Failed to load module '$fin->{source_stress}' ($file)" ) unless $PPI;
				
	} else {
		Error( "Unknown data source option '$fin->{source}'" );
	}
	
	
	
	
	
	# Step 2 - Transforms
	if ( $fin->{transform} eq 'tidy' ) {
		$PPI->addTransform( 'tidy' ) or Error( "Error adding tidy transform command" );
	} elsif ( $fin->{transform} eq 'passthrough' ) {
		# Run the Document through the lexer/delexer to test it
		my $Lexer = PPI::Lexer->new( $PPI->document )
			or Error( "Error creating lexer" );
		my $Tree = $Lexer->getTree
			or Error( "Failed to get parse tree" );
		my $Document = $Tree->Document
			or Error( "Failed to convert Tree into Document" );
			
		# Set the document back into the source code handler the hacky way
		$PPI->{Document} = $Document;		
	} elsif ( $fin->{transform} eq 'none' ) {
		# Do nothing
	} else {
		Error( "That transform is not available at this time" );
	}
	
	
	
	
	
	# Handle the special "download the plain file" case
	if ( $fin->{display} eq 'plain'
	 and $fin->{delivery} eq 'download' 
	) {
		AppLib::Client->send( 'plain.txt', $PPI->toString );
		exit();
	}
	 	
	
	# Step 3 - Display layout
	my $output;
	if ( $fin->{display} eq 'syntax'
	  or $fin->{display} eq 'debug'
	  or $fin->{display} eq 'plain'
	) {
		# Create the options
		my $options = {};
		$options->{linenumbers} = 1 if $fin->{line_numbers};
		
		# Generate the html
		$output = $PPI->html( $fin->{display}, $options );
		Error( "Error getting html page version of Perl Source Document" ) unless $output;
		
		# Wrap in a page
		$output = PPI::Format::HTML->wrapPage( $fin->{display}, $output );
		$output =~ s/^\s+//gm;
	} else {
		Error( "Unknown display format '$fin->{display}'" );
	}
	
	
	
	# Deliver the output
	if ( $fin->{delivery} eq 'browser' ) {
		print AppLib::CGI->header;
		print $output;
	
	} elsif ( $fin->{delivery} eq 'download' ) {
		# Send it to their browser
		AppLib::Client->send( 'formatted.html', $output );
		
	} else {
		Error( "Unknown display method '$fin->{display}'" );
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
		$modules = [ map { [ $_, $_ ] } @$modules ];
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
	my $message = join "<br>", ( @_, PPI->errstrConsole );
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
