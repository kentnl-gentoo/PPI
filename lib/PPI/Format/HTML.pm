package PPI::Format::HTML;

# PPI::Format::HTML is a package to format Perl source code for HTML viewing.

use strict;
use UNIVERSAL 'isa';
use PPI::Tokenizer ();
use base qw{Exporter PPI::Base};

use vars qw{$VERSION @EXPORT_OK};
use vars qw{@keywords @functions $colormap};
BEGIN {
	$VERSION = '0.820';

	# Some methods will also work as exportable functions
	@EXPORT_OK = qw{syntax_string syntax_page debug_string debug_page};

	# Reserved words and symbols
	@keywords = qw{
		-A -B -C -M -O -R -S -T -W -X
		-b -c -d -e -f -g -k -l -o -p -r -s -t -u -w -x -z
		__DATA__ __END__ __FILE__ __LINE__ __PACKAGE__ __WARN__ __DIE__
		bootstrap continue do else elsif for foreach goto if last local
		my next no our package redo return require sub until unless use
		while BEGIN INIT END
		};
	@functions = qw{
		accept alarm atan2
		bind binmode bless
		caller chdir chmod chomp chop chown chr chroot close closedir connect
		cos crypt
		dbmclose dbmopen defined delete die dump
		each endgrent endhostent endnetent endprotoent endpwent endservent eof
		eval exec exit exp exists
		fcntl fileno flock fork formline format
		getc getgrent getgrgid getgrname gethostbyaddr gethostbyname
		gethostent getlogin getnetbyaddr getnetbyname getnetent getpeername
		getpgrp getppid getpriority getprotobyname getprotobynumber getprotoent
		getpwent getpwnam getpwuid getservbyname getservbyport getservent
		getsockname getsockopt glob gmtime grep
		hex
		index int ioctl
		join
		keys kill
		lc lcfirst length link listen localtime log lstat
		map mkdir msgctl msgget msgrcv msgsnd
		oct open opendir ord
		pack pipe pop pos print printf push
		quotemeta
		rand read readdir readline readlink recv ref rename reset reverse
		rewinddir rindex rmdir
		scalar seek seekdir select semctl semgett semop send setgrent
		sethostent setnetent setpgrp setpriority setprotoent setpwent
		setservent setsockopt shift shmctl shmget shmread shmwrite shutdown
		sin sleep socket socketpair sort splice split sprintf sqrt srand stat
		study substr symlink syscall sysopen sysread system syswrite
		tell telldir tie tied time times truncate
		uc ucfirst umask undef unlink unpack unshift utime
		values vec
		wait waitpid wantarray warn write
		};
	$colormap = {};
	foreach ( @keywords )  { $colormap->{$_} = 'blue' }
	foreach ( @functions ) { $colormap->{$_} = 'red' }
}





#####################################################################
# Core methods

sub serialize {
	my $class = shift;
	my $Tokenizer = isa( $_[0], 'PPI::Tokenizer' ) ? shift
		: return $class->_error( "Can only serialize from a PPI::Tokenizer object" );
	my $style = shift || 'plain';
	my $options = shift || {};

	# Check the arguments
	unless ( $style eq 'syntax' or $style eq 'debug' or $style eq 'plain' ) {
		return $class->_error( "Invalid html format style '$style'" );
	}

	# Hand off to the appropriate formatter
	if ( $style eq 'syntax' ) {
		return $class->_serialize_syntax( $Tokenizer, $options );
	} elsif ( $style eq 'debug' ) {
		return $class->_serialize_debug( $Tokenizer, $options );
	} elsif ( $style eq 'plain' ) {
		return $class->_serialize_plain( $Tokenizer, $options );
	}

	# } else {
		# Look for a child class
		#my $styleclass = "PPI::Format::HTML::$style";
		#if ( Class::Autouse->class_exists( $styleclass ) ) {
			# Call the serialize_document function for that class
		#	Class::Autouse->load( $styleclass )
		#		or return $class->_error( "Error loading class $styleclass to format Document" );
		#	return $styleclass->_serialize_document_syntax( $Tokenizer, $options );
		#} else {
		#	return $class->_error( "Error looking for style '$style'. The class $styleclass foes not exist" );
		#}
	#}
}

sub _serialize_syntax {
	my $class = shift;
	my $Tokenizer = isa( $_[0], 'PPI::Tokenizer' ) ? shift : return undef;
	my $options = isa( $_[0], 'HASH' ) ? shift : {};
	my ($token, $html, $color) = ();
	my $delayed_whitespace = '';

	# Reset the cursor, and loop through
	my $current = '';
	while ( my $token = $Tokenizer->get_token ) {
		if ( isa( $token, 'PPI::Token::Whitespace' ) ) {
			if ( $token->{content} !~ /^\s*$/ ) {
				# Something in whitespace that shouldn't be
				$color = 'pink';
			} else {
				# It's a normal whitespace token
				$delayed_whitespace .= $token->{content};
				next;
			}
		}

		# Get the color for the token
		$color = $class->_get_token_color( $token );

		if ( $color ne $current ) {
			# End the previous color
			$html .= "</font>" if $current;
		}

		# Add buffered whitespace
		if ( $delayed_whitespace ) {
			$html .= escape_whitespace( $delayed_whitespace ) ;
			$delayed_whitespace = '';
		}

		if ( $color ne $current ) {
			$color = '' if $color eq 'black';

			# Start the new color
			$html .= "<font color='$color'>" if $color;
			$current = $color;
		}

		# If the token has the hidden {_href} property, link it
		my $content = escape_html( $token->{content} );
		if ( exists $token->{_href} ) {
			$content = "<a href=\"$token->{_href}\">$content</a>";
		}

		$html .= $content;
		$current = $color;
	}

	# Terminate any remaining bits
	$html .= "</font>" if $current;
	$html .= escape_whitespace( $delayed_whitespace );

	# Optionally add line numbers
	if ( $options->{linenumbers} ) {
		my $line = 0;
		my $lines = scalar( my @newlines = $html =~ /\n/g ) + 1;
		my $lines_width = length $lines;
		$html =~ s!(^|\n)!
			$1
			. "<font color='#666666'>"
			. $class->line_label( ++$line, $lines_width )
			. "</font> "
			!ge;
	}

	if ( PPI::Tokenizer->errstr ) {
		$html .= "\n<!-- \$errstr = '" 
			. PPI::Tokenizer->errstr
			. "' -->\n";
	}

	$html;
}

# Determine the appropriate color for a token.
# This is the method you should overload to make a new html syntax highlighter
sub _get_token_color {
	shift;
	my $Token = isa( $_[0], 'PPI::Token' ) ? shift : return '';
	my $class = ref $Token;
	my $content = $Token->{content};
	if ( $class eq 'PPI::Token::Keyword' ) {
		return 'blue';
	} elsif ( $class eq 'PPI::Token::Bareword' ) {
		return $colormap->{$content} if $colormap->{$content};
	} elsif ( $class eq 'PPI::Token::Comment' ) {
		return '#008080';
	} elsif ( $class eq 'PPI::Token::Pod' ) {
		return '#008080';
	} elsif ( $class eq 'PPI::Token::RawInput::Operator' ) {
		return '#FF9900';
	} elsif ( $class eq 'PPI::Token::RawInput::Terminator' ) {
		return '#999999';
	} elsif ( $class eq 'PPI::Token::RawInput::String' ) {
		return '#999999';
	} elsif ( $class =~ /^PPI::Token::Regex::/ or $class eq 'PPI::Token::Quote::Regex' ) {
		return '#9900AA';
	} elsif ( $class eq 'PPI::Token::Attribute' ) {
		return '#9900AA';
	} elsif ( $class =~ /^PPI::Token::Quote::/ ) {
		return '#999999';
	} elsif ( $class eq 'PPI::Token::Whitespace' ) {
		# There should be no visible Whitespace content
		return '#FF00FF' if $content =~ /\S/;
		return ''; # Transparent
	} elsif ( $class eq 'PPI::Token::Magic' ) {
		return '#0099FF';
	} elsif ( $class eq 'PPI::Token::Operator' ) {
		return '#FF9900';
	} elsif ( $class eq 'PPI::Token::Number' ) {
		return '#990000';
	} elsif ( $class eq 'PPI::Token::Cast' ) {
		return '#339999';
	} else {
		return 'black';
	}
}

sub _serialize_debug {
	my $class = shift;
	my $Tokenizer = isa( $_[0], 'PPI::Tokenizer' ) ? shift : return undef;
	my $options = isa( $_[0], 'HASH' ) ? shift : {};
	my ($html) = ();

	# Reset the cursor and loop
	my $line_count = 0;
	my $bgcolor = '#EEEEEE';
	foreach my $Token ( @{$Tokenizer->all_tokens} ) {
		$class = ref($Token) eq 'PPI::Token::Comment'
			? $Token->line ? 'Comment Line' : 'Comment'
			: ref($Token);
		$bgcolor = $bgcolor eq '#FFFFFF' ? '#EEEEEE' : '#FFFFFF';
		$html .= "<tr bgcolor='$bgcolor'><td align=right valign=top><b>"
			. ++$line_count
			. "</b></td>"
			. "<td valign=top nowrap>$class</td>"
			. "<td valign=top>" . escape_debug_html($Token->{content}) . "</td></tr>\n";
	}

	qq~
		<table border="0" cellspacing="0" cellpadding="1"><tr><td bgcolor="#000000">
      		<table border=0 cellspacing=1 cellpadding=2>
        	<tr bgcolor="#CCCCCC"><th>Token</th><th>Class</th><th>Content</th></tr>
		$html
		</table>
		</td></tr></table>
		~;
}

sub _serialize_plain {
	my $class = shift;
	my $Tokenizer = isa( $_[0], 'PPI::Tokenizer' ) ? shift : return undef;
	my $options = isa( $_[0], 'HASH' ) ? shift : {};

	# Get the content
	my $plain = '';
	while ( my $token = $Tokenizer->get_token ) {
		$plain .= $token->{content};
	}
	$plain = escape_html( $plain );

	# Optionally add line numbers
	if ( $options->{linenumbers} ) {
		my $line = 0;
		my $lines = scalar( my @newlines = $plain =~ /\n/g ) + 1;
		my $lines_width = length $lines;
		$plain =~ s!(^|\n)!
			$1
			. $class->line_label( ++$line, $lines_width )
			. " "
			!ge;
	}

	$plain;
}

sub escape_html {
	$_ = shift;
	s/\&/&amp;/g;
	s/\</&lt;/g;
	s/\>/&gt;/g;
	s/\n/<br>\n/g;
	s/\t/        /g;
	s/  /&nbsp;&nbsp;/g;
	$_;
}

sub escape_whitespace {
	$_ = shift;
	s/\n/<br>\n/g;
	s/\t/        /g;
	s/  /&nbsp;&nbsp;/g;
	$_;
}

sub escape_debug_html {
	$_ = shift;
	s/\&/&amp;/g;
	s/\</&lt;/g;
	s/\>/&gt;/g;
	s!\n!<b>\\n</b>!g;
	s/\t/        /g;
	s/ /&nbsp;/g;
	s!(</b>)(.)!$1<br>$2!g;
	$_;
}

# Wrap source code in a minamilist page
sub wrap_page {
	my $class = shift;
	my $style = shift;
	my $content = shift;

	return <<"END_HTML" if $style eq 'syntax';
<html>
<head>
  <title>Formatted Perl Source Code</title>
</head>
<body bgcolor="#FFFFFF" text="#000000">
<font face="Courier" size=-1>
$content
</font>
</body>
</html>
END_HTML

	return <<"END_HTML" if $style eq 'debug';
<html>
<head>
  <title>Debug Perl Source Code</title>
  <style type="text/css">
  <!--
    body {  font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px}
    td {  font-size: 12px; font-family: Verdana, Arial, Helvetica, sans-serif}
    th {  font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 12px}
  -->
</style>
</head>
<body bgcolor="#FFFFFF" text="#000000">
$content
</body>
</html>
END_HTML

	return <<"END_HTML";
<head>
  <title>Perl Source Code</title>
</head>
<body bgcolor="#FFFFFF" text="#000000">
<font face="Courier" size=-1>
$content
</font>
</body>
</html>
END_HTML
}

sub line_label {
	my $class = shift;
	my $line = shift;
	my $width = shift;
	my $label = sprintf( '%'.$width.'d:', $line );
	$label =~ s/ /&nbsp;/g;
	$label;
}





#####################################################################
# Interface methods

# These will work as both exportable functions, and methods

sub syntax_string {
	shift if isa($_[0], __PACKAGE__);
	my $Tokenizer = PPI::Tokenizer->new( shift ) or return undef;
	my $options = ref $_[0] eq 'HASH' ? shift : {};
	return __PACKAGE__->serialize( $Tokenizer, 'syntax', $options );
}

sub syntax_page {
	shift if isa($_[0], __PACKAGE__);
	my $html = __PACKAGE__->syntax_string( @_ ) or return undef;
	PPI::Format::HTML->wrap_page( 'syntax', $html );
}

sub debug_string {
	shift if isa($_[0], __PACKAGE__);
	my $Tokenizer = PPI::Tokenizer->new( shift ) or return undef;
	my $options = ref $_[0] eq 'HASH' ? shift : {};
	__PACKAGE__->serialize( $Tokenizer, 'debug', $options );
}

sub debug_page {
	shift if isa($_[0], __PACKAGE__);
	my $html = __PACKAGE__->debug_string( @_ ) or return undef;
	PPI::Format::HTML->wrap_page( 'debug', $html );
}

1;
