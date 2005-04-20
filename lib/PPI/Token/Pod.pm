package PPI::Token::Pod;

# Represents a section of POD

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.905';
}

### XS -> PPI/XS.xs:_PPI_Token_Pod__significant 0.900+
sub significant { '' }

sub __TOKENIZER__on_line_start {
	my $t = $_[1];

	# Add the line to the token first
	$t->{token}->{content} .= $t->{line};

	# Check the line to see if it is a =cut line
	if ( $t->{line} =~ /^=(\w+)/ ) {
		# End of the token
		$t->_finalize_token if lc $1 eq 'cut';
	}

	0;
}

# Breaks the pod into lines, returned as a reference to an array
sub lines { [ split /(?:\015{1,2}\012|\015|\012)/, $_[0]->{content} ] }

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

1;
