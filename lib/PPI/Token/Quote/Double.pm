package PPI::Token::Quote::Double;

# Double Quote

use strict;
use base 'PPI::Token::_QuoteEngine::Simple',
         'PPI::Token::Quote';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.902';
}

# Initially return true/fales for if there are ANY interpolations.
# Upgrade: Return the interpolated substrings.
# Upgrade: Returns parsed expressions.
sub interpolations {
	my $self = shift;

	# Are there any unescaped $things in the string
	!! $self->content =~ /(?<!\\)(?:\\\\)*\$/;
}

# Simplify a double-quoted string into a single-quoted string
sub simplify {
	# This only works on EXACTLY this class
	my $self = (ref $_[0] eq 'PPI::Token::Quote::Double') ? shift : return undef;

	# Don't bother if there are characters that could complicate things
	my $content = $self->content;
	my $value   = substr($content, 1, length($content) - 1);
	return '' if $value =~ /[\\\$\'\"]/;

	# Change the token to a single string
	$self->{content} = '"' . $value . '"';
	bless $self, 'PPI::Token::Quote::Single';
}

1;
