package PPI::Document;

=pod

=head1 NAME

PPI::Document - A single Perl document

=head1 INHERITANCE

  PPI::Base
  isa PPI::Element
      isa PPI::Node
          isa PPI::Document

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

The exemption to its ::Node behavior this is that a PPI::Document object
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
use List::MoreUtils ();
use File::Slurp     ();
use PPI             ();
use PPI::Statement  ();
use PPI::Structure  ();
use PPI::Document::Fragment ();
use overload 'bool' => sub () { 1 };
use overload '""'   => 'content';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840';
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
	my $content = $self->serialize;

	### FIXME - Check the return conditions for this
	File::Slurp::write_file( shift,
		{ err_mode => 'quiet' }, $content,
		) ? 1 : undef;
}

=pod

=head2 serialize

Unlike the C<content> method, which shows only the immediate content
within an element, Document objects also have to be able to be written
out to a file again.

When doing this we need to take into account some additional factors.

Primarily, we need to handle here-docs correctly, so that are written
to the file in the expected place.

The C<serialize> method generates the actual file content for a given
Document object. The resulting string can be written straight to a file.

Returns the serialized document as a string.

=cut

sub serialize {
	my $self   = shift;
	my @Tokens = $self->tokens;

	# The here-doc content buffer
	my $heredoc = '';

	# Start the main loop
	my $output = '';
	foreach my $i ( 0 .. $#Tokens ) {
		my $Token = $Tokens[$i];

		# Handle normal tokens
		unless ( $Token->isa('PPI::Token::HereDoc') ) {
			my $content = $Token->content;

			# Handle the trivial cases
			unless ( $heredoc ne '' and $content =~ /\n/ ) {
				$output .= $content;
				next;
			}

			# We have pending here-doc content that needs to be
			# inserted just after the first newline in the content.
			if ( $content eq "\n" ) {
				# Shortcut the most common case for speed
				$output .= $content . $heredoc;
			} else {
				# Slower and more general version
				$content =~ s/\n/\n$heredoc/;
			}

			$heredoc = '';
			next;
		}

		# This token is a HereDoc.
		# First, add the token content as normal, which in this
		# case will definately not contain a newline.
		$output .= $Token->content;

		# Now add all of the here-doc content to the heredoc
		# buffer.
		foreach my $line ( $Token->heredoc ) {
			$heredoc .= $line;
		}

		if ( $Token->{_damaged} ) {
			# Special Case:
			# There are a couple of warning/bug situations
			# that can occur when a HereDoc content was read in
			# from the end of a file that we silently allow.
			#
			# When writing back out to the file we have to
			# auto-repair these problems if we arn't going back
			# on to the end of the file.

			# This is a two part test.
			# First, are we on the last line of the
			# content part of the file
			my $last_line = List::MoreUtils::none {
				$Tokens[$_] and $Tokens[$_]->{content} =~ /\n/
				} (($i + 1) .. $#Tokens);

			# Secondly, are their any more here-docs after us
			my $any_after = List::MoreUtils::any {
				isa($Tokens[$_], 'PPI::Token::HereDoc')
				} (($i + 1) .. $#Tokens);

			# We don't need to repair the last here-doc on the
			# last line. But we do need to repair anything else.
			unless ( $last_line and ! $any_after ) {
				# Add a terminating string if it didn't have one
				unless ( defined $Token->{_terminator_line} ) {
					$Token->{_terminator_line} = $Token->{_terminator};
				}

				# Add a trailing newline to the terminating
				# string if it didn't have one.
				unless ( $Token->{_terminator_line} =~ /\n$/ ) {
					$Token->{_terminator_line} .= "\n";
				}
			}
		}

		# Now add the termination line to the heredoc buffer
		$heredoc .= $Token->{_terminator_line};
	}

	# End of tokens

	if ( $heredoc ne '' ) {
		# If the file doesn't end in a newline, we need to add one
		# so that the here-doc content starts on the next line.
		unless ( $output =~ /\n$/ ) {
			$output .= "\n";
		}

		# Now we add the remaining here-doc content
		# to the end of the file.
		$output .= $heredoc;
	}

	$output;
}

=pod

=head2 index_locations

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
	my $self    = shift;
	my @Tokens  = $self->tokens;

	# Whenever we hit a heredoc we will need to increment by
	# the number of lines in it's content section when when we
	# encounter the next token with a newline in it.
	my $heredoc = 0;

	# Find the first Token without a location
	my $i;
	my $location;
	foreach $i ( 0 .. $#Tokens ) {
		my $Token = $Tokens[$i];
		next if $Token->{_location};

		# Found the first Token without a location
		# Calculate the new location if needed.
		$location = $i
			? $self->_add_location( $location, $Tokens[$i-1], \$heredoc )
			: [ 1, 1 ];
	}

	# Calculate locations for the rest
	foreach $i ( $i .. $#Tokens ) {
		my $Token = $Tokens[$i];
		$Token->{_location} = $location;
		$location = $self->_add_location( $location, $Token, \$heredoc );

		# Add any here-doc lines to the counter
		if ( $Token->isa('PPI::Token::HereDoc') ) {
			$heredoc += $Token->heredoc + 1;
		}
	}

	1;
}

sub _add_location {
	my ($self, $start, $Token, $heredoc) = @_;
	my $content = $Token->{content};

	# Does the content contain any newlines
	my $newlines =()= $content =~ /\n/g;
	unless ( $newlines ) {
		# Handle the simple case
		return [ $start->[0], length($content) ];
	}

	# This is the more complex case where we hit or
	# span a newline boundary.
	my $location = [ $start->[0] + $newlines, 1 ];
	if ( $heredoc and $$heredoc ) {
		$location->[0] += $$heredoc;
		$$heredoc = 0;
	}

	# Does the token have additional characters
	# after their last newline.
	if ( $content =~ /\n([^\n])$/ ) {
		$location->[1] += length($1);
	}

	$location;
}

=pod

=head2 flush_locations

When no longer needed, the C<flush_locations> method clears all location data
from the tokens.

=cut

sub flush_locations {
	shift->_flush_locations(@_);
}

1;

=head1 TO DO

- Write proper unit and regression tests

- May need to overload some methods to forcefully prevent Document
objects becoming children of another Node.

- May be worth adding a PPI::Document::Normalized sub-class to formally
recognise the normalisation work going on in L<Perl::Compare> and the like.

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
