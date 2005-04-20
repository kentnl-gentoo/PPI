package PPI::Document;

=pod

=head1 NAME

PPI::Document - Object representation of a Perl document

=head1 INHERITANCE

  PPI::Document
  isa PPI::Node
      isa PPI::Element

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

The exemption to its ::Node-like behavior this is that a PPI::Document
object can NEVER have a parent node, and is always the root node in a tree.

=head1 METHODS

Most of the things you are likely to want to do with a Document are probably
going to involve the methods from L<PPI::Node> class, of which this is
a subclass.

The methods listed here are the remaining few methods that are truly
Document-specific.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use List::MoreUtils ();
use File::Slurp     ();
use PPI             ();
use PPI::Document::Fragment ();
use overload 'bool' => sub () { 1 };
use overload '""'   => 'content';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.904';
}





#####################################################################
# Load a PPI::Document object from a file

=pod

=head2 new $source

The C<new> constructor is slightly different for PPI::Document that for
the base L<PPI::Node>.

Although it behaves the same when called with no arguments, if you pass
it a defined string as the only argument, as a convenience the string
will be parsed, and the Document object returned will be for the source
code in the string.

Returns a PPI::Document object, or C<undef> if parsing fails.

=cut

sub new {
	my $class = ref $_[0] ? ref shift : shift;
	return $class->SUPER::new unless @_;

	# Check the source code
	my $source = shift;
	unless ( defined $source and length $source ) {
		return undef;
	}

	# Hand off to the lexer to build
	# and return the Document object.
	PPI::Lexer->lex_source( $source );
}

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

	### FIXME - Check the return conditions for this
	File::Slurp::write_file( shift,
		{ err_mode => 'quiet' },
		$self->serialize,
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
				$output .= $content;
			}

			$heredoc = '';
			next;
		}

		# This token is a HereDoc.
		# First, add the token content as normal, which in this
		# case will definately not contain a newline.
		$output .= $Token->content;

		# Now add all of the here-doc content to the heredoc buffer.
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

=pod

=head2 normalized

The C<normalized> method is used to generate a "Layer 1"
L<PPI::Document::Normalized> object for the current Document.

A "normalized" Perl Document is an arbitrary structure that removes any
irrelevant parts of the document and refactors out variations in style,
to attempt to approach something that is closer to the "true meaning"
of the Document.

See L<PPI::Normal> for more information on document normalization and
the tasks for which it is useful.

Returns a L<PPI::Document::Normalized> object, or C<undef> on error.

=cut

sub normalized {
	my $self = shift;

	# The normalization process will utterly destroy and mangle
	# anything passed to it, so we are going to only give it a
	# clone of ourself.
	my $Document = $self->clone or return undef;

	# Create the normalization object and execute it
	PPI::Normal->process( $Document );
}





#####################################################################
# PPI::Node Methods

# We are a scope boundary
### XS -> PPI/XS.xs:_PPI_Document__scope 0.903+
sub scope { 1 }

1;

=pod

=head1 TO DO

- Write proper unit and regression tests

- May need to overload some methods to forcefully prevent Document
objects becoming children of another Node.

- May be worth adding a PPI::Document::Normalized sub-class to formally
recognise the normalisation work going on in L<Perl::Compare> and the like.

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
