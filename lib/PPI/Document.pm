package PPI::Document;

=pod

=head1 NAME

PPI::Document - A single Perl document

=head1 INHERITANCE

  PPI::Base
  \--> PPI::Element
       \--> PPI::Node
            \--> PPI::Document

=head1 SYNOPSIS

  # Load a document from a file
  use PPI::Document;
  my $Document = PPI::Document->load('My/Module.pm');
  
  # Strip out comments
  $Document->prune( 'PPI::Token::Comment' );
  
  # Find all the named subroutines
  my @subs = $Document->find( 
  	sub { isa($_[1], 'PPI::Statement::Sub') and $_[1]->name }
  	);
  
  # Save the file
  $Document->save('My/Module.pm.stripped');

=head1 DESCRIPTION

The PPI::Document class represents a single Perl "document". A Document
object acts as a normal L<PPI::Node>, with some additional convenience
methods for loading and saving, and working with the line/column locations
of Elements within a file.

The exemption to it's ::Node behaviour this is that a PPI::Document object
can NEVER have a parent node, and is always the root node in a tree.

=head1 METHODS

Most of the things you are likely to want to do with a Document are probably
going to involve the methods of the L<PPI::Node|PPI::Node> class, of which
this is a subclass.

The methods listed here are the remaining few methods that are truly
Document-specific.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use File::Slurp    ();
use PPI            ();
use PPI::Statement ();
use PPI::Structure ();
use PPI::Document::Fragment ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.829';
}





#####################################################################
# Load a PPI::Document object from a file

=pod

=head2 load $file

The C<load> constructor loads a Perl document from a file, parses it, and
returns a new PPI::Document object. Returns C<undef> on error.

=cut

sub load {
	PPI::Lexer->lex_file( $_[1] );
}

=pod

=head2 save $file

The C<save> method serializes the PPI::Document object and saves the
resulting Perl document to a file. Returns C<undef> on error.

=cut

sub save {
	my $self = shift;

	# Serialize the Document
	my $content = $self->as_string or return undef;

	### FIXME - Check the return conditions for this
	File::Slurp::write_file( shift, $content );
}

=pod

index_locations

Within a document, all L<PPI::Element> objects can be considered to have a
"location", a line/column position within the document when considered as a
file. This position is primarily useful for debugging type activities.

The method for finding the position of a single Element is a bit laborious,
and very slow if you need to do it a lot. So the C<index_locations> method
will index and save the locations of every Element within the Document in
advance, making future calls to <PPI::Element::location> virtually free.

Please note that this is index should always be cleared using
C<flush_locations> once you are finished with the locations. If content is
added to or removed from the file, these indexed locations will be B<wrong>.

=cut

sub index_locations {
	my $self = shift;
	my ($line, $col) = (1, 1);

	# Get all the elements
	my @tokens = $self->tokens;
	foreach my $Token ( @tokens ) {
		$Token->{_line} = $line;
		$Token->{_col}  = $col;

		# Does the token contain any newlines
		my $content = $self->{content};
		my $newlines =()= $content =~ /\n/g;
		if ( $newlines ) {
			# Move down to the beginning of the new line(s)
			$line += $newlines;

			# Does the token have additional characters
			# after their last newline.
			if ( $content =~ /\n([^\n])$/ ) {
				# Move across to the column
				$col = length($1) + 1;
			} else {
				# We end up at the beginning of the line
				$col = 1;
			}

		} else {
			# Move across the page
			$col .= length $content;
		}
	}

	1;
}

=pod

When no longer needed, the C<flush_locations> method clears all location data
from the tokens.

=cut

sub flush_locations {
	my $self = shift;

	foreach ( $self->tokens ) {
		delete $_->{_line};
		delete $_->{_col};
	}

	1;
}

1;

=head1 TO DO

May need to overload some methods to forcefully prevent Document objects
becoming children of another Node.

=head1 SUPPORT

See the L<support section|PPI::Manual/SUPPORT> in the main PPI Manual

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Thank you to Phase N (L<http://phase-n.com/>) for permitting
the open sourcing and release of this distribution.

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
