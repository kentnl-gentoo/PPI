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
sub getParent { $_[0] }
sub parent { $_[0] }

# Overload methods from PPI::Lexer::Block
sub getType { 'top' }
sub getOpenToken { PPI::Lexer::Token->emptyToken }
sub getCloseToken { PPI::Lexer::Token->emptyToken }
sub detach { 1 }
sub setLexer { $_[0]->{lexer} = $_[1] }
	
# Attach errors to methods that can't be used
sub setParent { $_[0]->lexError( "Cannot set parent for PPI::Lexer::Tree" ) }
sub setType { $_[0]->lexError( "Cannot set type for PPI::Lexer::Tree" ) }
sub setOpenToken { $_[0]->lexError( "Cannot set open token for PPI::Lexer::Tree" ) }
sub setCloseToken { $_[0]->lexError( "Cannot set close token for PPI::Lexer::Tree" ) }





#####################################################################
# Search and navigation around the tree






#####################################################################
# Generators

# Create a Document from the tree.
### ABOUT AS FAST TO DO AS I CAN MAKE IT
sub Document { PPI::Document->new( $_[0]->flatten ) }




#####################################################################
# Special error handler

sub lexError { $_[0]->{lexer}->lexError( $_[1] ) }

1;
