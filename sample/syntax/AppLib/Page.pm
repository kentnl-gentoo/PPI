# See end of file for liscensing information

package AppLib::Page;

# The AppLib::Page module handles the load, parsing, and display
# of HTML pages

use strict;
use UNIVERSAL 'isa';
use base 'AppLib::Error';
use Class::Autouse qw{
	AppLib::PageFactory
	CGI
	File::Flat
	};





#####################################################################
# Constructor and main shortcut functions

# Create a new page
sub new {
	my $class = shift;
	my $name = shift or return undef;
	return isa( $_[0], 'AppLib::PageFactory' )
		? shift()->page($name, shift)
		: AppLib::PageFactory->page($name, shift);
}

# Make a new page and display it
sub show {
	my $Page = shift->new( @_ ) or return undef;
	return $Page->display ? 1 : undef;
}

# Make a new page and save it
sub freeze {
	my $file = $_[3] or return undef;
	my $Page = shift->new( @_ ) or return undef;
	return $Page->save( $file ) ? 1 : undef;
}





#####################################################################
# Changing Page Properties

# Read-Only properties
sub Name { $_[0]->{name} }
sub FileName { $_[0]->{filename} }

# Get and set the parser for the Page
sub getParser { $_[0]->{parser} }
sub setParser {
	my $self = shift;
	my $parser = shift;

	# Make the parser an object if it isn't
	if ( isa( $parser, 'AppLib::Parser' ) ) {
		$self->{parser} = $parser;
		return 1;

	} elsif ( isa( $parser, 'HASH' ) ) {
		$self->{parser} = AppLib::Parser->new( $parser ) || return undef;
		return 1;

	} else {
		return $self->andError( "Invalid parser argument" );
	}
}

# Get and set the source content
sub getSource {
	my $self = shift;

	# Load the source if needed
	unless ( defined $self->{source} ) {
		my $source = File::Flat->slurp( $self->{filename} );
		return $self->andError( "Error trying to load page '$self->{name}'" ) unless $source;
		$self->{source} = $$source;
	}

	return $self->{source};
}
sub setSource { $_[0]->{source} = $_[1]; 1; }

# Get and set the parsed content
sub getParsed {
	my $self = shift;

	# Shortcut if there is no parser
	return $self->getSource unless $self->{parser};

	# Get the source
	my $content = $self->getSource;
	return undef unless defined $content;
	my $parsed = $self->{parser}->parse( $content );
	return $self->andError( "Error parsing page" ) unless defined $parsed;

	# Hand off to our Factory to filter
	return $self->{filters}
		? $self->filter( $parsed )
			|| $self->andError( "Error filtering page" )
		: $parsed;
}

# Add a cookie to this particular page
sub setCookie {
	my $either = shift;
	my $cookie = shift;
	return undef unless isa( $cookie, 'CGI::Cookie' );
	if ( ref $either ) {
		# Add the cookie to this page
		if ( $either->{cookies} ) {
			push @{$either->{cookies}}, $cookie;
		} else {
			$either->{cookies} = [ $cookie ];
		}
	} else {
		# Pass through if called statically
		AppLib::PageFactory->setCookie( $cookie );
	}
	return 1;
}







#####################################################################
# Outputing Page Content

# Display the page
sub display {
	# Make sure we can get the page, then send
	my $content = $_[0]->getParsed or return undef;
	my $header = $_[0]->header or return undef;
	print STDOUT $header . $content;
	return 1;
}

# Generate the page header
sub header {
	my $either = shift or return undef;
	my @params = ();

	# Add the cookies to the headers if needed
	if ( ref $either and $either->{cookies} ) {
		# Detach the cookies, and
		# generate a header with them
		my $cookies = $either->{cookies};
		$either->{cookies} = undef;
		push @params, '-cookie', $cookies;
	}

	# CGI->header() throws warnings on some platforms,
	# in particular perl 5.6.1. To work around this, we
	# need to instantiate first.
	my $query = CGI->new();
	return $query->header( @params );
}

# Instead of displaying a page,
# save it to the file system
sub save {
	my $self = shift;
	my $filename = shift;

	# Make sure we have the parsed page
	my $content = $self->getParsed;
	return undef unless defined $content;

	# Reformat the page for our filesystem, and save
	$content =~ s/(\015\012|\015|\012)/\n/g;
	return File::Flat->save( $filename, \$content ) ? 1 : undef;
}

# Filter the parsed page
sub filter {
	my $self = shift;
	my $content = shift;

	# Pass the content to each of the filters
	foreach my $filter ( @{ $self->{filters} } ) {
		$content = &$filter( $self, $content );
		return undef unless defined $content;
	}

	# Done
	return $content;
}





#####################################################################
# Compatibility Methods
#
# Pass these through to the default PageFactory

sub setBasePath { AppLib::PageFactory->setBasePath( $_[1] ) }







#####################################################################
# Utility functions

# Scan the page for matching parser tags
sub scan {
	my $self = shift;
	unless ( ref $self ) {
		# Make a new object with the name
		$self = $self->new( shift ) or return undef;
	}
	my $tagroot = shift;

	# Make sure we have the source
	$self->getSource or return undef;

	# Scan the source and return the results
	my $results = AppLib::Parser->scan( $self->{source}, $tagroot );
	return $results ? $results : undef;
}

# Write an error message using nothing outside this function
# and nothing that can fail
sub safeError {
	shift;
	my $message = join "<br>", @_;
	print "Content-type: text/html\n\n";
	print qq~<html><head><title>Error</title></head>
		<body><h1>Error</h1>
		<p><font face="Verdana, Arial, Helvitica" size="2" color="#990000"><b>$message</b></font></p>~
		. AppLib::Error->calltraceHTML()
		. qq~</body></html>~;
}

1;





# Copyright (C) 2000-2002 Adam Kennedy ( software.applib@ali.as )
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
# Should you wish to utilise this software under a different licence,
# please contact the author.

