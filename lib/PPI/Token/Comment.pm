package PPI::Token::Comment;

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.844';
}

sub significant { 0 }

# Most stuff goes through _commit.
# This is such a rare case, do char at a time to keep the code small
sub _on_char {
	my $t = $_[1];

	# Make sure not to include the trailing newline
	if ( substr( $t->{line}, $t->{line_cursor}, 1 ) eq "\n" ) {
		return $t->_finalize_token->_on_char( $t );
	}

	1;
}

sub _commit {
	my $t = $_[1];

	# Get the rest of the line
	$_ = substr( $t->{line}, $t->{line_cursor} );
	if ( chomp ) { # Include the newline separately
		# Add the current token, and the newline
		$t->_new_token('Comment', $_);
		$t->_new_token('Whitespace', "\n");
	} else {
		# Add this token only
		$t->_new_token('Comment', $_);
	}

	# Advance the line cursor to the end
	$t->{line_cursor} = $t->{line_length} - 1;

	0;
}

# Comments end at the end of the line
sub _on_line_end {
	$_[1]->_finalize_token if $_[1]->{token};
	1;
}

# Is this comment an entire line?
sub line {
	# Entire line comments have a newline at the end
	$_[0]->{content} =~ /\n$/ ? 1 : 0;
}

1;
