package PPI;

# PPI, short for Parse::Perl::Isolated, provides a set of APIs for working
# with reasonably correct perl code, without having to load, read or run
# anything outside of the code you wish to work with. i.e. "Isolated" code.

# The PPI class itself provides an overall top level module for working
# with the various subsystems ( tokenizer, lexer, analysis, formatting,
# and transformation ).

use 5.005;
use strict;
# use warnings;
# use diagnostics;
use UNIVERSAL 'isa';
use Class::Autouse;

# Set the version for CPAN
use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.825';

	# If we are in a mod_perl environment, always fully load
	# modules, in case Apache::Reload is present, and also to
	# let copy-on-write do it's work and save us gobs of memory.
	Class::Autouse->devel(1) if $ENV{MOD_PERL};
}

# Load the essentials
use base 'PPI::Base';
use PPI::Element ();
use PPI::Node ();





# Build a regex library containing just the bits we need,
# and precompile them all. Note that in all the places that
# have critical speed issues, the regexs have been inlined.
use vars qw{%RE};
BEGIN {
	%RE = (
		CLASS        => qr/[\w:]/,                       # Characters anywhere in a class name
		SYMBOL_FIRST => qr/[^\W\d]/,                     # The first character in a perl symbol
		xpnl         => qr/(?:\015{1,2}\012|\015|\012)/, # Cross-platform newline
		blank_line   => qr/^\s*$/,
		comment_line => qr/^\s*#/,
		pod_line     => qr/^=(\w+)/,
		end_line     => qr/^\s*__(END|DATA)__\s*$/,
		);
}





# Autoload the remainder of the classes
use Class::Autouse 'PPI::Tokenizer', 
                   'PPI::Lexer',
                   'PPI::Document';





#####################################################################
# Constructors

# Create a new object from scratch
sub new {
	my $class  = shift;
	my $source = (defined $_[0] and length $_[0]) ? shift : return undef;

	# Create the object
	bless {
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
	my $source = File::Slurp::read_file( $filename );
	return $class->_error( "Error loading file" ) unless $source;

	# Create the new object and set the source
	my $self = $class->new( $source );
	$self->{file} = $filename;

	$self;
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
	1;
}





#####################################################################
# Main interface methods

# Get's the input document
sub document {
	die "Method ->document disabled";

	my $self = shift;
	unless ( $self->{Document} ) {
		$self->_load_source or return undef;
	}

	$self->{Document};
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
	$Document->to_string;
}

# Get the Tokenizer object
sub tokenizer {
	my $self = shift;
	unless ( $self->{Tokenizer} ) {
		$self->{Tokenizer} = PPI::Tokenizer->new( $self->{source} ) or return undef;
	}
	$self->{Tokenizer};
}

# Generates the html output
sub html {
	my $self = shift;
	my $style = shift || 'plain';
	my $options = shift || {};

	# Get the tokenizer, and generate the HTML
	my $Tokenizer = $self->tokenizer or return undef;
	PPI::Format::HTML->serialize( $Tokenizer, $style, $options );
}

# Generate a complete html page
sub html_page {
	my $self = shift;
	my $style = shift || 'plain';

	# Get the html
	my $html = $self->html( $style, @_ ) or return undef;
	PPI::Format::HTML->wrap_page( $style, $html );
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
	File::Slurp::write_file( $saveas, $content ) or return undef;

	1;
}

1;

__END__

=pod

=head1 NAME

PPI - Parse and manipulate Perl code non-destructively, without using perl itself

=head1 DESCRIPTION

This is an in-development package for parsing, manipulating and saving
perl code, without using the perl interpreter, the B modules, or any other
hacks that use perl's inbuilt grammar.

Please note that is project it intended as a mechanism for working with
perl content, NOT to actually compile and run working perl applications.
Thus, it provides only an approximation of the detail and flexibility 
available to the real perl parser, if a quite close approximation.

It has been shown many times that it is impossible to FULLY "parse" Perl
code without also executing it. We do not intend to fully parse it, just
get enough details to analyse it, alter it, and save it back without losing
details like whitespace, comments and other stuff lost when using the B::
modules.

=head1 STATUS

=over 4

=item Tokenizer

The Tokenizer can be considered complete, but with some remaining bugs that
will be fixed over time. This should get gradually more accurate as special
cases are found and handled, and more cruft is added. :)

=item Lexer

The basic framework of the lexer has been completely replaced. The new lexer
should be sufficient, but the lex logic is far from complete, and so the
parse tree may look kind of odd, but works for very basic statements.

The classes and methods are roughly completed for the basic parse tree
manipulation, but more advanced filters and such are yet to be written.
Overall, the lexer is considered about three quarters complete.

=item Syntax Highlighting

The syntax highlighter is virtually unchanged, except that instead of
working from an ( old style ) PPI::Document object, it pulls directly from
a Tokenizer. This is temporary, and you should expect the entire PPI::Format
tree to be overhauled and largely replaced once the lexer is completed.

=item Other Functionality

Given their current state, I have removed the entire PPI::Transform and
PPI::Analysis trees from the upload. They are totally out of date, and will
be replaced as the Lexer gets closer.

One rewritten module, L<PPI::Analysis::Compare|PPI::Analysis::Compare>, is
largely done and is currently in CPAN on it's own, as it relies on additional
modules not needed by the core.

=item Documentation

I have started on the very beginning of the manual, which can be found at
L<PPI::Manual>. It's raw, incomplete, and subject to change.

=back

=head1 STRUCTURE

This section provides a quick overview of all the classes in PPI, and their
general layout and inheritance. We start with the main data classes, and then
move on to the functional classes

  PPI::Base
    PPI::Element
      PPI::Node
        PPI::Document
        PPI::Statement
          PPI::Statement::Package
          PPI::Statement::Scheduled
          PPI::Statement::Expression
          PPI::Statement::Include
          PPI::Statement::Sub
          PPI::Statement::Variable
          PPI::Statement::Compound
          PPI::Statement::Break
          PPI::Statement::Null
        PPI::Structure
          
      PPI::Token
      
    

=head1 TO DO

=over

=item Tokenizer

Minor bug fixes and improvements are expected to be done as needed over time.

=item Lexer

- Finish the non-if compound statement lexing.

- Add lex and statement support for labels.

- Add support for statements that start with a block.

Also, a rewritten filter/transform framework needs to be created on top of the basic lexer,
to provide for the ability to add higher lever logic and capabilities.

=item Other Stuff

PPI::Format needs to be created properly, based on lex output rather than
the raw token stream. PPI::Analysis packages will need to be rewritten...
but they are likely to be largely third party, later. However, a base
collection of search/find/filter/replace type methods probably need to be
written centrally.

Somewhere in there we also need a SAX filter to generate events based on
perl structures, so various more complex processing tools can be written.

Replacements or equivalents are needed for current methods that do POD
extraction... some form of auto-doc can probably be written on top of that.

=item Documentation

Both user manuals and API documentation needs to get written.

=back

=head1 SUPPORT

None. Don't use this for anything you don't want to have to rewrite.
As this is changing, you probably need to be in contact with the author
if you want to be using this.

=head1 AUTHOR

    Adam Kennedy (Maintainer)
    cpan@ali.as
    http//ali.as/

=head1 COPYRIGHT

Copyright (c) 2002-2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
