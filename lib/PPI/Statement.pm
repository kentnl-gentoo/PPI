package PPI::Statement;

# Implements statements, in all the colours of the rainbow!

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use PPI ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.821';
}





#####################################################################
# Constructor

sub new {
	my $class = ref $_[0] ? ref shift : shift;
	
	# Create the object
	my $self = bless { 
		elements => [],
		}, $class;

	# If we have been passed an initial token, add it
	if ( isa( ref $_[0], 'PPI::Token' ) ) {
		$self->add_element( shift ) or return undef;
	}

	$self;
}

# Some statement types do not always end with a ;
# Our term for these are 'implied end' statements.
# They require special logic to determine their end.
sub _implied_end { 0 }





#####################################################################
package PPI::Statement::Expression;

# A "normal" expression of some sort

BEGIN {
	$PPI::Statement::Expression::VERSION = '0.821';
	@PPI::Statement::Expression::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Scheduled;

# Code that is scheduled to run at a particular time/phase.
# BEGIN/INIT/LAST/END blocks

BEGIN {
	$PPI::Statement::Scheduled::VERSION = '0.821';
	@PPI::Statement::Scheduled::ISA     = 'PPI::Statement';
}

sub _implied_end { 1 }





#####################################################################
package PPI::Statement::Package;

# Package decleration

BEGIN {
	$PPI::Statement::Package::VERSION = '0.821';
	@PPI::Statement::Package::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Include;

# Commands that call in other files ( or 'uncall' them :/ )
# use, no and require.
### require should be a function, not a special statement?

BEGIN {
	$PPI::Statement::Include::VERSION = '0.821';
	@PPI::Statement::Include::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Sub;

# Subroutine or prototype declaration

BEGIN {
	$PPI::Statement::Sub::VERSION = '0.821';
	@PPI::Statement::Sub::ISA     = 'PPI::Statement';
}

sub _implied_end { 1 }

sub name {
	my $self = shift;

	# The second token should be the name, if we have one
	my $Token = $self->schild(1) or return undef;
	$Token->is_a('Bareword') ? $Token->content : undef;
}

# If we don't have a block at the end, this is a forward declaration
sub forward {
	my $self = shift;
	! $self->schild(-1)->isa('PPI::Structure::Block');
}





#####################################################################
package PPI::Statement::Variable;

# Explicit variable decleration ( my, our, local )

use UNIVERSAL 'isa';

BEGIN {
	$PPI::Statement::Variable::VERSION = '0.821';
	@PPI::Statement::Variable::ISA     = 'PPI::Statement';
}

# What type of variable declaration is it? ( my, local, our )
sub type {
	my $self = shift;

	# Get the children we care about
	my @schild = grep { $_->significant } $self->children;
	shift @schild if isa($schild[0], 'PPI::Token::Label');

	# Get the type
	(isa($schild[0], 'PPI::Token::Bareword') and $schild[0]->content =~ /^(my|local|our)$/)
		? $schild[0]->content
		: undef;
}

# What are the variables declared
sub variables {
	my $self = shift;

	# Get the children we care about
	my @schild = grep { $_->significant } $self->children;
	shift @schild if isa($schild[0], 'PPI::Token::Label');

	# If the second child is a symbol, return it's name
	if ( isa($schild[1], 'PPI::Token::Symbol') ) {
		return $schild[1]->canonical;
	}

	# If it's a list, return as a list
	if ( isa($schild[1], 'PPI::Statement::List') ) {
		my $symbols = $schild[1]->find('PPI::Token::Symbol') or return undef;
		return map { $_->canonical } @$symbols;
	}

	# erm... this is unexpected
	undef;
}





#####################################################################
package PPI::Statement::Compound;

# This should cover all flow control statements, if, while, etc, etc

BEGIN {
	$PPI::Statement::Compound::VERSION = '0.821';
	@PPI::Statement::Compound::ISA     = 'PPI::Statement';
}

sub _implied_end { 1 }

# The type indicates the structure category.
# It should be the first bareword in the statement.
sub type {
	my $self = shift;
	my $Token = $self->schild(0);
	if ( $Token->is_a('Bareword') ) {
		return $Token->content;
	} elsif ( $Token->isa_a('Label') ) {
		$Token = $self->schild(1);
		return $Token->is_a('Bareword') ? $Token->content : undef;
	} else {
		return undef;
	}
}





#####################################################################
package PPI::Statement::Break;

# Break out of a flow control block.
# next, last, return.

BEGIN {
	$PPI::Statement::Break::VERSION = '0.821';
	@PPI::Statement::Break::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Null;

# A null statement is a useless statement.
# Usually, just an extra ; on it's own.

BEGIN {
	$PPI::Statement::Null::VERSION = '0.821';
	@PPI::Statement::Null::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Unknown;

# We are unable to definitely catagorize the statement from the first
# token alone. Do additional checks when adding subsequent tokens.

# Currently, the only time this happens is when we start with a label

BEGIN {
	$PPI::Statement::Unknown::VERSION = '0.821';
	@PPI::Statement::Unknown::ISA     = 'PPI::Statement';
}

1;
