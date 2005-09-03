package PPI::Cache;

=pod

=head1 NAME

PPI::Cache - Provides document caching for PPI

=head1 SYNOPSIS

  # Load the default cache
  use PPI::Cache ':default';
  
  # Manually create a cache
  my $Cache = PPI::Cache->new(
  	path     => '/var/cache/perl/class-PPI',
  	readonly => 1,
  	);

=head1 DESCRIPTION

C<PPI::Cache> provides the default caching functionality for L<PPI>.

It integrates automatically with L<PPI> itself. Once enabled, any attempt
to load a document from the filesystem will be cached via cache.

=head1 METHODS

=cut

use strict;
use Carp         ();
use File::Spec   ();
use File::Path   ();
use Storable     ();
use Digest::MD5  ();
use Params::Util '_INSTANCE',
                 '_SCALAR';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.100_01';
}





#####################################################################
# Constructor and Accessors

sub new {
	my $class  = shift;
	my %params = @_;

	# Path should exist and be usable
	my $path = $params{path}
		or Carp::croak("Cannot create PPI::Cache, no path provided");
	unless ( -d $path ) {
		Carp::croak("Cannot create PPI::Cache, path does not exist");
	}
	unless ( -r $path and -x $path ) {
		Carp::croak("Cannot create PPI::Cache, no read permissions for path");
	}
	if ( ! $params{readonly} and ! -w $path ) {
		Carp::croak("Cannot create PPI::Cache, no write permissions for path");
	}

	# Create the basic object
	my $self = bless {
		path     => $path,
		readonly => !! $params{readonly},
		}, $class;

	$self;
}

=pod

=head2 path

The C<path> accessor returns the path on the local filesystem that is the
root of the cache.

=cut

sub path { $_[0]->{path} }

=pod

=head2 readonly

The C<readonly> accessor returns true if documents should not be written
to the cache.

=cut

sub readonly { $_[0]->{readonly} }





#####################################################################
# PPI::Cache Methods

=pod

=head2 get_document $md5sum | \$source

The C<get_document> method checks to see if a Document is stored in the
cache and retrieves it if so.

=cut

sub get_document {
	my $self   = ref $_[0]
		? shift
		: Carp::croak('PPI::Cache::get_document called as static method');
	my $md5hex = $self->_md5hex(shift) or return undef;
	$self->_load($md5hex);
}

=pod

=head2 store_document $Document

The C<store_document> method takes a L<PPI::Document> as argument and
explicitly adds it to the cache.

Returns true if saved, or C<undef> (or dies) on error.

FIXME (make this return either one or the other, not both)

=cut

sub store_document {
	my $self     = shift;
	my $Document = _INSTANCE(shift, 'PPI::Document') or return undef;

	# Find the filename to save to
	my $content = $Document->serialize;
	my $md5hex  = Digest::MD5::md5_hex($content);

	# Store the file
	$self->_store( $md5hex, $Document );
}





#####################################################################
# Support Methods

# Store an arbitrary PPI::Document object (using Storable) to a particular
# path within the cache filesystem.
sub _store {
	my ($self, $md5hex, $object) = @_;
	my ($dir, $file) = $self->_paths($md5hex);

	# Save the file
	File::Path::mkpath( $dir, 0, 0755 ) unless -d $dir;
	Storable::lock_nstore( $object, $file );
}

# Load an arbitrary object (using Storable) from a particular
# path within the cache filesystem.
sub _load {
	my ($self, $md5hex) = @_;
	my (undef, $file) = $self->_paths($md5hex);

	# Load the file
	return '' unless -f $file;
	my $object = Storable::lock_retrieve( $file );

	# Security check
	unless ( _INSTANCE($object, 'PPI::Document') ) {
		Carp::croak("Security Violation: Object in '$file' is not a PPI::Document");
	}

	$object;
}

# Convert a md5 to a dir and file name
sub _paths {
	my $self   = shift;
	my $md5hex = lc shift;
	my $dir    = File::Spec->catdir( $self->path, substr($md5hex, 0, 1), substr($md5hex, 0, 2) );
	my $file   = File::Spec->catfile( $dir, $md5hex . '.ppi' );
	return ($dir, $file);
}

# Check a md5hex param
sub _md5hex {
	my $either = shift;
	my $it     = _SCALAR($_[0])
		? Digest::MD5::md5_hex(${$_[0]})
		: $_[0];
	return (defined $it and ! ref $it and $it =~ /^[a-f0-9]{32}$/si)
		? lc $it
		: undef;
}

1;

=pod

=head1 TO DO

- Finish the basic functionality

- Add support for use PPI::Cache auto-setting $PPI::Document::CACHE

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy, L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
