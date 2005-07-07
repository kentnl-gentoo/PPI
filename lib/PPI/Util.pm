package PPI::Util;

# Provides some common utility functions that can be imported

use strict;
use base 'Exporter';
use PPI::Document ();
use Params::Util '_INSTANCE',
                 '_SCALAR';

use vars qw{$VERSION @EXPORT_OK};
BEGIN {
	$VERSION   = '0.996';
	@EXPORT_OK = '_Document';
}





#####################################################################
# Functions

# Allows a sub that takes a L<PPI::Document> to handle the full range
# of different things, including file names, SCALAR source, etc.
sub _Document {
	shift if @_ > 1;
	return undef unless defined $_[0];
	return PPI::Document->new( shift ) unless ref $_[0];
	return PPI::Document->new( shift ) if _SCALAR($_[0]);
	return shift if _INSTANCE($_[0], 'PPI::Document');
	undef;
}

1;
