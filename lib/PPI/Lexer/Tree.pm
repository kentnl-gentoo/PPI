package PPI::Lexer::Tree;

# The PPI::Lexer::Tree package provides a wrapping object over the tree like
# collection of Blocks. It allows you to handle entire trees of code at once.
# It is created by PPI::Lexer, and consumed by modules like PPI::Lexer::Tidy
# and PPI::Lexer::Obfuscate.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Lexer::Block';
use Carp qw{confess};

sub new {
	my $class = shift;
	
	my $self = {
		type => 'top',
		lexer => undef,
		elements => [],
		};
	return bless $self, $class;
}






#####################################################################
# Coping with our inheritage

# Overload methods from PPI::Lexer::Element
sub get_parent { $_[0] }
sub parent { $_[0] }

# Overload methods from PPI::Lexer::Block
sub get_type { 'top' }
sub get_open_token { PPI::Lexer::Token->empty_token }
sub get_close_token { PPI::Lexer::Token->empty_token }
sub detach { 1 }
sub set_lexer { $_[0]->{lexer} = $_[1] }
	
# Attach errors to methods that can't be used
sub set_parent { $_[0]->_lex_error( "Cannot set parent for PPI::Lexer::Tree" ) }
sub set_type { $_[0]->_lex_error( "Cannot set type for PPI::Lexer::Tree" ) }
sub set_open_token { $_[0]->_lex_error( "Cannot set open token for PPI::Lexer::Tree" ) }
sub set_close_token { $_[0]->_lex_error( "Cannot set close token for PPI::Lexer::Tree" ) }





#####################################################################
# Search and navigation around the tree






#####################################################################
# Generators

# Create a Document from the tree.
### ABOUT AS FAST TO DO AS I CAN MAKE IT
sub Document { PPI::Document->new( $_[0]->flatten ) }




#####################################################################
# Special error handler

sub _lex_error { $_[0]->{lexer}->_lex_error( $_[1] ) }

1;
