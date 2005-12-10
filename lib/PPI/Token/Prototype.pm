package PPI::Token::Prototype;

=pod

=head1 NAME

PPI::Token::Prototype - A subroutine prototype descriptor

=head1 INHERITANCE

  PPI::Token::End
  isa PPI::Token
      isa PPI::Element

=head1 SYNOPSIS

  sub ($@) prototype;

=head1 DESCRIPTION

Although it sort of looks like a list or condition, a subroutine
prototype is a lot more like a string. It's job is to provide hints
to the perl compiler on what type of arguments a particular subroutine
expects, which the compiler uses to validate parameters at compile-time,
and allows programmers to use the functions without explicit parameter
braces.

Due to the rise of OO Perl coding, which ignores these prototypes, they
are most often used to allow for constant-like things, and to "extend"
the language and create things that act like keywords and core functions.

  # Create something that acts like a constant
  sub MYCONSTANT () { 10 }
  
  # Create the any core-looking function
  sub any (&@) { ... }
  
  if ( any { $_->sexy } @chicks ) {
  	...
  }

=head1 METHODS

This class provides one additional method beyond those defined by the
L<PPI::Token> and L<PPI::Element> parent classes.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.105';
}

sub __TOKENIZER__on_char {
	my $class = shift;
	my $t = shift;

	# Suck in until we find the closing bracket (or the end of line)
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(.*?(?:\)|$))/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Finish off the token and process the next char
	$t->_finalize_token->__TOKENIZER__on_char( $t );
}

=pod

=head2 prototype

The C<prototype> accessor returns the actual prototype patter, stripped
of braces and any whitespace inside the pattern.

=cut

sub prototype {
	my $self = shift;
	my $prototype = $self->content;
	$prototype =~ s/\(\)\s//g; # Strip brackets and whitespace
	$prototype;
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
