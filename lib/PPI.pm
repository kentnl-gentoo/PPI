package PPI;

# PPI ( Parse::Perl::Isolated ) implements a library for working with
# reasonably correct perl code, without having to load or run anything
# outside of the code you wish to work with. i.e. "Isolated" code.

# The PPI class itself provides an overall object for working with
# the various subsystems ( tokenizer, lexer, analysis, formatting,
# and transformation ).

require 5.005;
use strict;
# use warnings;
# use diagnostics;
use UNIVERSAL 'isa';
use Class::Autouse;

# Set the version for CPAN
use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.811';

	# If we are in a mod_perl environment, always fully load
	# modules, in case Apache::Reload is present.
	Class::Autouse->devel(1) if $ENV{MOD_PERL};
}

# Load the essentials
use base 'PPI::Common';
use PPI::Element ();





# Build a regex library containing just the bits we need,
# and precompile them all. Note that in all the places that
# have critical speed issues, the regexs have been inlined.
use vars qw{%RE};
BEGIN {
	%RE = (
		CLASS        => qr/[\w:]/o,                  # Characters anywhere in a class name
		SYMBOL_FIRST => qr/[a-zA-Z_]/o,              # The first character in a perl symbol
		xpnl         => qr/(?:\015\012|\015|\012)/o, # Cross-platform newline
		blank_line   => qr/^\s*$/o,
		comment_line => qr/^\s*#/o,
		pod_line     => qr/^=(\w+)/o,
		end_line     => qr/^\s*__(END|DATA)__\s*$/o,
		);
}





# Autoload the remainder of the classes
use Class::Autouse 'PPI::Tokenizer', 
	'PPI::Lexer', 'PPI::Document';





#####################################################################
# Constructors

# Create a new object from scratch
sub new {
	my $class = shift;
	my $source = length($_[0]) ? shift : return undef;

	# Create the object
	return bless {
		file      => undef,
		source    => $source,
		Tokenizer => undef,

		# The object works by collecting transform requests.
		# When a request to serialize ( ->html ->save etc ) is made
		# the source is tokenized and turned into a PPI::Document
		# and the transforms are applied to the Document.

		### Transforms are disabled...
		#transforms => [],
		#transforms_applied => 0,
		}, $class;
}

# Create a new object loading from a file
sub load {
	my $class = shift;

	my $filename = shift;

	# Try to slurp in the file
	my $source = File::Flat->slurp( $filename );
	return $class->_error( "Error loading file" ) unless $source;

	# Create the new object and set the source
	my $self = $class->new( $source );
	$self->{file} = $filename;

	return $self;
}

# Specify a transform to apply
sub add_transform {
	die "Method ->add_transform disabled";

	my $self = shift;
	my $transform = shift;
	unless ( $transform eq 'tidy' ) {
		return $self->_error( "Invalid transform '$transform'" );
	}

	# If effects have already been applied, remove them
	if ( $self->{transforms_applied} ) {
		$self->{Tree} = undef;
		$self->{transforms_applied} = 0;
	}

	push @{ $self->{transforms} }, $transform;
	return 1;
}





#####################################################################
# Main interface methods

# Get's the input document
sub document {
	die "Method ->document disabled";

	my $self = shift;
	unless ( $self->{Document} ) {
		$self->_load_source() or return undef;
	}
	return $self->{Document};
}

# Get's the output document
sub output {
	die "Method ->output disabled";

	my $self = shift;
	if ( scalar @{ $self->{transforms} } ) {
		unless ( $self->{transforms_applied} ) {
			$self->_apply_transforms() or return undef;
		}
		return $self->{Tree}->Document;
	} else {
		return $self->document;
	}
}

# Generate the code
sub to_string {
	my $self = shift;
	my $Document = $self->output or return undef;
	return $Document->to_string;
}

# Get the Tokenizer object
sub tokenizer {
	my $self = shift;
	unless ( $self->{Tokenizer} ) {
		$self->{Tokenizer} = PPI::Tokenizer->new( $self->{source} ) or return undef;
	}
	return $self->{Tokenizer};
}

# Generates the html output
sub html {
	my $self = shift;
	my $style = shift || 'plain';
	my $options = shift || {};

	# Get the tokenizer, and generate the HTML
	my $Tokenizer = $self->tokenizer or return undef;
	return PPI::Format::HTML->serialize( $Tokenizer, $style, $options );
}

# Generate a complete html page
sub html_page {
	my $self = shift;
	my $style = shift || 'plain';

	# Get the html
	my $html = $self->html( $style, @_ ) or return undef;
	return PPI::Format::HTML->wrap_page( $style, $html );
}

# Generic save function.
# Arguments are the filename and method to get the output from.
# Any additional arguments are passed through to the content generating
# method call.
# Example: $PSP->save( 'filename.html', 'html_page', 'syntax' );
sub save {
	my $self = shift;
	my $saveas = shift;
	my $from = shift;

	# Get the generated content
	my $content = $self->$from( @_ );
	return undef unless defined $content;

	# Save the content
	File::Flat->write( $saveas, $content ) or return undef;
	return 1;
}






#####################################################################
# Main functional methods

#sub _load_source {
#	my $self = shift;

	# Create the tokenizer
#	my $Tokenizer = PPI::Tokenizer->new( source => $self->{source} );
#	return $self->_error( "Error creating tokenizer" ) unless $Tokenizer;

	# Create the Document object using the Tokenizer
#	my $Document = PPI::Document->new( $Tokenizer );
#	return $self->_error( "Error turning Tokenizer into Lexer document" ) unless $Document;

	# Set the document
#	$self->{Document} = $Document;
#	return 1;
#}

#sub _load_tree {
#	my $self = shift;

	# Get the raw document
#	my $Document = $self->document or return undef;

	# Lex the document into a tree
#	my $Lexer = PPI::Lexer->new( $Document ) or return undef;
#	my $Tree = $Lexer->get_tree or return undef;

#	$self->{Tree} = $Tree;
#	return 1;
#}

#sub _apply_transforms {
#	my $self = shift;

	# Get the tree
#	my $Tree = $self->tree or return undef;

	# Iterate through the transforms and apply them
#	foreach my $transform ( @{ $self->{transforms} } ) {
#		if ( $transform eq 'tidy' ) {
#			PPI::Transform::Tidy->tidyTree( $Tree ) or return undef;
#		}
#	}

	# Done
#	return 1;
#}

1;

__END__

=pod

=head1 NAME

PPI ( Parse::Perl::Isolated ) - Parse and manipulate Perl code

=head1 DESCRIPTION

This is a checkpoint upload for the current state of PPI at the end of
April 2003.

=head1 STATUS

=over 4

=item Tokenizer

The tokenizer now has something close to it's final API completed. You
should however expect changes. It now runs about 25% faster, some
innacuracies have been fixed, and the memory overhead for tokenized code
has been significantly reduced. The Tokenizer can be considered complete,
but with some minor bugs.

=item Lexer

The basic framework of the lexer has been completely replaced. The new lexer
should be sufficient, but the lex logic is far from complete, and so the
parse tree may look kind of odd, but works for basic statements.

The classes and methods are roughly completed for the basic parse tree
manipulation, but more advanced filters and such are yet to be written.
Overall, the lexer is considered about half complete.

=item Syntax Highlighting

The syntax highlighter is virtually unchanged, except that instead of
working from an ( old style ) PPI::Document object, it pulls directly from
a Tokenizer. This is temporary, and you should expect the entire PPI::Format
tree to be overhauled and largely replaced once the lexer is completed.

=item Other Functionality

Given their current state, I have removed the entire PPI::Transform and
PPI::Analysis trees from the upload. They are totally out of date, and will
be replaced as the

=item Documentation

I have started on the very beginning of the manual, which can be found at
L<PPI::Manual>. It's raw, incomplete, and subject to change.

=back

=head1 TO DO

=over

=item Tokenizer

Further optomization work need to be done, and fix any bugs as they come to
light. Also, further fragments of token manipulation code need to be added
to the PPI::Token tree.

=item Lexer

PPI::Statement::* and PPI::Structure::* classes need to be written, and the
logic to tell what type of statement or structure something is. The lexer
itself than needs to use this analysis to build the tree correctly.

A filter/transform framework needs to be created on top of the basic lexer,
to provide for the ability to add higher lever logic and capabilities.

=item Other Stuff

PPI::Format needs to be created properly. PPI::Analysis packages will need
to be written... but they are likely to be largely third party, later.

Replacements or equivalents are needed for current methods that do POD
extraction... some form of auto-doc needs to be written.

=item Documentation

Both used manuals and API documentation needs to get written.

=back

=head1 SUPPORT

None. Don't use this for anything you don't want to have to rewrite.
To help contribute, contact the author.

=head1 AUTHOR

    Adam Kennedy
    cpan@ali.as
    http//ali.as/

=head1 COPYRIGHT

Copyright (c) 2002-2003 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
