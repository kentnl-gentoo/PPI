package AppLib::CGI;

# The AppLib::CGI module avoids a limitation with CGI.pm
# File upload parameters will ONLY work for the first CGI object
# created. Hence, this module caches the CGI object, instead of creating
# new ones.

use strict;
use UNIVERSAL 'isa';
use base 'AppLib::Error';
use CGI;
use vars qw{$cache};
BEGIN {
	$cache = undef;
	$CGI::DEBUG = $CGI::DEBUG = 2;
}

# Get the query if we don't have it already
sub new {
	my $class = shift;
	$cache or $cache = CGI->new( @_ );
}

# The scan method will scan a CGI query to determine a set of names
# within a certain namespace
# For example. Given a params of "a", "a_b", and "b", AppLib::CGI->scan would
# return ( "a", "b" ) and AppLib::CGI->scan( 'a' ) would return 'b'
sub scan {
	my $class = shift;
	my $query = shift;
	my $namespace = shift;
	$query = $class->new unless $query;
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

	sort keys %names;
}

# Move an uploaded file to somewhere else
sub saveUpload {
	my $class = shift;
	my $name = shift;
	my $outfile = shift;

	# Get a handle
	my $query = $class->new();
	my $filename = $query->param( $name ) or return 0;

        # Copy a binary file to somewhere else
        my $rv = open ( OUTFILE, ">>$outfile" )
        	or return $class->andError( "Error opening output file '$outfile'" );
        binmode OUTFILE;
        my ( $buffer, $bytesread );
        while ( $bytesread = read( $filename, $buffer, 1024 ) ) {
        	print OUTFILE $buffer;
        }
        close OUTFILE;
	1;
}

# Save a CGI request to a file
sub save {
	my $class = shift;
	my $query = $class->new;

	no strict;
	open( OUTFILE, ">$_[0]" ) or return undef;
	$query->save( OUTFILE );
	close OUTFILE;
	1;
}

sub header {
	# Pass through to the function form
	shift; CGI::header( @_ );
}

1;
