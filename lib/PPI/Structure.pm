package PPI::Structure;

# Implements a structure

use strict;
use UNIVERSAL 'isa';
use PPI ();

use vars qw{$VERSION %round_classes %curly_classes};
BEGIN {
	$VERSION = '0.811';
	@PPI::Structure::ISA = 'PPI::ParentElement';

	# Keyword -> Structure class maps
	%round_classes = (
		'if'     => 'PPI::Structure::Condition',
		'elsif'  => 'PPI::Structure::Condition',
		'unless' => 'PPI::Structure::Condition',
		);

	%curly_classes = (
		'sub'   => 'PPI::Structure::AnonymousSub',

		'BEGIN' => 'PPI::Structure::Block',
		'INIT'  => 'PPI::Structure::Block',
		'LAST'  => 'PPI::Structure::Block',
		'END'   => 'PPI::Structure::Block',

		# Condition related
		'else'    => 'PPI::Structure::Block::Else',
		);
}





sub new {
	my $class = shift;
	my $token = (isa( $_[0], 'PPI::Token' ) && $_[0]->_opens_structure)
		? shift : return undef;

	# Create the object
	bless {
		elements => [],
		start    => $token,
		}, $class;
}

# To be used by our children to rebless a structure
sub rebless { 
	ref $_[0] and return;
	isa( $_[1], 'PPI::Structure' ) or return;
	bless $_[1], $_[0];
}





#####################################################################
# Accessors

sub start  { $_[0]->{start} }
sub finish { $_[0]->{finish} }

# What general brace type are we
sub _brace_type {
	my $self = $_[0]->{start} ? shift : return undef;
	return { '[' => '[]', '(' => '()', '{' => '{}' }->{ $self->{start}->{content} };
}





#####################################################################
# Main functional methods

sub lex {
	my $self = shift;

	# Get the tokenizer
	$self->{tokenizer} = isa( $_[0], 'PPI::Tokenizer' )
		? shift : return undef;

	# Start the processing loop
	my $token;
	while ( $token = $self->{tokenizer}->get_token ) {
		# Is this a direct type token
		unless ( $token->significant ) {
			$self->add_element( $token );
			next;
		}

		# For anything other than a structural element
		unless ( $token->class eq 'PPI::Token::Structure' ) {
			# Create a new statement
			my $Statement = PPI::Statement->new( $token ) or return undef;

			# Pass the lex control to it
			$Statement->lex( $self->{tokenizer} ) or return undef;

			# Add the completed statement to our elements
			$self->add_element( $Statement );
			next;
		}

		# Is this the opening of a structure?
		if ( $token->_opens_structure ) {
			# Create the new block
			my $Structure = PPI::Structure->new( $token ) or return undef;

			# Pass the lex control to it
			$Structure->lex( $self->{tokenizer} ) or return undef;

			# Add the completed block to our elements
			$self->add_element( $Structure );
			next;
		}

		# Is this the close of a structure ( which would be an error )
		if ( $token->_closes_structure ) {
			# Is this OUR closing structure
			if ( $token->content eq $self->{start}->_matching_brace ) {
				# Add and close
				$self->{finish} = $token;
				return $self->_clean( 1 );
			}

			# Unexpected close... error
			return undef;
		}

		# It's a semi-colon on it's own
		# We call this a null statement
		my $Statement = PPI::Statement->new( $token ) or return undef;
		$self->add_element( $Statement );
	}

	# Is this an error
	return undef unless defined $token;

	# No, it's the end of file
	$self->_clean( 1 );
}





#####################################################################
# Starting with only our context, determine what subclass we are
# and try to rebless to it

sub resolve {
	my $self = shift;

	# Split based on type
	my $type = $self->_brace_type or return undef;
	return $self->_resolve_round( @_ )  if $type eq '()';
	return $self->_resolve_square( @_ ) if $type eq '[]';
	return $self->_resolve_curly( @_ )  if $type eq '{}';
	undef;
}

sub _resolve_round {
	my $self = shift;
	my $parent = isa( $_[0], 'PPI::ParentElement' ) ? shift : return undef;

	# Get the last significant element in the parent
	my $el = $parent->nth_significant_child( -1 );
	if ( isa( $el, 'PPI::Token::Bareword' ) ) {
		# Can it be determined because it is a keyword?
		my $class = $round_classes{$el->content};
		return $class->rebless( $self ) if $class;

		# If it's after a normal bareword, we assume that
		# the round specify an argument list.
		return PPI::Structure::List->rebless( $self );
	}

	# Otherwise, we know not what it is, and as the logic is far from
	# complete, we do not attempt a default rebless... yet.
	$self;
}

sub _resolve_square {
	my $self = shift;
	my $parent = isa( $_[0], 'PPI::ParentElement' ) ? shift : return undef;

	# Don't know. Don't care. Don't rebless
	$self;
}

sub _resolve_curly {
	my $self = shift;
	my $parent = isa( $_[0], 'PPI::ParentElement' ) ? shift : return undef;

	# Get the last significant element in the parent
	my $el = $parent->nth_significant_child( -1 );
	if ( isa( $el, 'PPI::Token::Bareword' ) ) {
		# Can it be determined because it is a keyword?
		my $class = $curly_classes{$el->content};
		return $class->rebless( $self ) if $class;

	}

	# More complicated upwards searching for subroutine context
	if ( isa( $el, 'PPI::Token::Attribute' ) or isa( $el, 'PPI::Token::SubPrototype' ) ) {
		my $i = -1;
		while( $el = $parent->nth_significant_child( --$i ) ) {
			next if isa( $el, 'PPI::Token::Attribute' );
			next if isa( $el, 'PPI::Token::SubPrototype' );
			if ( isa( $el, 'PPI::Token::Operator') and $el->content eq ':' ) {
				next;
			}
			last unless isa( $el, 'PPI::Token::Bareword' );
			last unless $el->content eq 'sub';
			return PPI::Structure::AnonymousSub->rebless($self);
		}
	}

	# Don't rebless
	$self;
}





#####################################################################
# Tools

# Like the token method ->content, get our merged contents.
# This will recurse downwards through everything
sub content {
	my $self = shift;
	join '', map { $_->content } grep { $_ }
		( $self->{start}, @{$self->{elements}}, $self->{finish} );
}





#####################################################################
package PPI::Structure::Condition;

# The round-braces condition structure from an if, elsif or unless
# if ( ) { ... }

BEGIN {
	@PPI::Structure::Condition::ISA = 'PPI::Structure';
}

sub DUMMY { 1 }





####################################################################
package PPI::Structure::List;

BEGIN {
	@PPI::Structure::List::ISA = 'PPI::Structure';
}	

sub DUMMY { 1 }





#####################################################################
package PPI::Structure::AnonymousSub;

# The round-braces condition structure from an if or elsif
BEGIN {
	@PPI::Structure::AnonymousSub::ISA = 'PPI::Structure';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Structure::Block;

# The general block curly braces
BEGIN {
	@PPI::Structure::Block::ISA = 'PPI::Structure';
}

sub DUMMY { 1 }





#####################################################################
package PPI::Structure::Block::Else;

# The else block
BEGIN {
	@PPI::Structure::Block::Else::ISA = 'PPI::Structure::Block';
}

sub DUMMY { 1 }

1;
