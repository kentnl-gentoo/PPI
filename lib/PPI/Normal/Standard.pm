package PPI::Normal::Standard;

=pod

=head1 NAME

PPI::Normal::Standard - Provides standard document normalization functions

=head1 DESCRIPTION

This module provides the default normalization methods for L<PPI::Normal>.

There is no reason for you to need to load this yourself.

B<Move along, nothing to see here>.

=cut

use strict;
use UNIVERSAL 'isa';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.903';
}





#####################################################################
# Configuration and Registration

my %METHODS = (
	remove_insignificant_elements => 1,
	);

sub import {
	PPI::Normal->register(
		map { /\D/ ? "PPI::Normal::Standard::$_" : $_ } %METHODS
		) or die "Failed to register PPI::Normal::Standard transforms";
}





#####################################################################
# Level 1 Transforms

# Remove all insignificant things
sub remove_insignificant_elements {
	my $Document = shift;
	$Document->prune( sub { ! $_[1]->significant } );
}

1;

=pod

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
