package PPI::Statement;

# Implements statements, in all the colours of the rainbow!

use strict;
use UNIVERSAL 'isa';
use PPI ();

BEGIN {
	$PPI::Statement::VERSION = '0.813';
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





#####################################################################
package PPI::Statement::Expression;

# A "normal" expression of some sort

BEGIN {
	$PPI::Statement::Expression::VERSION = '0.813';
	$PPI::Statement::Expression::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Scheduled;

# Code that is scheduled to run at a particular time/phase.
# BEGIN/INIT/LAST/END blocks

BEGIN {
	$PPI::Statement::Scheduled::VERSION = '0.813';
	@PPI::Statement::Scheduled::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Package;

# Package decleration

BEGIN {
	$PPI::Statement::Package::VERSION = '0.813';
	@PPI::Statement::Package::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Include;

# Commands that call in other files ( or 'uncall' them :/ )
# use, no and require.
### require should be a function, not a special statement?

BEGIN {
	$PPI::Statement::Include::VERSION = '0.813';
	@PPI::Statement::Include::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Sub;

# Subroutine or prototype declaration

BEGIN {
	$PPI::Statement::Sub::VERSION = '0.813';
	@PPI::Statement::Sub::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Variable;

# Explicit variable decleration ( my, our, local )

BEGIN {
	$PPI::Statement::Variable::VERSION = '0.813';
	@PPI::Statement::Variable::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Flow;

# This should cover all flow control statements, if, while, etc, etc

BEGIN {
	$PPI::Statement::Flow::VERSION = '0.813';
	@PPI::Statement::Flow::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Break;

# Break out of a flow control block.
# next, last, return.

BEGIN {
	$PPI::Statement::Break::VERSION = '0.813';
	@PPI::Statement::Break::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Null;

# A null statement is a useless statement.
# Usually, just an extra ; on it's own.

BEGIN {
	$PPI::Statement::Null::VERSION = '0.813';
	@PPI::Statement::Null::ISA     = 'PPI::Statement';
}

1;
