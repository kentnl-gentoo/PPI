package PPI::Structure;

# An abstract parent and a set of classes representing structures

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use PPI          ();
use PPI::Element ();
use Scalar::Util ();

use vars qw{$VERSION *_PARENT};
BEGIN {
	$VERSION = '0.827';
	*_PARENT = *PPI::Element::_PARENT;
}





#####################################################################
# Constructor

sub new {
	my $class = shift;
	my $Token = (isa( ref $_[0], 'PPI::Token::Structure' ) && $_[0]->_opens)
		? shift : return undef;

	# Create the object
	my $self = bless {
		children => [],
		start    => $Token,
		}, $class;

	# Set the start braces parent link
	$_PARENT{Scalar::Util::refaddr($Token)} = $self;

	$self;
}

# Hacky method to let the Lexer set the finish token, so it doesn't
# have to import %PPI::Element::_PARENT itself.
sub _set_finish {
	my $self  = shift;

	# Check the Token
	my $Token = isa(ref $_[0], 'PPI::Token::Structure') ? shift : return undef;
	$Token->parent and return undef; # Must be a detached token
	($self->start->_opposite eq $Token->content) or return undef; # ... that matches the opening token

	# Set the token
	$self->{finish} = $Token;
	$_PARENT{Scalar::Util::refaddr($Token)} = $self;

	1;
}





#####################################################################
# PPI::Structure API methods

sub start  { $_[0]->{start}  }
sub finish { $_[0]->{finish} }

# What general brace type are we
sub braces {
	my $self = $_[0]->{start} ? shift : return undef;
	return { '[' => '[]', '(' => '()', '{' => '{}' }->{ $self->{start}->{content} };
}





#####################################################################
# PPI::Node overloaded methods

# For us, the "elements" concept includes the brace tokens
sub elements {
	my $self = shift;

	if ( wantarray ) {
		# Return a list in array context
		return ( $self->{start} || (), @{$self->{children}}, $self->{finish} || () );
	} else {
		# Return the number of elements in scalar context.
		# This is memory-cheaper than creating another big array
		return scalar(@{$self->{children}})
			+ ($self->{start} ? 1 : 0)
			+ ($self->{start} ? 1 : 0);
	}
}

# For us, the first element is probably the opening brace
sub first_element {
	# Technically, if we have no children and no opening brace,
	# then the first element is the closing brace.
	$_[0]->{start} or $_[0]->{children}->[0] or $_[0]->{finish};
}

# For us, the last element is probably the closing brace
sub last_element {
	# Technically, if we have no children and no closing brace,
	# then the last element is the opening brace
	$_[0]->{finish} or $_[0]->{children}->[-1] or $_[0]->{start};
}





#####################################################################
# PPI::Element overloaded methods

# Get the full set of tokens, including start and finish
sub tokens {
	my $self = shift;
	my @tokens = ( $self->{start} || (), $self->SUPER::tokens(@_), $self->{finish} || () );
	@tokens;
}

# Like the token method ->content, get our merged contents.
# This will recurse downwards through everything
sub content {
	my $self = shift;
	join '', map { $_->content }
	( $self->{start} || (), @{$self->{children}}, $self->{finish} || () );
}





#####################################################################
package PPI::Structure::Block;

# The general block curly braces

BEGIN {
	$PPI::Structure::Block::VERSION = '0.827';
	@PPI::Structure::Block::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Subscript;

BEGIN {
	$PPI::Structure::Subscript::VERSION = '0.827';
	@PPI::Structure::Subscript::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Constructor;

# The else block
BEGIN {
	$PPI::Structure::Constructor::VERSION = '0.827';
	@PPI::Structure::Constructor::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Condition;

# The round-braces condition structure from an if, elsif or unless
# if ( ) { ... }

BEGIN {
	$PPI::Structure::Condition::VERSION = '0.827';
	@PPI::Structure::Condition::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::List;

BEGIN {
	$PPI::Structure::List::VERSION = '0.827';
	@PPI::Structure::List::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::ForLoop;

BEGIN {
	$PPI::Structure::ForLoop::VERSION = '0.827';
	@PPI::Structure::ForLoop::ISA     = 'PPI::Structure';
}





#####################################################################
package PPI::Structure::Unknown;

# The Unknown class has been added to handle situations where we do
# not immediately know the class we are, and need to wait for more
# clues.

BEGIN {
	$PPI::Structure::Unknown::VERSION = '0.827';
	@PPI::Structure::Unknown::ISA     = 'PPI::Structure';
}

1;
