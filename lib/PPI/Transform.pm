package PPI::Transform;

# Provides an abstract base class for implementing routines that modify perl
# documents.

use strict;
use UNIVERSAL 'isa';
use File::Slurp ();
use PPI ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.826';
}





#####################################################################
# Optional methods to see if we need to transform

sub matches {
	my $either = shift;

	# We take either a file name, PPI::Document object, or reference to
	# a scalar containing source as our an argument.
	if ( isa(ref $_[0], 'PPI::Document') ) {
		return $either->matches_document(@_);
	} elsif ( ref $_[0] eq 'SCALAR' ) {
		return $either->matches_source(@_);
	} elsif ( defined $_[0] and ! ref $_[0] ) {
		return $either->matches_file(@_);
	}

	undef;
}

sub matches_file {
	my $either = shift;
	my $file   = (-f $_[0] and -r $_[0]) ? shift : return undef;
	
	# Load the document object and hand off to the next method
	my $Document = PPI::Lexer->lex_file( $file ) or return undef;
	$either->matches_document( $Document, @_ );
}

sub matches_source {
	my $either = shift;
	my $source = ref $_[0] eq 'SCALAR' ? shift : return undef;

	# Lex the source into a document and hand off to the next method
	my $Document = PPI::Lexer->lex_source( $source ) or return undef;
	$either->matches_document( $Document, @_ );
}

sub matches_document {
	my $either = shift;
	my $Document = isa(ref $_[0], 'PPI::Document') ? shift : return undef;

	# By default, we assume a match
	1;
}





#####################################################################
# Apply the transform

sub transform {
	my $either = shift;

	# We take either a file name, PPI::Document object, or reference to
	# a scalar containing source as our an argument.
	if ( isa(ref $_[0], 'PPI::Document') ) {
		return $either->matches_document(@_);
	} elsif ( ref $_[0] eq 'SCALAR' ) {
		return $either->matches_source(@_);
	} elsif ( defined $_[0] and ! ref $_[0] ) {
		return $either->matches_file(@_);
	}

	undef;
}

sub transform_file {
	my $either = shift;
	my $file   = (-f $_[0] and -r $_[0]) ? shift : return undef;

	# Load the document object
	my $Document = PPI::Lexer->lex_file( $file ) or return undef;

	# Apply the transform
	my $rv = $either->transform_document( $Document, @_ );
	return $rv unless $rv; # False or undef

	# Save the changes back to the source
	my $changed = $Document->content;
	return undef unless defined $changed;
	File::Slurp::write_file( $file, $changed ) or return undef;
	$rv;
}

sub transform_source {
	my $either = shift;
	my $source = ref $_[0] eq 'SCALAR' ? shift : return undef;

	# Lex the source into a document
	my $Document = PPI::Lexer->lex_source( $source ) or return undef;

	# Apply the transform
	my $rv = $either->transform_document( $Document, @_ );
	return $rv unless $rv; # False or undef

	# Save the changes back to the source
	my $changed = $Document->content;
	return undef unless defined $changed;
	$$source = $changed;
	$rv;
}

sub transform_document {
	my $either = shift;
	my $Document = isa(ref $_[0], 'PPI::Document') ? shift : return undef;

	# This should have been implemented by the subclass
	undef;
}

1;
