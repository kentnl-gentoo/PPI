package PPI::Transform::Object;

use strict;
use base 'PPI::Transform';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.841';
}

# PPI::Transform::Object provides a mechanism for building complex transforms
# and transform toolkits by allowing instantiated Transform to be assembled
# from an arbitrary set of functions.

sub new {
	my $class = ref $_[0] || shift;
	my %params = %{shift()} if ref $_[0];
	$params{shift} = shift while @_;

	# Remove params that can't be handlers
	delete $params{$_} foreach qw{new can isa VERSION}; # Block stupidity
	foreach ( keys %params ) {
		delete $params{$_} unless $class->can($_);
		return undef unless ref $params{$_} eq 'CODE';
	}

	# Create the object
	bless \%params, $class;
}





#####################################################################
# PPI::Transform Methods

1;
