package PPI::Token::Attribute;

# Attributes are a relatively recent addition in perl terms.
# Given C< sub foo : bar(something) {} >, bar(something) is the attribute

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.828';
}

sub _on_char {
	my $class = shift;
	my $t = shift;
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Unless this is a '(', we are finished.
	unless ( $char eq '(' ) {
		# Finalise and recheck
		return $t->_finalize_token->_on_char( $t );
	}

	# This is a bar(...) style attribute.
	# We are currently on the ( so scan in until the end.
	# We finish on the character AFTER our end
	my $string = $class->_scan_for_end( $t );
	if ( ref $string ) {
		# EOF
		$t->{token}->{content} .= $$string;
		$t->_finalize_token;
		return '';
	}

	# Found the end of the attribute
	$t->{token}->{content} .= $string;
	$t->{token}->{_attribute} = 1;
	$t->_finalize_token->_on_char( $t );
}

# Scan for a close braced, and take into account both escaping,
# and open close bracket pairs in the string. When complete, the
# method leaves the line cursor on the LAST character found.
sub _scan_for_end {
	my $t = $_[1];

	# Loop as long as we can get new lines
	my $string = '';
	my $depth = 0;
	while ( exists $t->{line} ) {
		# Get the search area
		$_ = $t->{line_cursor}
			? substr( $t->{line}, $t->{line_cursor} )
			: $t->{line};

		# Look for a match
		unless ( /^(.*?(?:\(|\)))/ ) {
			# Load in the next line
			$string .= $_;
			return undef unless defined $t->_fill_line;
			$t->{line_cursor} = 0;
			next;
		}

		# Add to the string
		$string .= $1;
		$t->{line_cursor} += length $1;

		# Alter the depth and continue if we arn't at the end
		$depth += ($1 =~ /\($/) ? 1 : -1 and next;

		# Found the end
		return $string;
	}

	# Returning the string as a reference indicates EOF
	\$string;
}

# Returns the attribute identifier
sub identifier {
	my $self = shift;
	$self->{content} =~ /^(.+?)\(/ ? $1 : $self->{content};
}

# Returns the attribute parameters, or undef if it has none
sub parameters {
	my $self = shift;
	$self->{content} =~ /\((.+)\)$/ ? $1 : undef;
}

1;
