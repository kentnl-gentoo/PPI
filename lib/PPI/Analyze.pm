package PPI::Analyze;

# The PPI::Analyze package provides functionality to read a
# PPI::Lexer::Tree object and determine things about the structure
# of the code.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';

sub new {
	my $class = shift;
	my $createFrom = shift;
	my $Tree = undef;
	
	# Get a lexer tree from the argument
	if ( isa( $createFrom, 'PPI::Lexer::Tree' ) ) {
		$Tree = $createFrom;
	} elsif ( isa( $createFrom, 'PPI::Lexer::Document' ) ) {
	}
		
	unless ( isa( $Tree, 'PPI::Lexer::Tree' ) ) {
		return $class->_error( "Constructor was not passed a PPI::Lexer::Tree argument" );
	}
	
	# Create the object
	my $self = {
		Packages => {},
		};
	bless $self, $class;
	
	return $self;
}

1;
