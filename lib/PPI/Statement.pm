package PPI::Statement;

# Implements a statement

use strict;
use UNIVERSAL 'isa';
use PPI ();
BEGIN {
	@PPI::Statement::ISA = 'PPI::ParentElement';
}





sub new {
	my $class = shift;

	# Create the object
	my $self = bless {
		elements => [],
		}, $class;

	# If we have been passed an initial token, add it
	if ( isa( $_[0], 'PPI::Token' ) ) {
		$self->add_element( shift );
	}

	return $self;
}

# Classify the statement
use vars qw{%classes};
BEGIN {
	%classes = (
		# Things that affect the timing of execution
		'BEGIN'   => 'PPI::Statement::Scheduling',
		'INIT'    => 'PPI::Statement::Scheduling',
		'LAST'    => 'PPI::Statement::Scheduling',
		'END'     => 'PPI::Statement::Scheduling',

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
		);
}

sub class {
	my $self = shift;
	return $self->{class} if exists $self->{class};

	# Classification is done by examining the first
	# token in the statement
	my $first = $self->{elements}->[0] or return undef;

	# Is it a known bareword
	if ( $first->class eq 'PPI::Token::Bareword' ) {
		my $class = $classes{ $first->content };
		if ( $class ) {
			return $self->{class} = $class;
		}

		return $self->{class} = 'Statement';
	}


}



#####################################################################
# Tests

# Main lexing method
sub lex {
	my $self = shift;

	# Get the tokenizer
	$self->{tokenizer} = isa( $_[0], 'PPI::Tokenizer' )
		? shift : return undef;

	# Begin processing tokens
	my $token;
	while ( $token = $self->{tokenizer}->get_token() ) {
		my $class = $token->class;

		# Delay whitespace and comments
		if ( $class eq 'PPI::Token::Whitespace' ) {
			$self->_delay_element( $token );
			next;
		}
		if ( $class eq 'PPI::Token::Comment' ) {
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
	return $self->_clean( 1 );
}






#####################################################################
package PPI::Statement::Sub;

# Implements a class for a subroutine ( or prototype ) decleration statement.
use strict;
BEGIN {
	@PPI::Statement::Sub::ISA = 'PPI::Statement';
}

sub new {
	my $class = shift;
	my $element = isa( $_[0], 'PPI::Statement' )
		? shift : return undef;

	# Rebless the statement
	return bless $element, $class;
}

# What is the subroutine name
sub name {
	my $self = shift;

	### Find the first significant thing after the sub keyword
}

# Find something
sub _find_element_index {
	my $self = shift;
	my %options = @_;

	### What index do we start at
}

1;
