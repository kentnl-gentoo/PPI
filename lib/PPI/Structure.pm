package PPI::Structure;

# An abstract parent and a set of classes representing structures

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use PPI ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.817';
}





#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $token = (isa( ref $_[0], 'PPI::Token::Structure' ) && $_[0]->_opens)
		? shift : return undef;

	# Create the object
	bless {
		elements => [],
		start    => $token,
		}, $class;
}





#####################################################################
# Accessors

sub start  { $_[0]->{start}  }
sub finish { $_[0]->{finish} }

# What general brace type are we
sub braces {
	my $self = $_[0]->{start} ? shift : return undef;
	return { '[' => '[]', '(' => '()', '{' => '{}' }->{ $self->{start}->{content} };
}

# Get the full set of elements, including the start and finish
sub elements {
	my $self = shift;
	( $self->{start} || (), @{$self->{elements}}, $self->{finish} || () );
}

# Like the token method ->content, get our merged contents.
# This will recurse downwards through everything
sub content {
	my $self = shift;
	join '', map { $_->content }
	( $self->{start} || (), @{$self->{elements}}, $self->{finish} || () );
}





#####################################################################
package PPI::Structure::Block;

# The general block curly braces
BEGIN {
	$PPI::Structure::Block::VERSION = '0.817';
	@PPI::Structure::Block::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Subscript;

BEGIN {
	$PPI::Structure::Subscript::VERSION = '0.817';
	@PPI::Structure::Subscript::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Constructor;

# The else block
BEGIN {
	$PPI::Structure::Constructor::VERSION = '0.817';
	@PPI::Structure::Constructor::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Condition;

# The round-braces condition structure from an if, elsif or unless
# if ( ) { ... }

BEGIN {
	$PPI::Structure::Condition::VERSION = '0.817';
	@PPI::Structure::Condition::ISA     = 'PPI::Structure';
}





####################################################################
package PPI::Structure::List;

BEGIN {
	$PPI::Structure::List::VERSION = '0.817';
	@PPI::Structure::List::ISA     = 'PPI::Structure';
}	





#####################################################################
package PPI::Structure::Unknown;

# The Unknown class has been added to handle situations where we do
# not immediately know the class we are, and need to wait for more
# clues.

BEGIN {
	$PPI::Structure::Unknown::VERSION = '0.817';
	@PPI::Structure::Unknown::ISA     = 'PPI::Structure';
}	

1;
