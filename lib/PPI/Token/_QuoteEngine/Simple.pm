package PPI::Token::_QuoteEngine::Simple;

# Simple quote engine

use strict;
use base 'PPI::Token::_QuoteEngine';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840';
}





sub new {
	my $class     = shift;
	my $seperator = shift or return undef;

	# Create a new token containing the seperator
	### This manual SUPER'ing ONLY works because none of
	### Token::Quote, Token::QuoteLike and Token::Regexp
	### implement a new function of their own.
	my $self = PPI::Token::new( $class, $seperator ) or return undef;
	$self->{seperator} = $seperator;

	$self;
}

sub _fill {
	my $class = shift;
	my $t     = shift;
	my $self  = $t->{token} or return undef;

	# Scan for the end seperator
	my $string = $self->_scan_for_unescaped_character( $t, $self->{seperator} );
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

sub string {
	my $self = shift;
	substr( $self->{content}, 1, length($self->{content}) - 2 );
}

1;
