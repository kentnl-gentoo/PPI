package PPI::Token::_Pod;

# This is the shadow package for Pod tokens.
# It holds extended functionality to keep the memory overhead
# for loading PPI down.

# When loaded, it overwrites the PPI::Token::Pod class methods
# as needed. Note, there isn't much in here yet... it will grow.

use strict;
use UNIVERSAL 'isa';
use PPI::Token::Classes ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.814';
}

# Merges one or more Pod tokens.
# Can be called as either a class or object method.
# If called as a class method, returns a new Pod token object.
# If called as an object method, modifies the object, and also returns
# it as a convenience.
sub merge {
	my $either = $_[0];

	# Check there are no bad arguments
	if ( grep { ! isa( $_, 'PPI::Token::Pod' ) } @_ ) {
		return undef;
	}

	# Get the tokens, and extract the lines
	my @content = map { $_->lines } grep { ref $_ } @_;
	return undef unless @content; # No pod tokens...

	# Remove the leading =pod tags, trailing =cut tags, and any empty lines
	# between them and the pod contents.
	foreach my $pod ( @content ) {
		# Leading =pod tag
		if ( @$pod and $pod->[0] =~ /^=pod\b/o ) {
			shift @$pod;
		}

		# Trailing =cut tag
		if ( @$pod and $pod->[-1] =~ /^=cut\b/o ) {
			pop @$pod;
		}

		# Leading and trailing empty lines
		while ( @$pod and $pod->[0] eq '' ) {
			shift @$pod;
		}
		while ( @$pod and $pod->[-1] eq '' ) {
			pop @$pod;
		}
	}

	# Remove any empty pod sections, and add the =pod and =cut tags
	# for the merged pod back to it.
	@content = ( [ '=pod' ], grep { @$_ } @content, [ '=cut' ] );

	# Convert back into a single string
	my $merged = join "\n", map { join( "\n", @$_ ) . "\n" } @content;

	# Was this an object method
	if ( ref $either ) {
		$either->{content} = $merged;
		return $either;

	}

	# Return the static method response
	$either->new( $merged );
}

# Link the methods
BEGIN {
	*PPI::Token::Pod::merge = *PPI::Token::_Pod::merge{CODE};
}

1;
