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
	$VERSION = '0.828';

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
                   'PPI::Document',
                   'PPI::Transform';





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

=pod

=head1 NAME

PPI - Parse and manipulate Perl code non-destructively, without using perl itself

=head1 DESCRIPTION

This is PPI, originally short for Parse::Perl::Isolated, a package for parsing
and manipulating Perl documents.

For more information, see the L<PPI Manual|PPI::Manual>

=head1 SUPPORT

Although this is pre-beta, what code is there should actually work. So if you
find any bugs, they should be submitted via the CPAN bug tracker, located at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI>

For other issues, contact the author. In particular, if you want to make a
CPAN or private module that uses PPI, it would be best to stay in direct
contact with the author until PPI goes beta.

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
