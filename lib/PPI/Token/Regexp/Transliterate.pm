package PPI::Token::Regexp::Transliterate;

=pod

=head1 NAME

PPI::Token::Regexp::Transliterate - A transliteration regular expression token

=head1 INHERITANCE

  PPI::Token::Regexp::Transliterate
  isa PPI::Token::Regexp
      isa PPI::Token
          isa PPI::Element

=head1 SYNOPSIS

  $text =~ tr/abc/xyz/;

=head1 DESCRIPTION

A C<PPI::Token::Regexp::Transliterate> object represents a single
transliteration regular expression.

I'm afraid you'll have to excuse the rediculously long class name, but
when push came to shove I ended up going for pedantically correct
names for things (practically cut and paste from the various docs).

=head1 METHODS

There are no methods available for C<PPI::Token::Regexp::Transliterate>
beyond those provided by the parent L<PPI::Token::Regexp>, L<PPI::Token>
and L<PPI::Element> classes.

Got any ideas for methods? Submit a report to rt.cpan.org!

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token::_QuoteEngine::Full',
         'PPI::Token::Regexp';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.102';
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
