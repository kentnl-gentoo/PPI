package PPI::Lexer::Token;

# This package provides a variant of the PPI::Tokenizer::Token which 
# is more usefull to the lexer. These are not created directly, but are
# converted from "PPI::Tokenizer::Token"s.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Tokenizer::Token',
         'PPI::Lexer::Element';

sub new { 
	my $class = shift;
	my $type = shift;
	my $content = shift;	
	
	# Check the class
	PPI::Tokenizer->resolveClass( $type ) or return undef;	
	
	# Create the object
	my $self = {
		class => $type,
		content => $content,
		};
	bless $self, $class;

	return $self;
}

# The create method will make a PPI::Lexer::Token from a 
# PPI::Tokenizer::Token
sub convert {
	my $class = shift;
	my $token = shift;	
	unless ( UNIVERSAL::isa( $token, 'PPI::Tokenizer::Token' ) ) {
		return $class->andError( "Argument is not a PPI::Tokenizer::Token" );
	}
	
	# Do the conversion
	return bless $token, $class;
}

# Check the type ( and content ) of a token
sub is_a {
	return 0 unless $_[1] eq $_[0]->{class};  # Check the class
	return 1 unless scalar @_ > 2;            # More detail needed?
	return $_[0]->{content} eq $_[2] ? 1 : 0; # Check the content
}

# Is the token an open bracket
sub openBracket {
	my $self = shift;
	return 0 unless $self->class eq 'Structure';
	return ($PPI::Lexer::openOrClose->{$self->content} eq 'open') ? 1 : 0;
}

# Is the token a close bracket
sub closeBracket {
	my $self = shift;
	return 0 unless $self->class eq 'Structure';
	return ($PPI::Lexer::openOrClose->{$self->content} eq 'close') ? 1 : 0;
}

# Create an empty token
sub emptyToken { $_[0]->new( 'Base', '' ) }

sub getSummaryStrings {
	my $self = shift;
	if ( $self->{class} eq 'Operator'
	  or $self->{class} eq 'Structure'
	  or $self->{class} eq 'Bareword' ) {
	  	return [ "$self->{class} $self->{content}", $self->{class} ];
	} else {
		return [ $self->{class} ];
	}
}

1;
