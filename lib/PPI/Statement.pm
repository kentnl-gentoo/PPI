package PPI::Statement;

# Implements statements, in all the colours of the rainbow!
# Actually, apart from the base class, this file only contains the classes
# that are uninteresting and trivial. More complex classes get moved out
# to their own files.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Node';
use PPI ();
use PPI::Statement::Sub      ();
use PPI::Statement::Variable ();
use PPI::Statement::Compound ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.823';
}

# Statements that are normal end at statement terminators.
# Some are not, and need the more rigorous _statement_continues
sub __LEXER__normal { 1 }





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

# If the statement is labelled, what is the label name
sub label {
	my $first = shift->schild(1);
	isa($first, 'PPI::Token::Label')
		? substr($first, 0, length($first) - 1)
		: '';
}





#####################################################################
package PPI::Statement::Expression;

# A "normal" expression of some sort

BEGIN {
	$PPI::Statement::Expression::VERSION = '0.823';
	@PPI::Statement::Expression::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Scheduled;

# Code that is scheduled to run at a particular time/phase.
# BEGIN/INIT/LAST/END blocks

BEGIN {
	$PPI::Statement::Scheduled::VERSION = '0.823';
	@PPI::Statement::Scheduled::ISA     = 'PPI::Statement';
}

sub __LEXER__normal { '' }





#####################################################################
package PPI::Statement::Package;

# Package decleration

BEGIN {
	$PPI::Statement::Package::VERSION = '0.823';
	@PPI::Statement::Package::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Include;

# Commands that call in other files ( or 'uncall' them :/ )
# use, no and require.
### require should be a function, not a special statement?

BEGIN {
	$PPI::Statement::Include::VERSION = '0.823';
	@PPI::Statement::Include::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Break;

# Break out of a flow control block.
# next, last, return.

BEGIN {
	$PPI::Statement::Break::VERSION = '0.823';
	@PPI::Statement::Break::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Null;

# A null statement is a useless statement.
# Usually, just an extra ; on it's own.

BEGIN {
	$PPI::Statement::Null::VERSION = '0.823';
	@PPI::Statement::Null::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Data;

# The section of a file containing data

BEGIN {
	$PPI::Statement::Data::VERSION = '0.823';
	@PPI::Statement::Data::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::End;

# The useless stuff (although maybe containing POD) at the end of a file

BEGIN {
	$PPI::Statement::End::VERSION = '0.823';
	@PPI::Statement::End::ISA     = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Unknown;

# We are unable to definitely catagorize the statement from the first
# token alone. Do additional checks when adding subsequent tokens.

# Currently, the only time this happens is when we start with a label

BEGIN {
	$PPI::Statement::Unknown::VERSION = '0.823';
	@PPI::Statement::Unknown::ISA     = 'PPI::Statement';
}

1;
