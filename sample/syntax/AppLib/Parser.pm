# See end of file for licensing information

package AppLib::Parser;

# Simple module to handle parsing in AppLib applications
# primary in AppEdit, which need to do things like this more
# often.
#
# AppLib::Parser objects can and should be treated EXACTLY
# like a normal hash. That is, you shouldn't add normal
# parser elements to the parser through the use of methods,
# you can just $parser->{key} = $value
#
# What having the parser as an object does, is add a convenient
# handle for running functions using the parser, when the functions
# would otherwise just end up handing around in the application

use strict;
use UNIVERSAL 'isa';
use base 'AppLib::Error';





#####################################################################
# Class level configuration

sub defaults {
	return {
		string => '\[(\w+)\]',
		rootscan => '\[root_(\w+)\]',
		replace_start => '[',
		replace_end => ']',
		};
}





#####################################################################
# Constructors and friends

sub new {
	my $class = shift;
	my $self = ref $_[0] eq 'HASH' ? shift : {};
	bless $self, $class;

	# Set the optional match ends
	if ( ref $_[0] eq 'ARRAY' ) {
		$self->{' __match'} = $_[0];
	} else {
		$self->{' __match'} = $self->defaults;
	}
	$self->{' __safe_mode'} = 0;

	return $self;
}

# Make a full copy of the existing parser
sub clone { return bless {%{$_[0]}}, ref $_[0] }

# "Safe Mode" parsing ONLY parses things it finds in the hash
# Anything that isn't in the hash is explicitly left where it is
# This can be handy for not breaking JavaScript, but is less
# flexible, as you can't rely on something not being in the parser to
# blank out a parser tag.
sub safeMode {
	my $self = shift;
	if ( defined $_[0] ) {
		$self->{' __safe_mode'} = $_[0] ? 1 : 0;
	}
	return $self->{' __safe_mode'};
}




#####################################################################
# Manipulating the parser

# Add another parser to ours. Overwrite our elements
sub add {
	my $self = shift;
	my $parser = shift;
	return undef unless isa( $parser, 'HASH' );

	foreach ( keys %$parser ) {
		$self->{$_} = $parser->{$_};
	}
	return 1;
}




#####################################################################
# Methods to do the parsing

# Base parsing fuction
# Accepts a large range of things to parse into and splits
# into the appropriate functions
sub parse {
	my $self = shift;
	my $content = shift;

	if ( isa( $content, 'SCALAR' ) ) {
		return $self->_parseScalar( $content );

	} elsif ( isa( $content, 'ARRAY' ) ) {
		return $self->_parseArray( $content );

	} elsif ( ref $content ) {
		return $self->andError( "Invalid argument to parser" );

	} elsif ( defined $content ) {
		# To avoid copying the entire variable again,
		# do the parsing by reference
		my $result = $self->_parseScalar( \$content );
		return $result ? $content : undef;

	} else {
		return $self->andError( "Invalid argument to parser" );

	}
}

# Parse a reference to a scalar
sub _parseScalar {
	my $self = shift;
	my $content = shift;

	# Do the parsing
	my $match = $self->{' __match'}->{string};
	if ( $self->{' __safe_mode'} ) {
		$$content =~ s{$match}
			{exists $self->{$1}
				? $self->{$1}
				: ( $self->{' __match'}->{replacestart} . $1 . $self->{' __match'}->{replaceend} )
			}ge;
	} else {
		# Turn off warning to avoid warnings when there is a tag in
		# the template that doesn't exist in the hash
		{ no warnings;
			$$content =~ s/$match/$self->{$1}/g;
		}
	}

	return $content;
}

# Takes a reference to an array
sub _parseArray {
	my $self = shift;
	my $content = shift;

	# Do the parsing
	my $match = $self->{' __match'}->{string};
	if ( $self->{' __safe_mode'} ) {
		foreach ( 0 .. $#$content ) {
			$content->[$_] =~ s{$match}
			{exists $self->{$1}
				? $self->{$1}
				: ( $self->{' __match'}->{replacestart} . $1 . $self->{' __match'}->{replaceend} )
			}ge;
		}
	} else {
		foreach ( 0 .. $#$content ) {
			$content->[$_] =~ s/$match/$self->{$1}/g;
		}
	}

	return $content;
}




#####################################################################
# Scanning Methods

# The scan method takes a content source ( scalar, scalar ref, array ref )
# and scans it to determine all the strings that match in the content,
# returning it as a hash reference with the string as the key, and the
# occurance count as the value
#
# It is worth noting that scanning can slow down the display process
# It is only normally worth it in situations where only a small number
# of a potentially large parser need to be created, or when creating
# the parser entries may take a computationally non-trivial amount of time

sub scan {
	my $either = shift;
	my $class = ref $either || $either;
	my $content = shift;
	my $root = shift;

	# Find the match string
	my $match = ref $either
		? defined $root
			? $either->{' __match'}->{rootscan}
			: $class->defaults()->{rootscan}
		: defined $root
			? $either->{' __match'}->{string}
			: $class->defaults()->{string};
	$match =~ s/root/$root/g if defined $root;

	# Split on argument type
	if ( isa( $content, 'SCALAR' ) ) {
		return $class->_scanScalar( $content, $match );

	} elsif ( isa( $content, 'ARRAY' ) ) {
		return $class->_scanArray( $content, $match );

	} elsif ( ref $content ) {
		return $class->andError( "Invalid argument to parser" );

	} elsif ( defined $content ) {
		# To avoid copying the entire variable again,
		# do the scanning by reference
		return $class->_scanScalar( \$content, $match );

	} else {
		return $class->andError( "Invalid argument to parser" );

	}
}

sub _scanScalar {
	my $class = shift;
	my $content = shift or return undef;
	my $match = shift or return undef;

	# Build and return the hash
	my %hash = ();
	$hash{$_}++ foreach $$content =~ m/$match/g;
	return \%hash;
}

sub _scanArray {
	my $class = shift;
	my $content = shift or return undef;
	my $match = shift or return undef;

	# Build and return the hash
	my %hash = ();
	foreach my $i ( 0 .. $#$content ) {
		$hash{$_}++ foreach ${$content->[$i]} =~ m/$match/g;
	}
	return \%hash;
}

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

