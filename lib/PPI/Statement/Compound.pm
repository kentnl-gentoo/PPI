package PPI::Statement::Compound;

# This should cover all flow control statements, if, while, etc, etc

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.825';
}

# Lexer clue
sub __LEXER__normal { '' }

# Keyword type map
use vars qw{%TYPES};
BEGIN {
	%TYPES = (
		'if'      => 'if',
		'unless'  => 'if',
		'while'   => 'while',
		'for'     => 'for',
		'foreach' => 'foreach',
		);
}





#####################################################################
# PPI::Statement::Compound analysis methods

# The type indicates the structure category.
# It should be the first bareword in the statement.
sub type {
	my $self = shift;
	my $Element = $self->schild(0);

	# Most simple cases
	if ( isa($Element, 'PPI::Token::Bareword') ) {
		return $TYPES{$Element->content};
	}

	# A labelled statement
	if ( isa($Element, 'PPI::Token::Label') ) {
		$Element = $self->schild(1) or return 'label';
		return 'block' if isa($Element, 'PPI::Structure::Block');
		if ( isa($Element, 'PPI::Token::Bareword') ) {
			return $TYPES{$Element->content};
		}
	}

	# Unknown (shouldn't exist?)
	undef;
}

1;
