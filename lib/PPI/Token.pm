package PPI::Token;

# This package represents a single token ( chunk of characters ) in a perl
# source code file

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Element';

# When we load PPI::Token, make sure all our children are loaded.
# Note that the load order is important here.
use PPI::Token::Quote         ();
use PPI::Token::Quote::Simple ();
use PPI::Token::Quote::Full   ();
use PPI::Token::Unknown       ();
use PPI::Token::Classes       (); # This must be last

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.818';
}





# Create a new token
sub new {
	if ( scalar @_ == 2 ) {
		# PPI::Token->new( $content );
		my $class = $_[0] eq __PACKAGE__ ? 'PPI::Token::Whitespace' : shift;
		return bless {
			content => (defined $_[0] ? "$_[0]" : '')
			}, $class;
	} elsif ( scalar @_ == 3 ) {
		# PPI::Token->new( $class, $content );
		my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::' ? $_[1] : "PPI::Token::$_[1]";
		return bless {
			content => (defined $_[2] ? "$_[2]" : '')
			},  $class;
	}
	
	# Invalid argument count
	undef;
}

sub set_class {
	my $self = shift;
	return undef unless @_;
	my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::' ? shift : 'PPI::Token::' . shift;

	# Find out if the current and new classes are complex
	my $old_quote = (ref($self) =~ /\b(?:Quote|Regex)\b/o) ? 1 : 0;
	my $new_quote = ($class =~ /\b(?:Quote|Regex)\b/o) ? 1 : 0;

	# No matter what happens, we will have to rebless
	bless $self, $class;

	# If we are changing to or from a Quote style token, we
	# can't just rebless and need to do some extra thing
	# Otherwise, we have done enough
	return 1 if ($old_quote - $new_quote) == 0;

	# Make a new token from the old content, and overwrite the current
	# token's attributes with the new token's attributes.
	my $token = $class->new( $self->{content} ) or return undef;
	delete $self->{$_} foreach keys %$self;
	$self->{$_} = $token->{$_} foreach keys %$token;

	1;
}





#####################################################################
# Content related

sub content     { $_[0]->{content} }
sub set_content { $_[0]->{content} = $_[1] }
sub add_content { $_[0]->{content} .= $_[1] }
sub length      { &CORE::length( $_[0]->{content} ) }





#####################################################################
# Tokenizer Default Methods

sub _on_line_start { 1 }
sub _on_line_end   { 1 }
sub _on_char       { 'Unknown' }





#####################################################################
# Structure Related Tests

sub _opens  { ref($_[0]) eq 'PPI::Token::Structure' and $_[0]->{content} =~ /(?:\(|\[|\{)/ }
sub _closes { ref($_[0]) eq 'PPI::Token::Structure' and $_[0]->{content} =~ /(?:\)|\]|\})/ }





#####################################################################
# Miscellaneous Analysis and Utilities

# Provide a more detailed test on a token
sub is_a {
	my $self = shift;

	# Test the class
	my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::' ? shift
		: 'PPI::Token::' . shift;
	return '' unless isa( $self, $class );

	# Test the content if needed
	! (@_ and $self->{content} ne shift);
}

1;
