package PPI::Document::Normalized;

=pod

=head1 NAME

PPI::Document::Normalized - Create normalised PPI Documents

=head1 SYNOPSIS

  ...

=head1 DESCRIPTION

...

=head1 METHODS

=cut

use strict;
use base 'PPI::Document';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.844';
}

# A normalized document is a PPI document after normalisation. It's
# used as a convenience, to allow a function that plans on repeatedly
# comparing the same document on one side to pre-normalise and cache the
# results, to reduce processing time.

# The constructor takes a PPI::Document object, and returns an
# identical ::_NormalizedDocument object.
# This constructor IS destructive. If you don't want this, clone the
# document first.
sub new {
	my $Document = UNIVERSAL::isa(ref $_[1], 'PPI::Document') ? $_[1] : return undef;
	bless $Document, 'PPI::Document::Normalized';
}

1;
