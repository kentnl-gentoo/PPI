package PPI::Statement::End;

=pod

=head1 NAME

PPI::Statement::End - Content after the __END__ of a module

=head1 SYNOPSIS

  # This is normal content
  
  __END__
  
  This is part of an PPI::Statement::End statement
  
  =pod
  
  This is not part of the ::End statement, it's POD
  
  =cut
  
  This is another PPI::Statement::End statement

=head1 INHERITANCE

  PPI::Statement::End
  isa PPI::Statement
      isa PPI::Node
          isa PPI::Element

=head1 DESCRIPTION

C<PPI::Statement::End> is a utility class designed to serve as a contained
for all of the content after the __END__ tag in a file.

It doesn't cover the ENTIRE of the __END__ section, and can be interspersed
with L<PPI::Token::Pod> tokens.

=head1 METHODS

C<PPI::Statement::End> has no additional methods beyond the default ones
provided by L<PPI::Statement>, L<PPI::Node> and L<PPI::Element>.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.991';
}

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
