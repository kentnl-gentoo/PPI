package PPI::Document::Fragment;

# A document fragment is a part of a document. While it behaves in a similar
# way to a normal document, it does not have it's own scope, and thus can be
# inserted into another document directly, without the use of lexical scoping
# otherwise needed to maintain lexical integrity.

use strict;
use base 'PPI::Document';
use UNIVERSAL 'isa';

# Identical, except for not having it's own scope
# sub scope { '' }

# There's no point indexing a fragment
sub index_locations {
	warn "Useless attempt to index the locations of a document fragment";
	undef;
}
	
1;
