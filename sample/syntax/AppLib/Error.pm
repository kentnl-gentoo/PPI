# See end of file for licensing information

package AppLib::Error;

# Centralised error handling module

# The error handler uses the concept of an error stack
# each time an andError is called, it adds an error message
# to a stack

# If an error cascade upwards catches the error, the catchError
# function should be called. This has the effect of resetting the
# error stack the next time andError is called.

use strict;
use Class::Autouse;

# Declare package globals
use vars qw{@errStack $caught};
BEGIN {
	@errStack = ();
	$caught = 0;
}

# Add an error message to the stack
# The function will only add the first argument to the stack
sub andError {
	my $class = shift;
	$class = ref $class if ref $class;

	# Reset the error stack if someone has previously caught
	# an error
	if ( $caught ) {
		$caught = 0;
		@errStack = ();
	}

	# Add the error to the stack
	push @errStack, map { [ $class, $_ ] } reverse @_;
	return undef;
}

# Return a copy of the stack as a reference to a list
sub errStack {
	my $class = shift;
	return [ map { $_->[1] } @errStack ];
}

# Returns a full copy of the stack including calling classes
sub errFullStack {
	my $class = shift;
	return [ map { [ $_->[0], $_->[1] ] } @errStack ];
}

# Returns a formatted error string
sub errstr {
	my $class = shift;
	return join ': ', @{$class->errStack};
}

# Additional preformatted error strings
sub errstrConsole {
	my $class = shift;
	return join "\n", @{$class->errStack};
}
sub errstrHTML {
	my $class = shift;
	return join "<br>\n", @{$class->errStack};
}

# Allow the error to be "caught", resetting the stack
sub catchError {
	my $class = shift;
	$caught = 1;
	return $class->errstr;
}





#####################################################################
# Subroutine call tracing

sub calltrace {
	my $counter = 0;
	my @callstack = ();
	while( $counter < 50 ) {   # Infinite loop catching
		my @callitem = caller($counter++);
		if ( scalar @callitem ) {
			# Don't show call trace related subs
			next if $callitem[3] =~ /^AppLib::Error::calltrace/;

			push @callstack, {
				'package' => $callitem[0],
				'filename' => $callitem[1],
				'line' => $callitem[2],
				'subroutine' => $callitem[3],
				};
		} else {
			last;
		}
	}

	# Return the callstack
	return \@callstack;
}

# Formatted versions
sub calltraceHTML {
	my $class = shift;
	my $callstack = $class->calltrace;

	# Format and return
	my $content = join "\n", map { "<tr>"
		. "<td bgcolor='#FFFFFF'>$_->{subroutine}</td>"
		. "<td bgcolor='#FFFFFF'>$_->{filename}</td>"
		. "<td bgcolor='#FFFFFF'>$_->{line}</td>"
		} @$callstack;

	return qq~<table border="0" cellspacing="0" cellpadding="1">
		<tr bgcolor="#000000">
		<td>
		<table border="0" cellspacing="1" cellpadding="3">
		<tr bgcolor="#FFFFFF"><th colspan=3>Stack Trace</th></tr>
		<tr bgcolor="#FFFFFF"><th>Sub</th><th>File</th><th>Line</th></tr>
		$content
		</table>
		</td>
		</tr>
		</table>
		~;
}

sub calltraceConsole {
	my $class = shift;
	my $callstack = $class->calltrace;

	# Format and return
	return join "\n", map { "Sub $_->{subroutine} in file $_->{filename} on line $_->{line}" } @$callstack;
}

1;

__END__

# Copyright (C) 2000-2003 Adam Kennedy ( software.applib@ali.as )
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
# Should you wish to utilise this software under a different licence,
# please contact the author.

