package PPI::Format::Apache;

# This class implements an Apache hook to the syntax highlighting capabilities
# of the PPI::Format::HTML module.

use strict;
use UNIVERSAL 'isa';
use Apache ();
use Apache::Constants ':common';
use PPI::Tokenizer    ();
use PPI::Format::HTML ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.803';
}





# The Apache handler, called as a method
sub handler ($$) {
	my $class = shift;
	my $Apache = isa( $_[0], 'Apache' ) ? shift : return $class->_error;

	# Syntax highlighted? ( Default On )
	my $colour = $Apache->dir_config('Colour') or $Apache->dir_config('Color');
	$colour = (lc $colour ne 'off') ? 1 : 0;

	# Show line numbers? ( Default On )
	my $line_numbers = (lc $Apache->dir_config('LineNumbers') ne 'off') ? 1 : 0;

	# Do we have permissions to read the file
	my $filename = $Apache->filename;
	return NOT_FOUND unless -f $filename;
	return FORBIDDEN unless -r $filename;

	# Slurp in the file
	my $content;
	{ local $/ = undef;
	open( PERLFILE, $filename ) or return $class->_error( "open: $!" );
	$content = <PERLFILE>;
	close PERLFILE or return $class->_error;
	}

	# Tokenize the content
	my $Tokenizer = PPI::Tokenizer->new( $content ) 
		or return $class->_error("Failed to create Tokenizer");
	undef $content;

	# Prepare the options
	my $style = $colour ? 'syntax' : 'plain';
	my $options = { linenumbers => $line_numbers };

	# Get the formatted string, we will wrap it ourselves
	my $html = PPI::Format::HTML->serialize( $Tokenizer, $style, $options )
		or return $class->_error("Failed to generate HTML");

	# Destroy the Tokenizer
	%$Tokenizer = ();
	undef $Tokenizer;

	# Change the options for use in the debugging information
	$colour = $colour ? 'On' : 'Off';
	$line_numbers = $line_numbers ? 'On' : 'Off';

	# Send the page header
	$Apache->send_http_header( "text/html; charset=iso-8859-1" );

	# Wrap the code in a page and send
	local $| = 1;
	print <<END;
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
  <meta name="robots" content="noarchive">
</head>
<body bgcolor="#FFFFFF" text="#000000" link="#DDDDDD" vlink="#DDDDDD" alink="#DDDDDD">
<table width="0%" border="0" align="right" cellpadding="3" cellspacing="0">
  <tr>
    <td><a href="http://ali.as/CPAN/PPI"><font size="1" face="Verdana, Arial, Helvetica, sans-serif">PPI::Format::Apache</font></a></td>
  </tr>
</table>
<font face="Courier" size=-1>
$html
</font>
<!--

Debugging Information
Colour: $colour
Line Numbers: $line_numbers

-->
</body>
</html>
END

	OK;
}

# Error with a message...
### MESSAGE CURRENTLY IGNORED
sub _error {
	my $class = shift;
	return SERVER_ERROR;
}

1;

__END__

=pod

=head1 NAME

PPI::Format::Apache - mod_perl hook for perl syntax highlighting

=head1 SYNOPSIS

    # In httpd.conf
    PerlModule PPI::Format::Apache
    <Files ~ "\.pm$">
        SetHandler perl-script
        PerlHandler PPI::Format::Apache
        # PerlSetVar Colour Off
        # PerlSetVar LineNumbers Off
    </Files>

=head1 DESCRIPTION

L<PPI>, via PPI::Format::HTML, provides a method for converting perl source
code into nice looking HTML.

PPI::Format::Apache provides a convenient Apache mod_perl interface to hook
this functionality up, automatically syntax highlighting any perl documents
( as specified by their extension ).

=head2 Configuration

It is recommended you add PPI::Format::Apache to be loaded at server startup,
via the command

    PerlModule PPI::Format::Apache

PPI consumes 2-3 meg of memory, and it is far better than this is done once
and shared, rather than have every Apache child process do it seperately.

The C<SetHandler> and C<PerlHandler> commands are as per normal for an Apache
mod_perl handler. See the mod_perl docs for more details.

=head2 Options

By default, PPI::Format::Apache will show files syntax highlighted and with
line numbers. You can set either or both of the following two options to turn
colour or line numbers off.

    PerlSetVar Colour Off
    PerlSetVar LineNumbers Off

=head1 TO DO

=over 4

=item Add the ability to see the raw file

=item As PPI is somewhat slow, add the ability to cache the generated HTML

=back

=head1 SUPPORT

For general comments, contact the author.

To file a bug against this module, in a way you can keep track of, see the CPAN
bug tracking system.

http://rt.cpan.org/

=head1 AUTHOR

        Adam Kennedy ( maintainer )
        cpan@ali.as
        http://ali.as/

=head1 SEE ALSO

L<PPI::Manual>, http://ali.as/CPAN/PPI

=head1 COPYRIGHT

Copyright (c) 2002 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;
