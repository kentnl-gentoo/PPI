package PPI::Token::Quote::Full;

# Full quote engine

use strict;
use base 'PPI::Token::Quote';

use vars qw{$VERSION %quotes %sections};
BEGIN {
	$VERSION = '0.826';

	# For each quote type, the extra fields that should be set.
	# This should give us faster initialization.
	%quotes = (
		'q'   => { operator => 'q',  braced => undef, seperator => undef, _sections => 1 },
		'qq'  => { operator => 'qq', braced => undef, seperator => undef, _sections => 1 },
		'qx'  => { operator => 'qx', braced => undef, seperator => undef, _sections => 1 },
		'qw'  => { operator => 'qw', braced => undef, seperator => undef, _sections => 1 },
		'qr'  => { operator => 'qr', braced => undef, seperator => undef, _sections => 1, modifiers => {} },
		'm'   => { operator => 'm',  braced => undef, seperator => undef, _sections => 1, modifiers => {} },
		's'   => { operator => 's',  braced => undef, seperator => undef, _sections => 2, modifiers => {} },
		'tr'  => { operator => 'tr', braced => undef, seperator => undef, _sections => 2, modifiers => {} },

		# Y is the little used varient of tr
		'y'   => { operator => 'y', braced => undef, seperator => undef, _sections => 2, modifiers => {} },

		'/'   => { operator => undef, braced => 0, seperator => '/', _sections => 1, modifiers => {} },

		# The final ( and kind of depreciated ) "first match only" one is not
		# used yet, since I'm not sure on the context differences between
		# this and the trinary operator, but it's here for completeness.
		'?'   => { operator => undef, braced => 0, seperator => '?', _sections => 1, modifieds => {} },
		);

	# Prototypes for the different braced sections
	%sections = (
		'(' => { type => '()', _close => ')' },
		'<' => { type => '<>', _close => '>' },
		'[' => { type => '[]', _close => ']' },
		'{' => { type => '{}', _close => '}' },
		);

}




sub new {
	my $class = shift;
	my $init = defined $_[0] ? shift : return undef;

	# Create the token
	my $self = $class->SUPER::new($init) or return undef;

	# Do we have a prototype for the intializer? If so, add the extra fields
	my $options = $quotes{$init} or return $self->_error( "Unknown quote like operator '$init'" );
	$self->{$_} = $options->{$_} foreach keys %$options;

	$self;
}

sub _fill {
	my $class = shift;
	my $t = shift;
	my $self = $t->{token} or return undef;

	# Load in the operator stuff if needed
	if ( $self->{operator} ) {
		# In an operator based quote-like, handle the gap between the
		# operator and the opening seperator.
		if ( substr( $t->{line}, $t->{line_cursor}, 1 ) =~ /\s/ ) {
			# Go past the gap
			my $gap = $self->_scan_quote_like_operator_gap( $t );
			return undef unless defined $gap;
			if ( ref $gap ) {
				# End of file
				$self->{content} .= $$gap;
				return 0;
			}
			$self->{content} .= $gap;
		}

		# The character we are now on is the seperator. Capture,
		# and advance into the first section.
		$_ = substr( $t->{line}, $t->{line_cursor}++, 1 );
		$self->{content} .= $_;

		# Determine if these are normal or braced type sections
		if ( my $section = $sections{$_} ) {
			$self->{braced} = 1;
			$self->{sections}->[0] = { %$section };
		} else {
			$self->{braced} = 0;
			$self->{seperator} = $_;
		}
	}

	# Parse different based on whether we are normal or braced
	$_ = $self->{braced}
		? $self->_fill_braced( $t ) : $self->_fill_normal( $t )
		or return $_;

	# Does the quote support modifiers ( i.e. s/foo//eieio )
	if ( $self->{modifiers} ) {
		# Check for modifiers
		my $char;
		my $len = 0;
		while ( ($char = substr( $t->{line}, $t->{line_cursor} + 1, 1 )) =~ /\w/ ) {
			if ( $char eq '_' ) {
				return $self->_error( "Syntax error. Cannot use underscore '_' as regex modifier" );
			} else {
				$len++;
				$self->{content} .= $char;
				$self->{modifiers}->{ lc $char } = 1;
				$t->{line_cursor}++;
			}
		}
	}

	1;
}

# Handle the content parsing path for normally seperated
sub _fill_normal {
	my $self = shift;
	my $t = shift;

	# Get the content up to the next seperator
	my $string = $self->_scan_for_unescaped_character( $t, $self->{seperator} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	}
	$self->{content} .= $string;

	# Complete the properties of the first section
	$self->{sections}->[0] = {
		position => length $self->{content},
		size => length($string) - 1
		};

	# We are done if there is only one section
	return 1 if $self->{_sections} == 1;

	# There are two sections.

	# Advance into the next section
	$t->{line_cursor}++;

	# Get the content up to the end seperator
	$string = $self->_scan_for_unescaped_character( $t, $self->{seperator} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	}
	$self->{content} .= $string;

	# Complete the properties of the second section
	$self->{sections}->[1] = {
		position => length $self->{content},
		size => length($string) - 1
		};

	1;
}

# Handle content parsing for matching crace seperated
sub _fill_braced {
	my $self = shift;
	my $t = shift;

	# Get the content up to the close character
	my $section = $self->{sections}->[0];
	$_ = $self->_scan_for_brace_character( $t, $section->{_close} );
	return undef unless defined $_;
	if ( ref $_ ) {
		# End of file
		$self->{content} .= $$_;
		return 0;
	}
	$self->{content} .= $_;

	# Complete the properties of the first section
	$section->{position} = length $self->{content};
	$section->{size} = length($_) - 1;
	delete $section->{_close};

	# We are done if there is only one section
	return 1 if $self->{_sections} == 1;

	# There are two sections.

	# Is there a gap between the sections.
	my $char = substr( $t->{line}, ++$t->{line_cursor}, 1 );
	if ( $char =~ /\s/ ) {
		# Go past the gap
		$_ = $self->_scan_quote_like_operator_gap( $t );
		return undef unless defined $_;
		if ( ref $_ ) {
			# End of file
			$self->{content} .= $$_;
			return 0;
		}
		$self->{content} .= $_;
		$char = substr( $t->{line}, $t->{line_cursor}, 1 );
	}

	# Check that the next character is an open selector
	if ( $section = $sections{$char} ) {
		$self->{content} .= $char;

		# Initialize the second section
		$section = $self->{sections}->[1] = { %$section };

	} else {
		# Error, it has to be a brace of some sort
		return $self->_error( "Syntax error. Second section of regex does not start with an open brace" );
	}

	# Advance into the second region
	$t->{line_cursor}++;

	# Get the content up to the close character
	$_ = $self->_scan_for_brace_character( $t, $section->{_close} );
	return undef unless defined $_;
	if ( ref $_ ) {
		# End of file
		$self->{content} .= $$_;
		return 0;
	}
	$self->{content} .= $_;

	# Complete the properties for the second section
	$section->{position} = length $self->{content};
	$section->{size} = length($_) - 1;
	delete $section->{_close};

	1;
}




#####################################################################
# Additional methods to find out about the quote

# In a scalar context, get the number of sections
# In an array context, get the section information
sub sections { wantarray ? @{$_[0]->{sections}} : scalar @{$_[0]->{sections}} }

1;
