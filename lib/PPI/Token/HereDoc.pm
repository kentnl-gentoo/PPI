package PPI::Token::HereDoc;

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.840';
}





#####################################################################
# Tokenizer Methods

# Parse in the entire here-doc in one call
sub _on_char {
	my $t    = $_[1];

	# We are currently located on the first char after the <<
	# Get the rest of the line
	$_ = substr( $t->{line}, $t->{line_cursor} );
	/^(\s*(?:"\w+"|'\w+'|`\w+\`|\w+))/ or return undef;

	# Add the rest of the token, work out what type it is,
	# and suck in the content until the end.
	$t->{token}->{content} .= $1;
	$t->{line_cursor} += length $1;

	# Find the terminator
	unless ( $t->{token}->{content} =~ /\w+/ ) {
		return undef;
	}
	$t->{token}->{_terminator} = $1;

	# What type of here-doc
	my $type = ($t->{token}->{content} =~ /('|"|`)/) || '"';
	$t->{token}->{_type} = {
		"'" => 'single',
		'"' => 'double',
		'`' => 'execute',
		};

	# Suck in the HEREDOC
}

1;
