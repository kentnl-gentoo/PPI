# See end of file for licensing information

package AppLib::PageFactory;

# The AppLib::PageFactory class defines an environment
# in which AppLib::Page objects are created.
# Theme support has been removed from the default factory.
# Anyone needing theme support should use the AppLib::PageFactory::Themable
# class.

use strict;
use UNIVERSAL 'isa';
use base 'Class::Default',
         'AppLib::Error';
use Class::Autouse qw{AppLib::Page};
use File::Spec;





# Constructor
sub new {
	my $class = shift;
	my $self = {
		basePath => '.',
		Pages => {},
		cookies => [],
		filters => [],
		};
	bless $self, $class;

	# Set the base path if they passed it
	$self->setBasePath( scalar @_ ? shift : '.' ) or return undef;

	return $self;
}





# Base path
sub setBasePath {
	my $self = shift->_self;
	my $path = shift or return undef;

	# Check the path
	unless ( $self->_dirExists( $path ) ) {
		return $self->andError( "Path '$path' for PageFactory does not exist" );
	}

	# Fully resolve the path
	$path = File::Spec->rel2abs( $path );
	return $self->andError( "Failed to fully resolve path" ) unless $path;

	# Set the base path
	$self->{basePath} = $path;
}
sub getBasePath { $_[0]->self->{basePath} }

# Page map
sub getPage  { $_[0]->_self->{Pages}->{$_[1]} }
sub setPage  { $_[0]->_self->{Pages}->{$_[1]} = $_[2] }
sub getPages { {%{ $_[0]->_self->{Pages} }} }
sub setPages {
	my $self = shift->_self;
	my $hash = shift;
	return undef unless isa( $hash, 'HASH' );

	# Add ( and overwrite ) to the Pages hash
	foreach ( keys %$hash ) {
		$self->{Pages}->{$_} = $hash->{$_};
	}
	return 1;
}

# Page filters.
# A page filter is a function pointer that is called
# on the page content after it is has come out of the parser
# but before it is returned/displayed.
# It allows you to apply changes to pages after they have been
# generated, such as alterring colour schemes, adding messages etc.
# Filters for a PageFactory will be applyed to any pages created
# from it.
sub clearFilters { $_[0]->_self->{filters} = [] }
sub addFilter {
	my $self = shift->_self;
	my $function = shift;

	# Check arguments
	unless ( ref $function eq 'CODE' ) {
		return $self->andError( "Filters must be code references" );
	}

	push @{$self->{filters}}, $function;
	return 1;
}

# Clear the cookies
sub clearCookies {
	my $self = shift->_self;
	$self->{cookies} = [];
	return 1;
}

# Add a cookie to the next generated page
sub setCookie {
	my $self = shift->_self;
	my $cookie = shift;
	return undef unless isa( $cookie, 'CGI::Cookie' );

	push @{$self->{cookies}}, $cookie;
	return 1;
}





#####################################################################
# Main Interface Methods

# Does a page exist
sub pageExists {
	my $self = shift->_self;
	my $name = shift or return 0;

	# Does it exist already
	if ( $self->{Pages}->{$name} ) {
		return $self->_fileExists( $self->{Pages}->{$name} );
	}

	# Try and guess the file name, and add it to the page
	# hash if we can find it.
	if ( $self->_fileExists("$self->{basePath}/$name.html") ) {
		$self->setPage( $name, "$name.html" );
		return 1;
	} elsif ( $self->_fileExists("$self->{basePath}/$name.htm") ) {
		$self->setPage( $name, "$name.htm" );
		return 1;
	}

	return 0;
}

# Build a new page
sub page {
	my $self = shift->_self;
	my $name = shift;
	my $parser = shift;

	# Create the new object
	my $Page = {
		name => undef,
		parser => undef,
		cookies => undef,
		filters => undef,
		};
	bless $Page, 'AppLib::Page';

	# Check and set the page
	if ( $name ) {
		unless ( $self->pageExists( $name ) ) {
			return $self->andError( "The page '$name' does not exist" );
		}
		$Page->{name} = $name;
		$Page->{filename} = $self->getFileName($name) or return undef;
	} else {
		# Set the source to something
		# so we don't need a page name
		$Page->{source} = '';
	}

	# Set the parser if passed
	if ( $parser ) {
		$Page->setParser( $parser ) or return undef;
	}

	# If any cookies have accumulated in
	# the Factory, give them to the page
	if ( scalar @{ $self->{cookies} } ) {
		$Page->{cookies} = $self->{cookies};
		$self->{cookies} = [];
	}

	# Add all the page filters to the page
	if ( scalar @{ $self->{filters} } ) {
		$Page->{filters} = [ @{$self->{filters}} ];
	}

	# Return the object
	return $Page;
}

# Get the full filename for a page
sub getFileName {
	my $self = shift->_self;
	return $self->{basePath} . '/' . $self->getPage( shift );
}





#####################################################################
# Utility methods

sub _fileExists { (-e $_[1] and -f $_[1] and -r $_[1]) ? 1 : undef }
sub _dirExists { (-e $_[1] and -d $_[1]) ? 1 : undef }

1;

__END__

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

