package PPI::Document;

=pod

=head1 NAME

PPI::Document - Object representation of a Perl document

=head1 INHERITANCE

  PPI::Document
  isa PPI::Node
      isa PPI::Element

=head1 SYNOPSIS

  use PPI;
  
  # Load a document from a file
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

The C<PPI::Document> class represents a single Perl "document". A
C<PPI::Document> object acts as a root L<PPI::Node>, with some
additional methods for loading and saving, and working with
the line/column locations of Elements within a file.

The exemption to its L<PPI::Node>-like behavior this is that a
C<PPI::Document> object can NEVER have a parent node, and is always
the root node in a tree.

=head1 METHODS

Most of the things you are likely to want to do with a Document are
probably going to involve the methods from L<PPI::Node> class, of which
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
use PPI::Document::Fragment ();
use overload 'bool' => sub () { 1 };
use overload '""'   => 'content';

use vars qw{$VERSION $errstr};
BEGIN {
	$VERSION = '0.993';
	$errstr  = '';
}





#####################################################################
# Load a PPI::Document object from a file

=pod

=head2 new $file, \$source

The C<new> constructor takes as argument a variety of different sources of
Perl code, and attempt to create a single cohesive Perl C<PPI::Document>
for it.

If passed a file name as a normal string, it will attempt to load the
document from the file.

If passed a reference to a SCALAR, this is taken to be source code and
parsed directly to create the document.

If passed zero arguments, a "blank" document will be created that contains
no content at all.

Returns a C<PPI::Document> object, or C<undef> if parsing fails.

=cut

sub new {
	my $class = ref $_[0] ? ref shift : shift;
	
	unless ( @_ ) {
		my $self = $class->SUPER::new;
		$self->{tab_width} = 1;
		return $self;
	}

	# Check the source code
	my $Document;
	if ( ! defined $_[0] ) {
		$class->_error("An undefined value was passed to PPI::Document::new");

	} elsif ( ! ref $_[0] ) {
		# Catch people using the old API
		if ( $_[0] =~ /(?:\012|\015)/ ) {
			die "API CHANGE: Source code should only be passed to PPI::Document->new as a SCALAR reference";
		}
		$Document = PPI::Lexer->lex_file( shift );

	} elsif ( ref $_[0] eq 'SCALAR' ) {
		$Document = PPI::Lexer->lex_source( ${$_[0]} );

	} else {
		$class->_error("An unknown object or reference was passed to PPI::Document::new");
	}

	# Did the parsing go smoothly?
	return $Document if $Document;

	# Pull and store the error from the lexer
	my $errstr = PPI::Lexer->errstr
		|| "Unknown error returned by PPI::Lexer";
	PPI::Lexer->_clear;
	$class->_error( $errstr );
}

sub load {
	die "API CHANGE: File names should now be passed to PPI::Document->new to load a file";
}

=pod

=head2 save $file

The C<save> method serializes the C<PPI::Document> object and saves the
resulting Perl document to a file. Returns C<undef> on error.

=cut

sub save {
	my $self = shift;
	File::Slurp::write_file( shift, $self->serialize );
}

=pod

=head2 tab_width [ $width ]

In order to handle support for C<location> correctly, C<Documents>
need to understand the concept of tabs and tab width. The C<tab_width>
method is used to get and set the size of the tab width.

At the present time, PPI only support "naive" (width 1) tabs, but we do
plan on supporting artibtrary, default and auto-sensing tab widths.

Returns the tab width as an integer, or C<die>s if you attempt to set the
tab width.

=cut

sub tab_width {
	my $self = shift;
	return $self->{tab_width} unless @_;
	die "PPI FEATURE INCOMPLETE(Only naive tabs (width 1) are supported at this time)";
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
	my ($first, $location) = ();
	foreach ( 0 .. $#Tokens ) {
		my $Token = $Tokens[$_];
		next if $Token->{_location};

		# Found the first Token without a location
		# Calculate the new location if needed.
		$location = $first
			? $self->_add_location( $location, $Tokens[$_ - 1], \$heredoc )
			: [ 1, 1 ];
		$first = $_;
		last;
	}

	# Calculate locations for the rest
	foreach ( $first .. $#Tokens ) {
		my $Token = $Tokens[$_];
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
		return [ $start->[0], $start->[1] + length($content) ];
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






#####################################################################
# Error Handling

# Set the error message
sub _error {
	$errstr = $_[1];
	undef;
}

# Clear the error message.
# Returns the object as a convenience.
sub _clear {
	$errstr = '';
	$_[0];
}

=pod

=head2 errstr

For error that occur when loading and saving documents, you can use
C<errstr>, as either a static or object method, to access the error message.

If a Document loads or saves without error, C<errstr> will return false.

=cut

sub errstr {
	$errstr;
}

1;

=pod

=head1 TO DO

- May need to overload some methods to forcefully prevent Document
objects becoming children of another Node.

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy, L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
