package PPI::Tokenizer::Token;

# This package represents a single token ( chunk of characters ) in a perl
# source code file

use strict;
use UNIVERSAL;
use base 'PPI::Common';

use vars qw{$classOffset};
BEGIN { $classOffset = 23; }
sub new {
	# Create the token
	my $self = {
		zone => $_[1],
		content => '',
		class => substr( $_[0], $classOffset ),
		};
	bless $self, $_[0];
	
	# Set the starting content
	if ( defined $_[2] ) {
		$self->{content} = $_[2];
	}	
	return $self;
}

# Add a string
sub add { $_[0]->{content} .= $_[1] }

# Get some variables
sub content { $_[0]->{content} }
sub zone {
	my $self = shift;
	my $zone = $self->{zone};
	$zone =~  s/^.*(?>::)//;
	return $zone;
}
sub class { $_[0]->{class} }
	
# Provide defaults for methods
sub on_line_start { 1 }
sub on_line_end { 1 }
sub on_char { 'Unknown' }

sub set_class {
	my $class = PPI::Tokenizer->_resolve_class( $_[1] ) or return undef;

	# Rebless the token
	bless $_[0], $class;
	$_[0]->{class} = $_[1];
	return 1;
}

sub set_content { $_[0]->{content} = $_[1] }
sub length { &CORE::length( $_[0]->{content} ) }
sub is_a {
	my $self = shift;
	my $type = shift;
	my $content = shift;
	return 0 unless ref $self eq "PPI::Tokenizer::Token::$type";
	return 1 unless defined $content;
	return $self->{content} eq $content ? 1 : 0;
}

# Is the token significant ( Not comment or whitespace etc )
use vars qw{$notSignificant};
BEGIN {
	$notSignificant = {
		Base => 1,
		Comment => 1,
		Pod => 1,
		};
}
sub significant { $notSignificant->{ $_[0]->{class} } ? 0 : 1 }

# Putting in the ever expected to_string method
sub to_string { $_[0]->{content} }

# Deep copy a token
sub copy { 
	my $self = shift;
	return bless {%$self}, ref $self;
}

# Is the string escaped
sub is_really_escaped {
	my $class = shift;
	my $string = shift;
	
	# Get the count of previous slashes
	$string =~ /(\\+)$/ or die "Something is wrong";
	my $count = &CORE::length($1);
		
	# Escape ONLY if we have an odd number of escapes.
	return ( $count % 2 ) ? 1 : 0;
}
	
1;
