package PPI::Document;

# The file lexer element is the top level of parsing.

use strict;
use UNIVERSAL 'isa';
use PPI ();
use PPI::Statement ();
use PPI::Structure ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.811';
	@PPI::Document::ISA = 'PPI::ParentElement'
}





# Constructor
sub new { bless { elements => [] }, shift }





# The main lexing method.
# Takes as an argument a source of tokens.
sub lex {
	my $self = shift;

	# Get the tokenizer
	$self->{tokenizer} = isa( $_[0], 'PPI::Tokenizer' ) ? shift : return undef;

	# Start the processing loop
	my $token;
	while ( $token = $self->{tokenizer}->get_token ) {
		# Add insignificant tokens directly to us
		unless ( $token->significant ) {
			$self->add_element( $token );
			next;
		}

		# For anything other than a structural element
		unless ( $token->class eq 'PPI::Token::Structure' ) {
			# Create a new statement
			my $Statement = PPI::Statement->new( $token ) or return undef;

			# Pass the lex control to it
			$Statement->lex( $self->{tokenizer} ) or return undef;

			# Add the completed statement to our elements
			$self->add_element( $Statement );
			next;
		}

		# Is this the opening of a structure?
		if ( $token->_opens_structure ) {
			# Create the new block
			my $Structure = PPI::Structure->new( $token ) or return undef;

			# Pass the lex control to it
			$Structure->lex( $self->{tokenizer} ) or return undef;

			# Try to determine what type of structure it is
			$Structure->resolve( $self ) or return undef;

			# Add the resolved block to our elements
			$self->add_element( $Structure );
			next;
		}

		# Is this the close of a structure ( which would be an error )
		if ( $token->_closes_structure ) {
			# This means either a mis-parsing, or an
			# error in the code.
			return undef;
		}

		# It's a semi-colon on it's own
		# We call this a null statement
		my $Statement = PPI::Statement->new( $token ) or return undef;
		$self->add_element( $Statement );
	}

	# Is this an error?
	return undef unless defined $token;

	# No, it's the end of file
	$self->_clean( 1 );
}

1;
