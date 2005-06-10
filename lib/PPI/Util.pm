package PPI::Util;

# Provides some common utility functions that can be imported

use strict;
use UNIVERSAL 'isa';
use base 'Exporter';
use PPI::Document ();

use vars qw{$VERSION @EXPORT_OK};
BEGIN {
	$VERSION = '0.991';
	@EXPORT_OK = qw{_Document};
}





#####################################################################
# Functions

# Allows a sub that takes a PPI::Document to handle the full range
# of different things, including file names, SCALAR source, etc.
sub _Document {
	shift if @_ > 1;
	return undef unless defined $_[0];
	return PPI::Document->new( shift ) unless ref $_[0];
	return PPI::Document->new( shift ) if ref $_[0] eq 'SCALAR';
	return shift if isa($_[0], 'PPI::Document');
	undef;
}

1;
