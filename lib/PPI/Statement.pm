package PPI::Statement;

# Implements a statement

use strict;
use UNIVERSAL 'isa';
use PPI ();

use vars qw{$VERSION %classes};
BEGIN {
	$VERSION = '0.811';
	@PPI::Statement::ISA = 'PPI::ParentElement';

	# Keyword -> Statement Subclass
	%classes = (
		# Things that affect the timing of execution
		'BEGIN'   => 'PPI::Statement::Scheduled',
		'INIT'    => 'PPI::Statement::Scheduled',
		'LAST'    => 'PPI::Statement::Scheduled',
		'END'     => 'PPI::Statement::Scheduled',

		# Loading and context statement
		'package' => 'PPI::Statement::Package',
		'use'     => 'PPI::Statement::Include',
		'no'      => 'PPI::Statement::Include',
		'require' => 'PPI::Statement::Include',

		# Various declerations
		'sub'     => 'PPI::Statement::Sub',
		'my'      => 'PPI::Statement::Variable',
		'local'   => 'PPI::Statement::Variable',
		'our'     => 'PPI::Statement::Variable',

		# Flow control
		'for'     => 'PPI::Statement::Loop',
		'foreach' => 'PPI::Statement::Loop',
		'while'   => 'PPI::Statement::Loop',
		'next'    => 'PPI::Statement::Break',
		'last'    => 'PPI::Statement::Break',
		'return'  => 'PPI::Statement::Break',
		'if'      => 'PPI::Statement::Condition',
		'unless'  => 'PPI::Statement::Condition',
		);
}





sub new {
	my $class = ref $_[0] ? ref shift : shift;
	
	# Create the object
	my $self = bless { 
		elements => [],
		}, $class;

	# If we have been passed an initial token, add it
	if ( isa( $_[0], 'PPI::Token' ) ) {
		$self->add_element( shift ) or return undef;
	}

	$self;
}

# Rebless as a subclass
# To be used by our children to rebless a structure
sub rebless { 
	ref $_[0] and return;
	isa( $_[1], 'PPI::Statement' ) or return;
	bless $_[1], $_[0];
}





#####################################################################
# Lexing

# Main lexing method
sub lex {
	my $self = shift;
	$self->{tokenizer} = isa( $_[0], 'PPI::Tokenizer' ) ? shift : return undef;

	# Begin processing tokens
	my $token;
	while ( $token = $self->{tokenizer}->get_token ) {
		my $class = $token->class;

		# Delay whitespace and comments
		unless ( $token->significant ) {
			$self->_delay_element( $token );
			next;
		}

		# Add normal things
		unless ( $class eq 'PPI::Token::Structure' ) {
			$self->add_element( $token );
			next;
		}

		# Does the token end this statement
		if ( $token->content eq ';' ) {
			$self->add_element( $token );
			return $self->_clean( 1 );
		}

		# Is it the opening of a structure
		if ( $token->_opens_structure ) {
			# Create a structure parser, and hand off to it
			my $Structure = PPI::Structure->new( $token ) or return undef;
			$Structure->lex( $self->{tokenizer} ) or return undef;
			$Structure->resolve( $self ) or return undef;
			$self->add_element( $Structure );
			next;
		}

		# Otherwise, it must be a structure close, which means
		# our statement ends by falling out of scope.

		# Rollback anything we won't be adding, so our parent can process them.
		$self->rollback_tokenizer( $token );
		return $self->_clean( 1 );
	}

	# Was it an error in the tokenizer?
	return undef unless defined $token;

	# End of file...
	$self->_clean( 1 );
}

# Add the resolution hook
sub add_element {
	my $self = shift;

	# If this is the first element,
	# try to resolve the statement type.
	unless ( @{$self->{elements}} ) {
		$self->resolve( $_[0] ) or return undef;
	}

	$self->SUPER::add_element( @_ );
}

# Attempt to resolve the statement using the first element
sub resolve {
	my $self = shift;
	my $element = isa( $_[0], 'PPI::Element' ) ? shift : return undef;

	# Is the statement defined by it's first keyword?
	if ( isa( $element, 'PPI::Token::Bareword' ) ) {
		my $class = $classes{$element->content};
		return $class->rebless( $self ) if $class;
	}

	# There may be more options we haven't though of yet
	$self;	
}





#####################################################################
package PPI::Statement::Scheduled;

# BEGIN/INIT/LAST/END blocks

BEGIN {
	@PPI::Statement::Scheduled::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Statement::Package;

# Package decleration

BEGIN {
	@PPI::Statement::Package::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Statement::Include;

# Commands that call in other files.
# use, no and require.
### require should be a function, not a special statement?

BEGIN {
	@PPI::Statement::Include::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Statement::Sub;

# Subroutine or prototype

BEGIN {
	@PPI::Statement::Sub::ISA = 'PPI::Statement';
}





#####################################################################
package PPI::Statement::Variable;

# Explicit variable decleration ( my, our, local )

BEGIN {
	@PPI::Statement::Variable::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Statement::Loop;

# Package decleration

BEGIN {
	@PPI::Statement::Loop::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Statement::Break;

# Package decleration

BEGIN {
	@PPI::Statement::Break::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Statement::Condition;

# Package decleration

BEGIN {
	@PPI::Statement::Condition::ISA = 'PPI::Statement';
}

sub DUMMY { 1 }

1;
