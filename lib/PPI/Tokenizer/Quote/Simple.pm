package PPI::Tokenizer::Quote::Simple;

# Simple quote engine

use strict;
use base 'PPI::Tokenizer::Quote';

sub new {
	my $class = shift;
	my $zone = shift;
	my $seperator = shift;
	return undef unless $seperator;
	
	# Create a new token containing the seperator
	my $self = $class->SUPER::new( $zone, $seperator ) or return undef;
	$self->{seperator} = $seperator;
	return $self;
}

sub fill {
	my $class = shift;
	my $t = shift;
	my $self = $t->{token} or return undef;
	
	# Scan for the end seperator
	my $string = $self->_scanForUnescapedCharacter( $t, $self->{seperator} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	} else {
		# End of string
		$self->{content} .= $string;
		return $self;
	}
}

sub getString {
	my $self = shift;
	return substr( $self->{content}, 1, length($self->{content}) - 2 );
}

1;
