package PPI;

=pod

=head1 NAME

PPI - Parse and manipulate Perl code non-destructively, without using perl itself

=head1 DESCRIPTION

This is PPI, originally short for Parse::Perl::Isolated, a package for parsing
and manipulating Perl documents.

For more information, see the L<PPI Manual|PPI::Manual>

The PPI itself provides the primary mechanism for loading the PPI library,
as the full library contains over 50 classes.

=cut

use 5.005;
use strict;
# use warnings;
# use diagnostics;
use UNIVERSAL 'isa';
use Class::Autouse;

# Load the essentials
use base 'PPI::Base';
use PPI::Token     ();
use PPI::Statement ();
use PPI::Structure ();

# Set the version for CPAN
use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840_01';
}





# Build a regex library containing just the bits we need,
# and precompile them all. Note that in all the places that
# have critical speed issues, the regexs have been inlined.
use vars qw{%RE};
BEGIN {
	%RE = (
		CLASS        => qr/[\w:]/,                       # Characters anywhere in a class name
		SYMBOL_FIRST => qr/[^\W\d]/,                     # The first character in a perl symbol
		xpnl         => qr/(?:\015{1,2}\012|\015|\012)/, # Cross-platform newline
		blank_line   => qr/^\s*$/,
		comment_line => qr/^\s*#/,
		pod_line     => qr/^=(\w+)/,
		end_line     => qr/^\s*__(END|DATA)__\s*$/,
		);
}





# Autoload the remainder of the classes
use Class::Autouse 'PPI::Document',
                   'PPI::Tokenizer',
                   'PPI::Lexer';

1;

=cut

=head1 SUPPORT

Although this is pre-beta, what code is there should actually work. So if you
find any bugs, they should be submitted via the CPAN bug tracker, located at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI>

For other issues, or commercial enhancement or support, contact the author.. In particular, if you want to make a
CPAN or private module that uses PPI, it would be best to stay in direct
contact with the author until PPI goes beta.

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Thank you to Phase N (L<http://phase-n.com/>) for permitting
the open sourcing and release of this distribution.

Copyright (c) 2004 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
