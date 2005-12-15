package PPI::Token::Regexp;

=pod

=head1 NAME

PPI::Token::Regexp - Regular expression abstract base class

=head1 INHERITANCE

  PPI::Token::Regexp
  isa PPI::Token
      isa PPI::Element

=head1 DESCRIPTION

The C<PPI::Token::Regexp> class is never instantiated, and simply
provides a common abstract base class for the three regular expression
classes. These being:

m// - L<PPI::Token::Regexp::Match>

s/// - L<PPI::Token::Regexp::Substitute>

tr/// - L<PPI::Token::Regexp::Transliterate>

The names are hopefully obvious enough not to have to explain what
each class is. See their pages for more details.

To save some confusion, it's worth pointing out here that C<qr//> is
B<not> a regular expression (which PPI takes to mean something that
will actually examine or modify a string), but rather a quote-like
operator that acts as a constructor for compiled L<Regexp> objects. 

=cut

use strict;
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.108';
}

1;

=pod

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy, L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2001 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
