package PPI::Token::Number;

# The perl numeric token are
#    $n = 1234;       # decimal integer
#    $n = 0b1110011;  # binary integer
#    $n = 01234;      # octal integer
#    $n = 0x1234;     # hexadecimal integer
#    $n = 12.34e-56;  # exponential notation ( currently not working )

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.830';
}

sub _on_char {
	my $class = shift;
	my $t     = shift;
	my $char  = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Allow underscores straight through
	return 1 if $char eq '_';

	# Handle the conversion from an unknown to known type.
	# The regex covers "potential" hex/bin/octal number.
	my $token = $t->{token};
	if ( $token->{content} =~ /^-?0_*$/ ) {
		# This could be special
		if ( $char eq 'x' ) {
			$token->{_subtype} = 'hex';
			return 1;
		} elsif ( $char eq 'b' ) {
			$token->{_subtype} = 'binary';
			return 1;
		} elsif ( $char =~ /\d/ ) {
			$token->{_subtype} = 'octal';
			return 1;
		} elsif ( $char eq '.' ) {
			return 1;
		} else {
			# End of the number... it's just 0
			return $t->_finalize_token->_on_char( $t );
		}
	}

	if ( ! $token->{_subtype} or $token->{_subtype} eq 'base256' ) {
		# Handle the easy case, integer or real.
		return 1 if $char =~ /\d/o;

		if ( $char eq '.' ) {
			if ( $token->{content} =~ /\.$/ ) {
				# We have a .., which is an operator.
				# Take the . off the end of the token..
				# and finish it, then make the .. operator.
				chop $t->{token}->{content};
				$t->_new_token( 'Operator', '..' ) or return undef;
				return 0;
			} else {
				# Will this be the first .?
				if ( $token->{content} =~ /\./ ) {
					return 1;
				} else {
					# Flag as a base256.
					$token->{_subtype} = 'base256';
					return 1;
				}
			}
		}

	} elsif ( $token->{_subtype} eq 'octal' ) {
		# You cannot have 9s on octals
		if ( $char eq '9' ) {
			return $class->_error( "Illegal octal digit '9'" );
		}

		# Any other number is ok
		return 1 if $char =~ /\d/o;

	} elsif ( $token->{_subtype} eq 'hex' ) {
		return 1 if $char =~ /[\da-f]/io;

		# Error on other word chars
		if ( $char =~ /\w/ ) {
			return $class->_error( "Illegal hexidecimal character '$char'" );
		}

	} elsif ( $token->{_subtype} eq 'binary' ) {
		return 1 if $char =~ /(?:1|0)/;

		# Other bad characters
		if ( $char =~ /[\w\d]/ ) {
			return $class->_error( "Illegal binary character '$char'" );
		}

	} else {
		return $class->_error( "Unknown number type '$token->{_subtype}'" );
	}

	# Doesn't fit a special case, or is after the end of the token
	# End of token.
	$t->_finalize_token->_on_char( $t );
}

1;
