package AppLib::HTML;

=pod

=head1 NAME

AppLib HTML Generation API

=head1 DESCRIPTION

The AppLib HTML Generation API is a set of classes containing mainly static
methods that generates HTML for a variety of tasks.

The AppLib::HTML package itself holds commonly used HTML related methods,
such as escaping and tag generation.

The L<AppLib::HTML::Form> class contains methods for generating form elements.

The L<AppLib::HTML::Table> is a class that implements the generation of quite
complex HTML tables.

=cut

use strict;
use UNIVERSAL 'isa';
use base 'AppLib::Error';





#####################################################################
# Escaping Methods

# First, provide some resources.
use vars qw{%escapeMap $text $property $textarea};
BEGIN {
	%escapeMap = (
		'&' => '&amp;',
		'<' => '&lt;',
		'>' => '&gt;',
		'"' => '&quot;',
		"'" => '&#039;',
		"\n" => "<br>\n",
		);
	$text = qr/([&<>])/;
	$property = qr/([&<>"'])/;
	$textarea = qr/([&<>"'])/;
}

=pod

=head2 escapeText( $text )

The C<escapeText> method escapes 'text' for general purpose uses.

=cut

sub escapeText { $_[1] =~ s/([&<>])/$escapeMap{$1}/g; $_[1] }

=pod

=head2 escapeProperty( $text )

The C<escapeProperty> method escapes text for use in HTML tag
properties. In these situations, extra attention needs to be
paid to ensure that quotes are always properly escaped.

=cut

sub escapeProperty { $_[1] =~ s/([&<>"'])/$escapeMap{$1}/g; $_[1] }

=pod

=head2 escapeTextArea( $text )

Escape text for the special case of text in a textarea.

=cut

sub escapeTextArea { $_[1] =~ s/([&<>"'])/$escapeMap{$1}/g; $_[1] }

=pod

=head2 escapeHTMLText( $text )

The C<escapeHTMLText> method escapes text for display on a HTML page,
especially in situations where the text might contains line breaks etc.

=cut

sub escapeHTMLText {
	$_[1] =~ s/([&<>])/$escapeMap{$1}/g;
	$_[1] =~ s/(\015\012|\015|\012)/<br>\n/g;
	return $_[1];
}





#####################################################################
# Callback Generators

=pod

=head2 linkCallback( $text, \%args, \%options )

TO BE COMPLETED

=cut

# Create a generic callback link.
# Don't escape, that is left to the caller
sub linkCallback {
	my $class = shift;
	my $text = shift;
	my $args = shift || {};
	my $options = shift || {};
	return undef unless isa( $args, 'HASH' );
	return undef unless isa( $options, 'HASH' );

	# Copy the options and args to avoid
	# corrupting passed values
	$args = { %$args };
	$options = { %$options };

	# Avoid warnings in the map below
	foreach ( keys %$args ) {
		$args->{$_} = '' unless defined $args->{$_};
	}

	# Create the href
	my $arg_string = join( '&', map { "$_=$args->{$_}" } keys %$args );
	my $href = $ENV{SCRIPT_NAME};
	$href .= $ENV{PATH_INFO} if defined $ENV{PATH_INFO};
	$href .= "?$arg_string" if (defined $arg_string and length $arg_string);

	# Create the full set of tag options
	$options->{href} = $href;
	return $class->tagPair( 'a', $options, $text );
}





#####################################################################
# String generators

=pod

=head2 tag( $name, \%properties )

Generates an arbitrary tag, somewhat like CGI.pm does.

To reduce load, this method does not do escaping or case alteration.
Escaping untrusted strings is left to the caller.

TO BE COMPLETED

=cut

sub tag {
	my $class = shift;
	my $tag = shift or return undef;
	my $props = shift or return undef;
	return '<'
		. join(' ', $tag, map { defined $props->{$_}
			? "$_=\"$props->{$_}\""
			: "$_"
			} keys %$props)
		. '/>';
}

=pod

=head2 tagPair( $name, $props, @contents )

Generate a pair of tags with content in them.

To reduce load, this method does not do escaping or case alteration.
Escaping untrusted strings is left to the caller.

TO BE COMPLETED

=cut

sub tagPair {
	my $class = shift;
	my $tag = shift or return undef;
	my $props = shift or return undef;

	# Generate the open tag ( as above )
	my $html = '<'
		. join(' ', $tag, map { defined $props->{$_}
			? "$_=\"$props->{$_}\""
			: "$_"
			} keys %$props)
		. '>';

	# Add the content ( escaping is left to the caller )
	# and the closing tag, and return.
	return $html . join( '', @_ ) . "</$tag>";
}

1;

__END__

=pod

=head1 TO DO

Reorganise the methods somewhat, especially the escaping ones.

Chase down all references to them, and fix them as well ( there
will be a lot )

=head1 COPYRIGHT

Copyright (C) 2000-2002 Adam Kennedy

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

Should you wish to utilise this software under a different licence,
please contact the author.

=cut
