package AppLib::CGI;

# The AppLib::CGI module avoids a limitation with CGI.pm
# File upload parameters will ONLY work for the first CGI object
# created. Hence, this module caches the CGI object, instead of creating
# new ones.

use strict;
use UNIVERSAL 'isa';
use base 'AppLib::Error';
use CGI qw{-debug};

use vars qw{$cache};
BEGIN {
	$cache = undef;
}

sub new {
	my $class = shift;

	# Get the query if we don't have it already
	$cache = CGI->new( @_ ) unless $cache;
	return $cache;
}

# Pseudo emulation of the ReadParse function
# Returns a non-tied hash
use vars qw{%in};
sub ReadParse {
	my $class = shift;
	my $query = $class->new();

	# Build the hash
	my %hash = ();
	foreach ( $query->param ) {
		$hash{$_} = $query->param( $_ ) unless exists $hash{$_};
	}

	return \%hash;
}

# The scan method will scan a CGI query to determine a set of names
# within a certain namespace
# For example. Given a params of "a", "a_b", and "b", AppLib::CGI->scan would
# return ( "a", "b" ) and AppLib::CGI->scan( 'a' ) would return 'b'
sub scan {
	my $class = shift;
	my $query = shift;
	my $namespace = shift;
	$query = $class->new() unless $query;
	$namespace .= '_' if $namespace ne '';

	# Get the params list
	my @params = $query->param;

	# Go through the list and build the list
	my %names = ();
	foreach ( @params ) {
		if ( $_ =~ /^$namespace([a-zA-Z0-9]+)_?/ ) {
			$names{$1} = 1;
		}
	}

	return sort keys %names;
}

# Move an uploaded file to somewhere else
sub saveUpload {
	my $class = shift;
	my $name = shift;
	my $outfile = shift;

	# Get a handle
	my $query = $class->new();
	my $filename = $query->param( $name );
	return 0 unless $filename;

        # Copy a binary file to somewhere else
        my $rv = open ( OUTFILE, ">>$outfile" );
        return $class->andError( "Error opening output file '$outfile'" ) unless $rv;
        binmode OUTFILE;
        my ( $buffer, $bytesread );
        while ( $bytesread = read( $filename, $buffer, 1024 ) ) {
        	print OUTFILE $buffer;
        }
        close OUTFILE;
	return 1;
}

# Save a CGI request to a file
sub save {
	my $class = shift;
	my $filename = shift;
	my $query = $class->new;

	open( OUTFILE, ">$filename" ) or return undef;
	{
		no strict;
		$query->save( OUTFILE );
	}
	close OUTFILE;
	return 1;
}

sub header {
	# Pass through
	my $class = shift;
	return CGI::header( @_ );
}

1;

