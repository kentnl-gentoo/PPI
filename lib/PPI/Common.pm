package PPI::Common;

# Provides common functionality 

use strict;
use PPI;

#####################################################################
# Error handling

use vars qw{@errStack};
BEGIN { @errStack = () }
sub andError { shift; push @errStack, @_; undef }
sub errStack { @errStack }
sub errstr { join ": ", reverse @errStack }
sub errstrConsole { join "\n", reverse @errStack }

1;
