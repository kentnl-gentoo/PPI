package PPI;

# See POD at end for documentation

use 5.005;
use strict;
# use warnings;
# use diagnostics;
use UNIVERSAL 'isa';
use Class::Inspector ();
use Class::Autouse   ();

# Set the version for CPAN
use vars qw{$VERSION $XS_COMPATIBLE @XS_EXCLUDE};
BEGIN {
	$VERSION       = '0.902';
	$XS_COMPATIBLE = '0.845';
	@XS_EXCLUDE    = ();
}

# Always load the entire PDOM
use PPI::Element   ();
use PPI::Token     ();
use PPI::Statement ();
use PPI::Structure ();

# Autoload the remainder of the classes
use Class::Autouse 'PPI::Document',
                   'PPI::Document::Normalized',
                   'PPI::Normal',
                   'PPI::Tokenizer',
                   'PPI::Lexer';

# If it is installed, load in PPI::XS
if ( Class::Inspector->installed('PPI::XS') ) {
	require PPI::XS unless $PPI::XS_DISABLE;
}

1;

__END__

=pod

=head1 NAME

PPI - BETA: Analyze and manipulate Perl code without using perl itself (Beta 1)

=head1 DESCRIPTION

This is PPI, originally short for Parse::Perl::Isolated, a package for
parsing and manipulating Perl documents.

For more information, see the L<PPI Manual|PPI::Manual>

PPI.pm itself provides the primary mechanism for loading the PPI API,
a family of around 50 classes.

=head1 SUPPORT

Anything documented is considered to be frozen, and bugs should always
be reported at:

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
