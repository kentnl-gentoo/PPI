package PPI::Token::Quote;

# The PPI::Token::Quote package is designed hold functionality
# for processing quotes and quote like operators, including regex's.
# These have special requirements in parsing.
#
# The PPI::Token::Quote package itself provides various parsing
# methods, which the PPI::Token::Quote::* and
# PPI::Token::Regex::* can inherit from. In this sense, it serves
# as a base class.
#
# This file also contains the token classes for all the quotes, and
# quote like operators.
#
# To use these, you should initialize them as normal 'Class->new',
# and then call the 'fill' method, which will cause the specialised
# parser to parse the quote to it's end point.
#
# If ->fill returns true, finailise the token.

use strict;
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.823';
}





# Hook for the _on_char token call
sub _on_char {
	my $class = shift;
	my $t = $_[0]->{token} ? shift : return undef;

	# Call the fill method to process the quote
	my $rv = $t->{token}->_fill( $t );
	return undef unless defined $rv;

	# Finalize the token and return 0 to tell the tokenizer
	# to go to the next character.
	$t->_finalize_token;

	0;
}





#####################################################################
# Optimised character processors, used for quotes
# and quote like stuff, and accessible to the child classes

# An outright scan, raw and fast.
# Searches for a particular character, loading in new
# lines as needed.
# When called, we start at the current position.
# When leaving, the position should be set to the position
# of the character, NOT the one after it.
sub _scan_for_character {
	my $class = shift;
	my $t = shift;
	my $char = (length $_[0] == 1) ? quotemeta shift : return undef;

	# Create the search regex
	my $search = qr/^(.*?$char)/;

	my $string = '';
	while ( exists $t->{line} ) {
		# Get the search area for the current line
		$_ = $t->{line_cursor}
			? substr( $t->{line}, $t->{line_cursor} )
			: $t->{line};

		# Can we find a match on this line
		if ( /$search/ ) {
			# Found the character on this line
			$t->{line_cursor} += length($1) - 1;
			return $string . $1;
		}

		# Load in the next line
		$string .= $_;
		return undef unless defined $t->_fill_line;
		$t->{line_cursor} = 0;
	}

	# Returning the string as a reference indicates EOF
	\$string;
}

# Scan for a character, but not if it is escaped
sub _scan_for_unescaped_character {
	my $class = shift;
	my $t = shift;
	my $char = (length $_[0] == 1) ? quotemeta shift : return undef;

	# Create the search regex.
	# Same as above but with a negative look-behind assertion.
	my $search = qr/^(.*?(?<!\\)(?:\\\\)*$char)/;

	my $string = '';
	while ( exists $t->{line} ) {
		# Get the search area for the current line
		$_ = $t->{line_cursor}
			? substr( $t->{line}, $t->{line_cursor} )
			: $t->{line};

		# Can we find a match on this line
		if ( /$search/ ) {
			# Found the character on this line
			$t->{line_cursor} += length($1) - 1;
			return $string . $1;
		}

		# Load in the next line
		$string .= $_;
		return undef unless defined $t->_fill_line;
		$t->{line_cursor} = 0;
	}

	# Returning the string as a reference indicates EOF
	\$string;
}

# Scan for a close braced, and take into account both escaping,
# and open close bracket pairs in the string. When complete, the
# method leaves the line cursor on the LAST character found.
sub _scan_for_brace_character {
	my $class = shift;
	my $t = shift;
	my $close_brace = $_[0] =~ /^(?:\>|\)|\}|\])$/ ? shift : return undef;
	my $open_brace = $close_brace;
	$open_brace =~ tr/\>\)\}\]/\<\(\{\[/;

	# Create the search string
	$close_brace = quotemeta $close_brace;
	$open_brace = quotemeta $open_brace;
	my $search = qr/^(.*?(?<!\\)(?:\\\\)*(?:$open_brace|$close_brace))/;

	# Loop as long as we can get new lines
	my $string = '';
	my $depth = 1;
	while ( exists $t->{line} ) {
		# Get the search area
		$_ = $t->{line_cursor}
			? substr( $t->{line}, $t->{line_cursor} )
			: $t->{line};

		# Look for a match
		unless ( /$search/ ) {
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
		$depth += ($1 =~ /$open_brace$/) ? 1 : -1 and next;

		# Rewind the cursor by one character ( cludgy hack )
		$t->{line_cursor} -= 1;
		return $string;
	}

	# Returning the string as a reference indicates EOF
	\$string;
}

# Find all spaces and comments, up to, but not including
# the first non-whitespace character.
#
# Although it doesn't return it, it leaves the cursor
# on the character following the gap
sub _scan_quote_like_operator_gap {
	my $t = $_[1];

	my $string = '';
	while ( exists $t->{line} ) {
		# Get the search area for the current line
		$_ = $t->{line_cursor} 
			? substr( $t->{line}, $t->{line_cursor} ) 
			: $t->{line};

		# Since this regex can match zero characters, it should always match
		/^(\s*(?:\#.*)?)/ or return undef;
		
		# Add the chars found to the string
		$string .= $1;
		
		# Did we match the entire line?
		unless ( length $1 == length $_ ) {
			# Partial line match, which means we are at
			# the end of the gap. Fix the cursor and return
			# the string.
			$t->{line_cursor} += length $1;
			return $string;
		}
		
		# Load in the next line.
		# If we reach the EOF, $t->{line} gets deleted,
		# which is caught by the while.
		return undef unless defined $t->_fill_line;
			
		# Set the cursor to the first character
		$t->{line_cursor} = 0;
	}

	# Returning the string as a reference indicates EOF
	\$string;
}

1;
