package PPI::Base;

# Provides common functionality, primarily common error handling.

use strict;

use vars qw{$VERSION @err_stack};
BEGIN {
	$VERSION   = '0.841';
	@err_stack = ();
}





#####################################################################
# Error handling

sub _error         { shift; push @err_stack, @_; undef }
sub err_stack      { @err_stack }
sub errstr         { join ": ", reverse @err_stack }
sub errstr_console { join "\n", reverse @err_stack }
sub errclear       { @err_stack = () }

1;
