package PPI::Token::_QuoteEngine::Full;

# Full quote engine

use strict;
use base 'PPI::Token::_QuoteEngine';
use Clone ();

use vars qw{$VERSION %quotes %sections};
BEGIN {
	$VERSION = '0.995';

	# Prototypes for the different braced sections
	%sections = (
		'(' => { type => '()', _close => ')' },
		'<' => { type => '<>', _close => '>' },
		'[' => { type => '[]', _close => ']' },
		'{' => { type => '{}', _close => '}' },
		);

	# For each quote type, the extra fields that should be set.
	# This should give us faster initialization.
	%quotes = (
		'q'   => { operator => 'q',   braced => undef, seperator => undef, _sections => 1 },
		'qq'  => { operator => 'qq',  braced => undef, seperator => undef, _sections => 1 },
		'qx'  => { operator => 'qx',  braced => undef, seperator => undef, _sections => 1 },
		'qw'  => { operator => 'qw',  braced => undef, seperator => undef, _sections => 1 },
		'qr'  => { operator => 'qr',  braced => undef, seperator => undef, _sections => 1, modifiers => 1 },
		'm'   => { operator => 'm',   braced => undef, seperator => undef, _sections => 1, modifiers => 1 },
		's'   => { operator => 's',   braced => undef, seperator => undef, _sections => 2, modifiers => 1 },
		'tr'  => { operator => 'tr',  braced => undef, seperator => undef, _sections => 2, modifiers => 1 },

		# Y is the little used varient of tr
		'y'   => { operator => 'y',   braced => undef, seperator => undef, _sections => 2, modifiers => 1 },

		'/'   => { operator => undef, braced => 0,     seperator => '/',   _sections => 1, modifiers => 1 },

		# Angle brackets quotes mean "readline(*FILEHANDLE)"
		'<'   => { operator => undef, braced => 1,     seperator => undef, _sections => 1, },

		# The final ( and kind of depreciated ) "first match only" one is not
		# used yet, since I'm not sure on the context differences between
		# this and the trinary operator, but its here for completeness.
		'?'   => { operator => undef, braced => 0,     seperator => '?',   _sections => 1, modifieds => 1 },
		);
}



=pod

=begin testing new 4

# Verify that Token::Quote, Token::QuoteLike and Token::Regexp
# do not have ->new functions
use_ok( 'Class::Inspector' );
foreach ( qw{Token::Quote Token::QuoteLike Token::Regexp} ) {
	my $functions = Class::Inspector->functions($_);
	is( scalar(grep { $_ eq 'new' } @$functions), 0,
		"$_ does not have a new function" );
}

=end testing

=cut

sub new {
	my $class = shift;
	my $init  = defined $_[0] ? shift : return undef;

	# Create the token
	### This manual SUPER'ing ONLY works because none of
	### Token::Quote, Token::QuoteLike and Token::Regexp
	### implement a new function of their own.
	my $self = PPI::Token::new( $class, $init ) or return undef;

	# Do we have a prototype for the intializer? If so, add the extra fields
	my $options = $quotes{$init} or return $self->_error(
		"Unknown quote type '$init'"
		);
	foreach ( keys %$options ) {
		$self->{$_} = $options->{$_};
	}

	# Set up the modifiers hash if needed
	$self->{modifiers} = {} if $self->{modifiers};

	# Handle the special < base
	if ( $init eq '<' ) {
		$self->{sections}->[0] = Clone::clone( $sections{'<'} );
	}

	$self;
}

sub _fill {
	my $class = shift;
	my $t     = shift;
	my $self  = $t->{token} or return undef;

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
			$self->{braced}        = 1;
			$self->{sections}->[0] = Clone::clone($section);
		} else {
			$self->{braced}    = 0;
			$self->{seperator} = $_;
		}
	}

	# Parse different based on whether we are normal or braced
	$_ = $self->{braced}
		? $self->_fill_braced($t)
		: $self->_fill_normal($t)
		or return $_;

	# Return now unless it has modifiers ( i.e. s/foo//eieio )
	return 1 unless $self->{modifiers};

	# Check for modifiers
	my $char;
	my $len = 0;
	while ( ($char = substr( $t->{line}, $t->{line_cursor} + 1, 1 )) =~ /\w/ ) {
		$char eq '_' and return $self->_error(
			"Syntax error. Cannot use underscore '_' as regex modifier"
			);
		$len++;
		$self->{content} .= $char;
		$self->{modifiers}->{lc $char} = 1;
		$t->{line_cursor}++;
	}
}

# Handle the content parsing path for normally seperated
sub _fill_normal {
	my $self = shift;
	my $t    = shift;

	# Get the content up to the next seperator
	my $string = $self->_scan_for_unescaped_character( $t, $self->{seperator} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	}

	# Complete the properties of the first section
	$self->{sections}->[0] = {
		position => length $self->{content},
		size     => length($string) - 1
		};
	$self->{content} .= $string;

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

	# Complete the properties of the second section
	$self->{sections}->[1] = {
		position => length($self->{content}),
		size     => length($string) - 1
		};
	$self->{content} .= $string;

	1;
}

# Handle content parsing for matching crace seperated
sub _fill_braced {
	my $self = shift;
	my $t    = shift;

	# Get the content up to the close character
	my $section = $self->{sections}->[0];
	$DB::single = 1 unless $section->{_close};
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
	$section->{size}     = length($_) - 1;
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
	$section->{size}     = length($_) - 1;
	delete $section->{_close};

	1;
}




#####################################################################
# Additional methods to find out about the quote

# In a scalar context, get the number of sections
# In an array context, get the section information
sub _sections { wantarray ? @{$_[0]->{sections}} : scalar @{$_[0]->{sections}} }

1;

=pod

=head1 SUPPORT

See the L<support section|PPI/SUPPORT> in the main module

=head1 AUTHOR

Adam Kennedy, L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
