package PPI::Token::Quote::Single;

=pod

=head1 NAME

PPI::Token::Quote::Single - A 'single quote' token

=head1 INHERITANCE

  PPI::Token::Quote::Single
  isa PPI::Token::Quote
      isa PPI::Token
          isa PPI::Element

=head1 SYNOPSIS

  'This is a single quote'
  
  q{This is a literal, but NOT a single quote}

=head1 DESCRIPTION

A C<PPI::Token::Quote::Single> object represents a single quoted string
literal. 

=head1 METHODS

There are no methods available for C<PPI::Token::Quote::Single> beyond
those provided by the parent L<PPI::Token::Quote>, L<PPI::Token> and
L<PPI::Element> classes.

Got any ideas for methods? Submit a report to rt.cpan.org!

=cut

use strict;
use base 'PPI::Token::_QuoteEngine::Simple',
         'PPI::Token::Quote';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.100_03';
}





#####################################################################
# PPI::Token::Quote Methods

=pod

=begin testing string 3

my $Document = PPI::Document->new( \"print 'foo';" );
isa_ok( $Document, 'PPI::Document' );
my $Single = $Document->find_first('Token::Quote::Single');
isa_ok( $Single, 'PPI::Token::Quote::Single' );
is( $Single->string, 'foo', '->string returns as expected' );

=end testing

=cut

sub string {
	my $str = $_[0]->{content};
	substr( $str, 1, length($str) - 2 );
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
