package PPI;

# The PPI object is the top level object for working with Perl source
# code. It essentially provides macros and shortcut functions.

use strict;
# use warnings;
# use diagnostics;

use vars qw{$VERSION};
BEGIN {
	$VERSION = 0.2;
}

use UNIVERSAL 'isa';
use base 'PPI::Common';
use Class::Autouse qw{:devel
	File::Flat
	};

# Autoload everything below us
Class::Autouse->autouse_recursive( 'PPI' );






#####################################################################
# Constructors

# Create a new object from scratch
sub new {
	my $class = shift;
	my $source = shift;
	
	# Create the object
	my $self = {
		file => undef,
		source => $source,
		Document => undef,
		Tree => undef,
		
		# The object works by collecting transform requests.
		# When a request to serialize ( ->html ->save etc ) is made
		# the source is tokenized and turned into a PPI::Document
		# and the transforms are applied to the Document.
		transforms => [],
		transforms_applied => 0,				
		};
	bless $self, $class;
	
	return $self;
}

# Create a new object loading from a file
sub load {
	my $class = shift;
	my $filename = shift;
	
	# Try to slurp in the file
	my $source = File::Flat->slurp( $filename );
	return $class->andError( "Error loading file" ) unless $source;
	
	# Create the new object and set the source
	my $self = $class->new( $source );
	$self->{file} = $filename;
	
	return $self;
}

# Specify a transform to apply
sub addTransform {
	my $self = shift;
	my $transform = shift;
	unless ( $transform eq 'tidy' ) {
		return $self->andError( "Invalid transform '$transform'" );
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
	my $self = shift;
	unless ( $self->{Document} ) {
		$self->_loadSource() or return undef;
	}
	return $self->{Document};
}

# Get's the input tree
sub tree { 
	my $self = shift;
	if ( $self->{Tree} ) {
		if ( $self->{transforms_applied} ) {
			$self->{Tree} = undef;
			$self->_loadTree() or return undef;
		}
	} else {
		$self->_loadTree() or return undef;
	}
	return $self->{Tree};
}

# Get's the output document
sub output {
	my $self = shift;
	if ( scalar @{ $self->{transforms} } ) {
		unless ( $self->{transforms_applied} ) {
			$self->_applyTransforms() or return undef;
		}
		return $self->{Tree}->Document;
	} else {
		return $self->document;
	}
}

# Generate the code
sub toString {
	my $self = shift;
	my $Document = $self->output or return undef;
	return $Document->toString;
}

# Generates the html output
sub html {
	my $self = shift;
	my $style = shift || 'plain';
	my $options = shift || {};
	
	# Get the document and pass through the html formatter
	my $Document = $self->output or return undef;
	return PPI::Format::HTML->serializeDocument( $Document, $style, $options );
}

# Generate a complete html page
sub htmlPage {
	my $self = shift;
	my $style = shift || 'plain';
	
	# Get the html
	my $html = $self->html( $style, @_ ) or return undef;
	return PPI::Format::HTML->wrapPage( $style, $html );
}

# Generic save function.
# Arguments are the filename and method to get the output from.
# Any additional arguments are passed through to the content generating
# method call.
# Example: $PSP->save( 'filename.html', 'htmlPage', 'syntax' );
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

sub _loadSource {
	my $self = shift;
	
	# Create the tokenizer
	my $Tokenizer = PPI::Tokenizer->new( source => $self->{source} );
	return $self->andError( "Error creating tokenizer" ) unless $Tokenizer;
	
	# Create the Document object using the Tokenizer
	my $Document = PPI::Document->new( $Tokenizer );
	return $self->andError( "Error turning Tokenizer into Lexer document" ) unless $Document;
	
	# Set the document
	$self->{Document} = $Document;
	return 1;
}

sub _loadTree {
	my $self = shift;
	
	# Get the raw document
	my $Document = $self->document or return undef;
	
	# Lex the document into a tree
	my $Lexer = PPI::Lexer->new( $Document ) or return undef;
	my $Tree = $Lexer->getTree or return undef;
	
	$self->{Tree} = $Tree;
	return 1;
}

sub _applyTransforms {
	my $self = shift;
	
	# Get the tree
	my $Tree = $self->tree or return undef;
	
	# Iterate through the transforms and apply them
	foreach my $transform ( @{ $self->{transforms} } ) {
		if ( $transform eq 'tidy' ) {
			PPI::Transform::Tidy->tidyTree( $Tree ) or return undef;
		}
	}
	
	# Done
	return 1;
}

1;

__END__

=pod

=head1 NAME

PPI ( Parse::Perl::Isolated ) - Parsing an manipulating Perl code

=head1 DESCRIPTION

Most of this is really broken, and put in CPAN for the benefit of the interested.

The API is going to compltely change, the Lexer replaced. After that, we get docs.

For now, look at the syntax highlighter in the samples directory.

=head1 TODO

Shitloads

=head1 SUPPRT

None

=head1 AUTHOR

    Adam Kennedy
    cpan@ali.as
    http//ali.as/

=head1 COPYRIGHT

opyright (c) 2002 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

