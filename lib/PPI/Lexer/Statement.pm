package PPI::Lexer::Statement;

# A PPI::Lexer::Statement is a single Perl statement.
# A single statement can be either an assignlement style a = b,
# or a flow control statement, such as if () {} else {}.
# It can also be sub declaration statements etc.
#
# Statements are classified by the first word in them.
# For example, there are "use", "package", "sub" etc statements.
#
# Any statement that does not contain start with a keyword is
# assigned to the default "AssignStatement" statement.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Lexer::Element';

# Create a new statement.
# You can only set the contents of a statement at construct time,
# since the statement needs to classify itself.
sub new {
	my $class = shift;
	my $self = $class->SUPER::new();
	my @tokens = ref $_[0] ? @{$_[0]} : @_;
	
	# Check the statement contents
	unless ( scalar @tokens ) {
		return $self->_error( "Statement must contain at least 1 token" );
	}
	unless ( $tokens[0]->significant ) {
		return $self->_error( "Statement must start with a significant token" );
	}
	unless ( $tokens[-1]->significant ) {
		return $self->_error( "Statement must end with a significant token" );
	}
	
	# Set the tokens in the statement
	$self->{tokens} = \@tokens;

	# Classify the statement
	$self->_classify or return undef;
	
	# Done
	return $self;
}

# Classify the type of statement this is based on contents
sub _classify {
	my $self = shift;	
	my $key = $self->{tokens}->[0];
	if ( $key->{class} eq 'Bareword' ) {
		if ( $key->{content} eq 'sub' ) {
			# Is this a sub prototype or a sub declaration
			if ( scalar grep { $_->is_a( 'Sub' ) } @{$self->{tokens}} ) {
				# This is a sub declaration
				$self->{class} = 'SubStatement';
			} else {
				# This is a prototype
				$self->{class} = 'SubPrototypeStatement';
			}

		} elsif ( $key->{content} eq 'package' ) {
			$self->{class} = 'PackageStatement';

		} elsif ( $key->{content} eq 'use' ) {
			$self->{class} = 'UseStatement';
			
		} else {
			$self->{class} = 'AssignStatement';
			
		}
	} else {
		$self->{class} = 'AssignStatement';
	}
	
	# Done
	return 1;
}

# Get the tokens in the statement
sub get_tokens {
	my $self = shift;
	
	# Returns as a list
	return @{ $self->{tokens} };
}

# Change the tokens
sub set_tokens {
	my $self = shift;
	my @tokens = ref $_[0] ? @{$_[0]} : @_;

	# Check the statement contents
	unless ( scalar @tokens ) {
		return $self->_error( "Statement must contain at least 1 token" );
	}
	unless ( $tokens[0]->significant ) {
		return $self->_error( "Statement must start with a significant token" );
	}
	unless ( $tokens[-1]->significant ) {
		return $self->_error( "Statement must end with a significant token" );
	}
	
	# Re-set the tokens
	$self->{tokens} = \@tokens;
	
	# Re-classify
	$self->_classify();
	
	# Done
	return 1;
}

# Statements are always significant
sub significant {
	return 1;
}

# Implementing is_a
sub is_a {
	my $self = shift;
	return $_[0] eq $self->{class} ? 1 : 0;
}
	
1;
