package PPI::Token::Quote;

=pod

=head1 NAME

PPI::Token::Quote - String quote abstract base class

=head1 INHERITANCE

  PPI::Token::Quote
  isa PPI::Token
      isa PPI::Element

=head1 DESCRIPTION

The C<PPI::Token::Quote> class is never instantiated, and simply
provides a common abstract base class for the four quote classes.
In PPI, a "quote" is limited to only the quote-like things that
themselves directly represent a string. (although this includes
double quotes with interpolated elements inside them).

The subclasses of C<PPI::Token::Quote> are:

C<''> - L<PPI::Token::Quote::Single>

C<q{}> - L<PPI::Token::Quote::Literal>

C<""> - L<PPI::Token::Quote::Double>

C<qq{}> - L<PPI::Token::Quote::Interpolate>

The names are hopefully obvious enough not to have to explain what
each class is here. See their respective pages for more details.

Please note that although the here-doc B<does> represent a literal
string, it is such a nasty piece of work that in L<PPI> it is given the
honor of it's own token class (L<PPI::Token::HereDoc>).

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.995';
}





#####################################################################
# PPI::Token::Quote Methods

=pod

=head2 string

The C<string> method is provided by all four ::Quote classes. It won't
get you the actual literal Perl value, but it will strip off the wrapping
of the quotes.

  # The following all return foo from the ->string method
  'foo'
  "foo"
  q{foo}
  qq <foo>

=cut

#sub string {
#	my $class = ref $_[0] || $_[0];
#	die "$class does not implement method ->string";
#}

1;

=pod

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy, L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
