package PPI::Tokenizer::Quote::Full;

# Full quote engine
		
use strict;
use base 'PPI::Tokenizer::Quote';

use vars qw{%quoteTypes};
BEGIN {
	# For each quote type, the extra fields that should be set.
	# This should give us faster initialization.
	%quoteTypes = (
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

		'/' => { operator => undef, braced => 0, seperator => '/', _sections => 1, modifiers => {} },

		
		# The final ( and kind depreciated ) "first match only" one is not
		# used yet, since I'm not sure on the context differences between
		# this and the trinary operator, but it's here for completeness.
		'?' => { operator => undef, braced => 0, seperator => '?', _sections => 1, modifieds => {} },
		);
}
		
sub new {
	my $class = shift;
	my $zone = shift;
	my $init = shift;
	return undef unless defined $init;
	
	# Create the token
	my $self = $class->SUPER::new($zone, $init) or return undef;
	
	# Do we have a prototype for the intializer? If so, add the extra fields
	my $options = $quoteTypes{$init} or return $self->_error( "Unknown quote like operator '$init'" );
	$self->{$_} = $options->{$_} foreach keys %$options;

	return $self;
}

use vars qw{%sectionPrototypes};
BEGIN {
	%sectionPrototypes = (
		'(' => { type => '()', _close => ')' },
		'<'	=> { type => '<>', _close => '>' },
		'[' => { type => '[]', _close => ']' },
		'{' => { type => '{}', _close => '}' },
		);
}
sub fill {
	my $class = shift;
	my $t = shift;
	my $self = $t->{token} or return undef;
	my ($gap, $string, $rv);
	
	# Load in the operator stuff if needed
	if ( $self->{operator} ) {
		# Is there a gap after the operator
		if ( $t->{char} =~ /\s/ ) {
			# Go past the gap
			$gap = $self->_scan_quote_like_operator_gap( $t );
			return undef unless defined $gap;
			if ( ref $gap ) {
				# End of file
				$self->{content} .= $$gap;
				return 0;
			}
			$self->{content} .= $gap;
		} 
	
		# The character we are now on is the seperator. What sort is it?
		# Initialize for the appropriate path.
		$self->{content} .= $t->{char};
		if ( $t->{char} =~ /(?:\<|\[|\{|\()/ ) {
			$self->{braced} = 1;
			$self->{sections}->[0] = {%{ $sectionPrototypes{$t->{char}} }};
		} else {
			$self->{braced} = 0;
			$self->{seperator} = $t->{char};
		}
		
		# Advance the cursor into the first region
		$t->{char} = substr( $t->{line}, ++$t->{line_cursor}, 1 );
	}
	
	# Ready to go.
	# Split based on whether we are braced or not.
	# The two methods for the different paths are used
	# just to make the code a bit easier to read.
	if ( $self->{braced} ) {
		$rv = $self->_fill_braced( $t ) or return $rv;
	} else {
		$rv = $self->_fill_normal( $t ) or return $rv;
	}
	
	# Does the quote support modifiers ( i.e. regex )
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
		
		# Correct the state
		$t->{char} = substr( $t->{line}, $t->{line_cursor}, 1 );
	}
	
	# Done
	return 1;
}

# Handle the content parsing path for normally seperated
sub _fill_normal {
	my $self = shift;
	my $t = shift;
	my ($gap, $string, $rv);

	# Get the content up to the seperator
	$string = $self->_scan_for_unescaped_character( $t, $self->{seperator} );
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
	$t->{char} = substr( $t->{line}, ++$t->{line_cursor}, 1 );	

	# Get the content up to the end seperator
	$string = $self->_scan_for_unescaped_character( $t, $self->{seperator} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	}
	$self->{content} .= $string;
	
	# Complete the properties of the first section
	$self->{sections}->[1] = {
		position => length $self->{content},
		size => length($string) - 1
		};
	
	# Done
	return 1;
}

# Handle content parsing for matching crace seperated
sub _fill_braced {
	my $self = shift;
	my $t = shift;
	my ($gap, $string, $rv);

	# Get the content up to the close character
	my $section = $self->{sections}->[0];
	$string = $self->_scan_for_brace_character( $t, $section->{_close} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	}
	$self->{content} .= $string;
	
	# Complete the properties of the first section
	$section->{position} = length $self->{content};
	$section->{size} = length($string) - 1;
	delete $section->{_close};
	
	# We are done if there is only one section
	return 1 if $self->{_sections} == 1;

	# There are two sections.	

	# Advance to the (space|openseperator)
	$t->{char} = substr( $t->{line}, ++$t->{line_cursor}, 1 );		

	# Is there a gap between the sections.
	if ( $t->{char} =~ /\s/ ) {
		# Go past the gap
		$gap = $self->_scan_quote_like_operator_gap( $t );
		return undef unless defined $gap;
		if ( ref $gap ) {
			# End of file
			$self->{content} .= $$gap;
			return 0;
		}
		$self->{content} .= $gap;
	} 

	# Check that the next character is an open selector
	if ( $t->{char} =~ /(?:\<|\[|\{|\()/ ) {
		# Initialize the second section
		$self->{sections}->[1] = {%{ $sectionPrototypes{$t->{char}} }};
	} else {
		# Error, it has to be a brace of some sort
		return $self->_error( "Syntax error. Second section of quote does not start with an open brace" );
	}

	# Advance into the second region
	$t->{char} = substr( $t->{line}, ++$t->{line_cursor}, 1 );		

	# Get the content up to the close character
	$section = $self->{sections}->[1];	
	$string = $self->_scan_for_brace_character( $t, $section->{_close} );
	return undef unless defined $string;
	if ( ref $string ) {
		# End of file
		$self->{content} .= $$string;
		return 0;
	}
	$self->{content} .= $string;
	
	# Complete the properties for the second section
	$section->{position} = length $self->{content};
	$section->{size} = length($string) - 1;
	delete $section->{_close};

	# Path done
	return 1;
}




#####################################################################
# Additional methods to find out about the quote

# In a scalar context, get the number of sections
# In an array context, get the section information
sub sections {
	my $self = shift;
	return wantarray
		? @{ $self->{sections} }
		: scalar @{ $self->{sections} };
}

1;
