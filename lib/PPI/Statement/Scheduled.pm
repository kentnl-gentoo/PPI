package PPI::Statement::Scheduled;

=pod

=head1 NAME

PPI::Statement::Scheduled - A scheduled code block

=head1 INHERITANCE

  PPI::Statement::Scheduled
  isa PPI::Statement
      isa PPI::Node
          isa PPI::Element

=head1 DESCRIPTION

A scheduled code block is one that is intended to be run at a specific
time during the loading process.

There are four types of scheduled block:

  BEGIN {
  	# Executes as soon as this block is fully defined
  	...
  }
  
  CHECK {
  	# Executes after compile-phase in reverse order
  	...
  }
  
  INIT {
  	# Executes just before run-time
  	...
  }
  
  END {
  	# Executes as late as possible in reverse order
  	...
  }

Technically these scheduled blocks are actually subroutines, and in fact
may have 'sub' in front of them.

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Statement';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.904';
}

sub __LEXER__normal { '' }

=pod

=head2 type

The C<type> method returns the type of scheduled block, which should always be
one of 'BEGIN', 'CHECK', 'INIT' or 'END'.

=cut

sub type {
	my $self = shift;
	my @children = $self->schildren or return undef;
	$children[0]->content eq 'sub'
		? $children[1]->content
		: $children[0]->content;
}

=pod

=head2 block

With its name and implementation shared with
L<PPI::Statement::Sub|PPI::Statement::Sub>, the C<block> method finds and
returns the actual Structure object of the block for this scheduled block.

Returns false if it cannot find a block (although why this might happen
I'm not sure).

=cut

sub block {
	my $self = shift;
	my $lastchild = $self->schild(-1);
	isa($lastchild, 'PPI::Structure::Block') and $lastchild;
}

1;

=pod

=head1 TO DO

- Write unit tests for this package

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
