package PPI::Common;

# Provides common functionality

use strict;
use PPI ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = "0.6";
}


#####################################################################
# Error handling

use vars qw{@err_stack};
BEGIN { @err_stack = () }
sub _error { shift; push @err_stack, @_; undef }
sub err_stack { @err_stack }
sub errstr { join ": ", reverse @err_stack }
sub errstr_console { join "\n", reverse @err_stack }

1;
