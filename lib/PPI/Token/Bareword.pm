package PPI::Token::Bareword;

use strict;
use base 'PPI::Token';

use vars qw{$VERSION %quotelike};
BEGIN {
	$VERSION = '0.825';

	%quotelike = (
		'q'  => 'Quote::OperatorSingle',
		'qq' => 'Quote::OperatorDouble',
		'qx' => 'Quote::OperatorExecute',
		'qw' => 'Quote::Words',
		'qr' => 'Quote::Regex',
		'm'  => 'Regex::Match',
		's'  => 'Regex::Replace',
		'tr' => 'Regex::Transform',
		'y'  => 'Regex::Transform',
		);
}

sub _on_char {
	my $class = shift;
	my $t     = shift;

	# Suck in till the end of the bareword
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(\w+(?:(?:\'|::)[^\W\d]\w*)*(?:::)?)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# We might be a subroutine attribute.
	my $tokens = $t->_previous_significant_tokens(1);
	if ( $tokens and $tokens->[0]->{_attribute} ) {
		$t->_set_token_class( 'Attribute' );
		return $t->{class}->_commit( $t );
	}

	# Check for a quote like operator
	my $word = $t->{token}->{content};
	if ( $quotelike{$word} ) {
		# Turn it into the appropriate class
		$t->_set_token_class( $quotelike{$word} );
		return $t->{class}->_on_char( $t );
	}

	# Or one of the word operators
	if ( $PPI::Token::Operator::operator{$word} ) {
	 	$t->_set_token_class( 'Operator' );
	 	return $t->_finalize_token->_on_char( $t );
	}

	# Unless this is a simple identifier, at this point
	# it has to be a normal bareword
	if ( $word =~ /\:/ ) {
		return $t->_finalize_token->_on_char( $t );
	}

	# If the NEXT character in the line is a colon, this
	# is a label.
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );
	if ( $char eq ':' ) {
		$t->{token}->{content} .= ':';
		$t->{line_cursor}++;
		$t->_set_token_class( 'Label' );

	# If not a label, '_' on it's own is the magic filehandle
	} elsif ( $word eq '_' ) {
		$t->_set_token_class( 'Magic' );

	}

	# Finalise and process the character again
	$t->_finalize_token->_on_char( $t );
}

# We are committed to being a bareword.
# Or so we would like to believe.
sub _commit {
	my $t = $_[1];

	# Our current position is the first character of the bareword.
	# Capture the bareword.
	my $line = substr( $t->{line}, $t->{line_cursor} );
	unless ( $line =~ /^([^\W\d]\w*(?:(?:\'|::)[^\W\d]\w*)*(?:::)?)/ ) {
		# Programmer error
		$DB::single = 1;
		die "Fatal error... regex failed to match when expected";
	}

	# Advance the position one after the end of the bareword
	my $word = $1;
	$t->{line_cursor} += length $word;

	# We might be a subroutine attribute.
	my $tokens = $t->_previous_significant_tokens(1);
	if ( $tokens and $tokens->[0]->{_attribute} ) {
		$t->_new_token( 'Attribute', $word );
		return ($t->{line_cursor} >= $t->{line_length}) ? 0
			: $t->{class}->_on_char($t);
	}

	# Check for the special case of the quote-like operator
	if ( $quotelike{$word} ) {
		$t->_new_token( $quotelike{$word}, $word );
		return ($t->{line_cursor} >= $t->{line_length}) ? 0
			: $t->{class}->_on_char( $t );
	}

	# Check for the end of the file
	if ( $word eq '__END__' ) {
		# Create the token for the __END__ itself
		$t->_new_token( 'Bareword', $1 );
		$t->_finalize_token;

		# Change into the End zone
		$t->{zone} = 'PPI::Token::End';

		# Add the rest of the line as the End token
		$line = substr( $t->{line}, $t->{line_cursor} );
		$t->{line_cursor} = length $t->{line};
		$t->_new_token( 'End', $line );

		return 0;
	}

	# Check for the data section
	if ( $word eq '__DATA__' ) {
		# Create the token for the __DATA__ itself
		$t->_new_token( 'Bareword', "$1" );
		$t->_finalize_token;

		# Change into the Data zone
		$t->{zone} = 'PPI::Token::Data';

		# Add the rest of the line as the Data token
		$line = substr( $t->{line}, $t->{line_cursor} );
		$t->{line_cursor} = length $t->{line};
		$t->_new_token( 'Data', $line );

		return 0;
	}

	my $token_class;
	if ( $PPI::Token::Operator::operator{$word} ) {
		# Word operator
		$token_class = 'Operator';

	} elsif ( $word =~ /\:/ ) {
		# Since it's not a simple identifier...
		$token_class = 'Bareword';

	} else {
		# Now, if the next character is a :, it's a label
		my $char = substr( $t->{line}, $t->{line_cursor}, 1 );
		if ( $char eq ':' ) {
			$word .= ':';
			$t->{line_cursor}++;
			$token_class = 'Label';
		} elsif ( $word eq '_' ) {
			$token_class = 'Magic';
		} else {
			$token_class = 'Bareword';
		}
	}

	# Create the new token and finalise
	$t->_new_token( $token_class, $word );
	if ( $t->{line_cursor} >= $t->{line_length} ) {
		# End of the line
		$t->_finalize_token;
		return 0;
	}
	$t->_finalize_token->_on_char($t);
}

1;
