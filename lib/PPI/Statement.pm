package PPI::Statement;

# Implements statements, in all the colours of the rainbow!

use strict;
use UNIVERSAL 'isa';
use PPI ();

BEGIN {
	$PPI::Statement::VERSION = '0.814';
	@PPI::Statement::ISA     = 'PPI::ParentElement';
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
	$PPI::Statement::Expression::VERSION = '0.814';
	$PPI::Statement::Expression::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Scheduled;

# Code that is scheduled to run at a particular time/phase.
# BEGIN/INIT/LAST/END blocks

BEGIN {
	$PPI::Statement::Scheduled::VERSION = '0.814';
	@PPI::Statement::Scheduled::ISA     = 'PPI::Statement';
}

sub _implied_end { 1 }





#####################################################################
package PPI::Statement::Package;

# Package decleration

BEGIN {
	$PPI::Statement::Package::VERSION = '0.814';
	@PPI::Statement::Package::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Include;

# Commands that call in other files ( or 'uncall' them :/ )
# use, no and require.
### require should be a function, not a special statement?

BEGIN {
	$PPI::Statement::Include::VERSION = '0.814';
	@PPI::Statement::Include::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Sub;

# Subroutine or prototype declaration

BEGIN {
	$PPI::Statement::Sub::VERSION = '0.814';
	@PPI::Statement::Sub::ISA     = 'PPI::Statement';
}

sub _implied_end { 1 }

sub name {
	my $self = shift;

	# The second token should be the name, if we have one
	my $Token = $self->nth_significant_child(2) or return undef;
	$Token->is_a('Bareword') ? $Token->content : undef;
}

# If we don't have a block at the end, this is a forward declaration
sub forward {
	my $self = shift;
	! $self->nth_significant_child(-1)->isa('PPI::Structure::Block');
}





#####################################################################
package PPI::Statement::Variable;

# Explicit variable decleration ( my, our, local )

BEGIN {
	$PPI::Statement::Variable::VERSION = '0.814';
	@PPI::Statement::Variable::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Compound;

# This should cover all flow control statements, if, while, etc, etc

BEGIN {
	$PPI::Statement::Compound::VERSION = '0.814';
	@PPI::Statement::Compound::ISA     = 'PPI::Statement';
}

sub _implied_end { 1 }

# The type indicates the structure category.
# It should be the first bareword in the statement.
sub type {
	my $self = shift;
	my $Token = $self->nth_significant_child(1);
	if ( $Token->is_a('Bareword') ) {
		return $Token->content;
	} elsif ( $Token->isa_a('Label') ) {
		$Token = $self->nth_significant_child(2);
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
	$PPI::Statement::Break::VERSION = '0.814';
	@PPI::Statement::Break::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Null;

# A null statement is a useless statement.
# Usually, just an extra ; on it's own.

BEGIN {
	$PPI::Statement::Null::VERSION = '0.814';
	@PPI::Statement::Null::ISA     = 'PPI::Statement';
}

1;
