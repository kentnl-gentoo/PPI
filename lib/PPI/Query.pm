package PPI::Query;

=pod

=head1 NAME

PPI::Query - Base class for building queries against PDOM trees

=head1 DESCRIPTION

As work on the first generation of higher-level modules built on top of PPI
was getting started, it became quite obvious that many of these consisted of
large numbers of "queries" and "transformations". This class implements an
API for building these queries. See L<PPI::Transform> for the other half of
the story.

=head2 What is a Query

Because of the complex nature of Perl code and PDOM trees, testing them for
conditions can often be quite involved, even for relatively trivial cases.

A Query class or object is basically a chunk of code, with some metadata
attached that describes it's use. By wrapping the conditions up this way,
in theory they can be passed around and re-used much more readily.

This class really only serves as a very general base class. You are probably
going to be more interested in one of the task-specific subclasses.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.831';
}





#####################################################################
# Configuration Methods

=head2 class

If the C<class> method returns true, it indicates that the entire B<class>
is a Query, and not just instances of it, as is normally the case. This
would typically be used for very large and complex queries that could
require significant amounts of additional methods and functionality to
implement them.

If false, indicates that only an instance of this class can be used as a
Query.

=cut

sub class { '' } # By default, all queries must be instantiated

=pod

=head2 accepts

Some queries are only useful in certain circumstances. The C<accepts> method
is used to describe when this is. It should return a PPI PDOM class. The
Query will thus be expected to only be used in situations where an object of
that type is being tested.

By default, returns 'PPI::Element' indicating the Query can be used for any
type of PDOM object.

=cut

sub accepts { 'PPI::Element' }

=pod

=head2 usable

For a given PDOM element, C<usable> will do a quick check to make sure that
the class/object is usable. Basically just checks that the C<class> and
C<accepts> are ok.

Returns true if the Query can be used with the argument, or false otherwise.

=cut

sub usable {
	ref($_[0]) or $_[0]->class or return '';
	!! isa($_[1], $_[0]->accepts);
}





#####################################################################
# Constructor and Accessors

=pod

ALL Query classes are required to instantiate, for simplicity in the PPI
internals. In the cases where a Query is valid as a standalone class, the
C<new> method provides a default instantiation to an empty object.

By default, PPI::Query itself defines no format for the arguments provided
to a Query class, although a task-specific subclass may do so.

Returns a new PPI::Query object, or C<undef> on bad arguments.

=cut

sub new {
	bless {}, ref $_[0] || $_[0];
}

=pod

By default, the primary query for a given class/object is accessed via the
C<execute> method. The method is passed the PDOM element you wish to run
the Query against, and returns a value.

In the default case, PPI::Query does not define the returns value format,
although certain subclasses aimed at specific tasks may do so.

Returns C<undef> if an error occured during the execution of the Query.

=cut

sub execute { '' }

1;

=pod

=head1 TO DO

- Add some basic subclasses based around return condition

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main PPI Manual

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

Thank you to Phase N (L<http://phase-n.com/>) for permitting
the open sourcing and release of this distribution.

=head1 COPYRIGHT

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
