package AppLib::HTML::Form;

=pod

=head1 NAME

AppLib HTML Form Element Generator

=head1 DESCRIPTION

The AppLib::HTML::Form package is a class containing a series
of static methods used to generate HTML form elements in a more logical
way than the pure CGI.pm module approach.

AppLib::HTML::Form does not use CGI.pm to generate any of it's
html, it prefers to use it's own internal tag generators in
L<AppLib::HTML>.

=cut

use strict;
use base 'AppLib::Error';
use Class::Autouse;

# Make sure the main HTML library is loaded
BEGIN {
	# We will always need this, and right away too
	Class::Autouse->load( 'AppLib::HTML' )
}





#####################################################################
# Form componants

=pod

=head1 METHODS

=head2 textbox( $name, $value, \%options )

The C<textbox> method generates a regular textbox.

The C<$name> argument defines the name property for the text box.

The C<$value> argument defines a default value for the text box. By default,
this value will be automatically escaped for use as a html property, so that
any value can be used, and it will become safe HTML. This primarily affect
things like quotes and angle brackets in the value.

An optional hashref containing options can be provided. Some of these are
recognised internally, and the some are passed on as additional properties
to be added to the E<lt>inputE<gt> tag. The remainder are ignored.

=over 4

=item C<dontescape>

The dontescape options, if provided, will cause the generator to assume that
C<$value> is already escaped, and to not escape it again.

=item C<class>

Any class option is passed through to define a stylesheet class for the textbox.

=item C<size>

Any size option is passed through to the textbox.

=item C<maxlength>

Any maxlength option is passed through to the textbox.

=back

The C<textbox> method returns a HTML string on success, or C<undef> on error.

=cut

# Generate a textbox
sub textbox {
	my $class = shift;
	my $name = shift or return undef;
	my $value = shift;
	my $opt = shift || {};
	my %props = ( type => 'text', name => $name, value => $value );
	$value =~ s/$AppLib::HTML::property/$AppLib::HTML::escapeMap{$1}/g
		unless $opt->{dontescape};

	# Pass through options
	foreach ( qw{size maxlength class} ) {
		$props{$_} = $opt->{$_} if defined $opt->{$_};
	}
	return AppLib::HTML->tag( 'input', \%props );
}

=pod


=head2 textarea( $name, $content, \%options )

The C<textarea> method generates a regular textarea input.

The C<$name> argument defines the name property of the textarea.

The C<$content> argument defines the initial contents of the textarea. This
contents is automatically escaped by default for use as the textarea content.

An optional hashref containing options can be provided. Some of these are
recognised internally, some are passed on as additional properties to add
to the E<lt>inputE<gt> tag, and the remainder are ignored.

=over 4

=item dontescape

The C<dontescape> options, if provided, will cause the generator to assume that
C<$contents> is already escaped, and to not escape it again.

=item cols

The C<cols> option will be passed through as a textarea property.

=item rows

The C<rows> option will be passed through as a textarea property.

=item class

The C<class> option will be passed through as a textarea property, to define the
style used for the textarea.

=item wrap

The C<wrap> options option, if provided, will be passed through as a textarea
property, to define the wrapping form to use.

=back

=cut

# Generate a text area
sub textarea {
	my $class = shift;
	my $name = shift or return undef;
	my $content = shift;
	my $opt = shift || {};
	my %props = ( name => $name );
	$content =~ s/$AppLib::HTML::textarea/$AppLib::HTML::escapeMap{$1}/g
		unless $opt->{dontescape};

	# Pass through options
	foreach ( qw{cols rows class} ) {
		$props{$_} = $opt->{$_} if defined $opt->{$_};
	}

	# Handle special options
	$props{wrap} = uc $opt->{wrap} if defined $opt->{wrap};

	### FIXME - Add support for that weird IE html edit tag
	# $props{SOMETHING} = undef if exists $opt->{SOMETHING};

	return AppLib::HTML->tagPair( 'textarea', \%props, $content );
}

=pod

=head2 dropbox( $name, \@data, $value, \%options )

The C<dropbox> method generates a dropbox based on a select tag.

The C<$name> argument defines the name property of the textarea.

The C<\@data> argument is a reference to an array that contains a
series of 'options'. The single option consist of a reference an
a 2 element array, where the first element is the 'value' of the
options, and the second element is the 'label' displayed to the
user.

An simple example argument would be

  # Example data set
  my $data = [
    [ 1, 'One' ],
    [ 2, 'Two' ],
    [ 3, 'Three' ],
    ];

In many dropboxs, text is provided for the null case, for when
nothing is selected. In out case, this is the label provided
for the value '', as seen above.

The C<$value> argument is the initial value to set the dropbox
to, null by default. If should be passed as C<undef> is no value
is to be selected by default.

An optional hashref containing options can be provided. Some of these are
recognised internally, some are passed on as additional properties to add
to the E<lt>selectE<gt> or E<lt>optionE<gt> tags, and the remainder are ignored.

=over 4

=item dontescape

The C<dontescape> option, if provided, will cause the generator to assume that
the labels are already escaped, and to not escape it again. The values are never
escaped.

=item class

The C<class> option, if provided, will set a class value for the select tag.

=item onChange

The C<onChange> option, if provided, will be passed through to the select tag
to specify a javascript action to take when the dropbox is changed.

=item notnull

The C<notnull> option, if set to true, causes the generator to not show the null
option.

=item nullstring

The C<nullstring> option, if provided, specifies a string to display for the null
option, unless it has been provided in the options, as the C<[ '', 'nullstring' ]>
option.

=back

=cut

# Creates a drop box
sub dropbox {
	my $class = shift;
	my $name = shift or return undef;
	my $data = shift or return undef;
	my $value = shift;
	my $opt = shift || {};

	# Create the options array, and add all the data options
	my $havenull = 0;
	my @options = ();
	foreach ( @$data ) {
		$havenull = 1 if $_->[0] eq '';
		$_->[1] =~ s/$AppLib::HTML::text/$AppLib::HTML::escapeMap{$1}/g
			unless $opt->{dontescape};

		# Add the option to the array
		push @options, (defined $value and $value eq $_->[0])
			? "<option value=\"$_->[0]\" selected>$_->[1]</option>\n"
			: "<option value=\"$_->[0]\">$_->[1]</option>\n";
	}

	# Add the null entry if we can have it and do need it
	if ( ! $opt->{notnull} or $havenull ) {
		$opt->{nullstring} = '' unless defined $opt->{nullstring};
		unshift @options, (defined $value and $value ne '')
			? "<option value=''>$opt->{nullstring}</option>\n"
			: "<option value='' selected>$opt->{nullstring}</option>\n";
	}

	# Now build the final tag and return
	my %props = ( name => $name );
	foreach ( qw{class onChange} ) {
		$props{$_} = $opt->{$_} if exists $opt->{$_};
	}
	return AppLib::HTML->tagPair( 'select', \%props, join( '', @options ) );
}

=pod

=head2 radio( $name, \@data, $value, $layout, \%options )

TO BE COMPLETED

=cut

# Generate a cluster of radio buttons
# Create a set of radio buttons
sub radio {
	my $class = shift;
	my $name = shift or return undef;
	my $data = shift or return '';
	my $value = shift;
	my $layout = shift or return undef;
	my $opts = shift || {};

	# Map the value half of the data into radio buttons
	foreach ( @$data ) {
		my $props = {
			type => 'radio',
			name => $name,
			value => defined $_->[0] ? $_->[0] : ''
			};
		$props->{checked} = undef if $_->[0] eq $value;
		if ( $opts->{autoid} or $opts->{activelabels} ) {
			$props->{id} = "$name\_$_->[0]";

			# If they want active labels, map the labels to label tags
			if ( $opts->{activelabels} ) {
				$_->[1] = AppLib::HTML->tagPair( 'label',
					{ 'for' => $props->{id} },
					$_->[1] );
			}
		}
		$_->[0] =~ s/$AppLib::HTML::property/$AppLib::HTML::escapeMap{$1}/g unless $opts->{dontescape};
		$_->[0] = AppLib::HTML->tag( 'input', $props );


	}

	# Now, hand them over to the appropriate layout method
	$layout = 'vertical' unless $layout;
	if ( $layout eq 'vertical' ) {
		return join "<br>\n", map { "$_->[0]$_->[1]" } @$data;

	} elsif ( $layout eq 'horizontal' ) {
		return join " \n", map { $_->[0] . $_->[1] } @$data;

	} elsif ( $layout eq 'table' ) {
		# Generate the cell pairs
		my @cellpairs = ();
		my %cellprops = ref $opts->{td} ? %{$opts->{td}} : ();
		$cellprops{valign} = 'top' unless defined $cellprops{valign};
		$cellprops{nowrap} = undef if $opts->{nowrap};

		foreach ( @$data ) {
			push @cellpairs, "    "
				. AppLib::HTML->tagPair( 'td', \%cellprops, $_->[0] )
				. AppLib::HTML->tagPair( 'td', \%cellprops, $_->[1] );
		}

		# Format the cell pairs into a grid
		my @rows = ();
		my $cols = $opts->{cols} ? $opts->{cols}
			: $opts->{rows} ? ceil(scalar(@cellpairs) / $opts->{rows})
			: 1;
		while ( scalar @cellpairs ) {
			push @rows, join( '', map { "    $_\n" } splice(@cellpairs, 0, $cols) );
		}

		# Generate the final table html
		my $table = join "\n", map { "  <tr>\n    $_\n  </tr>" } @rows;
		my %tableprops = ref $opts->{table} ? %{$opts->{table}} : ();
		$tableprops{border} = 0 unless defined $tableprops{border};
		$tableprops{cellspacing} = 0 unless defined $tableprops{cellspacing};
		$tableprops{cellpadding} = 1 unless defined $tableprops{cellpadding};
		return AppLib::HTML->tagPair( 'table', \%tableprops, $table );

	} elsif ( isa( $layout, 'CODE' ) ) {
		# Hand off to the external layout method
		return &{$layout}($data, $opts);

	} else {
		return "Unknown radio button layout format '$layout'";
	}
}

=pod

=head2 checkbox( $name, $value, \%options )

TO BE COMPLETED

=cut

# Generate a checkbox
sub checkbox {
	my $class = shift;
	my $name = shift or return undef;
	my $value = shift;
	my $opt = shift || {};
	my %props = ( type => 'checkbox', name => $name, value => $value );
	$value =~ s/$AppLib::HTML::property/$AppLib::HTML::escapeMap{$1}/g unless $opt->{dontescape};

	# Pass through options
	foreach ( qw{class id} ) {
		$props{$_} = $opt->{$_} if defined $opt->{$_};
	}
	if ( $opt->{checked} ) {
		$props{checked} = undef;
	} else {
		delete $props{checked};
	}
	return AppLib::HTML->tag( 'input', \%props );
}

=pod

=head2 hidden( $name, $value )

=cut

# Create a hidden field
sub hidden {
	my $class = shift;
	my $name = shift or return undef;
	my $value = shift;

	# Escape the name and value
	$name = AppLib::HTML->escapeProperty( $name );
	$value = AppLib::HTML->escapeProperty( $value );

	# Generate the tag
	return AppLib::HTML->tag( 'input', {
		type => 'hidden',
		name => $name,
		value => $value
		} );
}

1;

__END__

=head1 TODO

This module is not as complete as I would like, but nothing immediately
springs to mind to do to it.

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
