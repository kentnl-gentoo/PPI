package PPI::Document;

# A PPI::Document provides functionality for working with and
# manipulating a Perl document. It does so by aggressively indexing, 
# amoung other things.
# 
# The most complex aim of the PPI::Document is to provide for
# "round trip" editing of Perl documents. That is, to be able to navigate
# to, and edit, parts of a document without affecting the layout of other
# parts of the document.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';


# Constructor.
# The constructor is passed a tokenizer, from which to draw it's source
# tokens.
sub new {
	my $class = shift;
	my $arg = shift;
	my $tokens;
	if ( isa( $arg, 'PPI::Tokenizer' ) ) {
		$tokens = $arg->allTokens;
		return $class->andError( "Error while getting tokens" ) unless defined $tokens;
		return $class->andError( "Tokenizer did not provide any tokens" ) unless $tokens;
		
		# Convert from PPI::Tokenizer::Token sub class -> PPI::Lexer::Token
		$tokens = [ map { bless $_, 'PPI::Lexer::Token' } @$tokens ];
	
	} elsif ( isa( $arg, 'ARRAY' ) ) {
		if ( scalar @$arg and ! isa( $arg->[0], 'PPI::Lexer::Token' ) ) {
			return $class->andError( "Array does not contain PPI::Lexer::Token's" );
		}
		$tokens = $arg;
		
	} else {
		return $class->andError( "Constructor was not passed a valid argumetn" );
	
	}

	# Create the object
	my $self = {
		tokens => $tokens,
		
		# The index property also acts as a flag.
		# If it is undefined, then indexing is considerred 
		# to be turned off
		'index' => undef,
		cursor => 0,
		};
	bless $self, $class;

	# Turn on the indexing
	$self->enableIndex;
	
	return $self;
}

# Build the main index from scratch
sub buildIndex {
	my $self = shift;
	return undef unless $self->{index};
	
	# Create the index
	my $position = 0;
	my %hash = ();
	foreach ( @{ $self->{tokens} } ) {
		$hash{ "$_" } = $position++;
	}
	
	# Set the index
	$self->{index} = \%hash;
	return 1;
}






#####################################################################
# The normal array methods

sub d_push {
	my $self = shift;
	my $token = shift;
	unless ( isa( $token, 'PPI::Lexer::Token' ) ) {
		return $self->andError( "Can't push a non PPI::Lexer::Token" );
	}
	
	# Add the token
	push @{ $self->{tokens} }, $token;
	
	# Update the index
	if ( $self->{index} ) {
		$self->{index}->{ "$token" } = $#{ $self->{tokens} };
	}
	return 1;
}

sub d_pop {
	my $self = shift;
	
	# Remove the token
	my $token = pop @{$self->{tokens}};
	
	# Update the index
	if ( $token and $self->{index} ) {
		delete $self->{index}->{ "$token" };
	}
	return $token;
}

sub d_shift {
	my $self = shift;
	my $token = shift @{$self->{tokens}};
	if ( $token and $self->{index} ) {
		delete $self->{index}->{ "$token" };
	
		# Decrement all the positions
		my $hash = $self->{index};
		foreach ( keys %$hash ) {
			$hash->{$_}--;
		}
	}
	
	return $token;
}

sub d_unshift {
	my $self = shift;
	my $token = shift;
	unless ( isa( $token, 'PPI::Lexer::Token' ) ) {
		return $self->andError( "Can't unshift non PPI::Lexer::Token" );
	}
	
	if ( $self->{index} ) {
		# Increment all the positions
		my $hash = $self->{index};
		foreach ( keys %$hash ) {
			$hash->{$_}++;
		}
	}
	
	unshift @{ $self->{tokens} }, $token;
	return 1;
}

# This provides a full work-alike to the builtin splice command in
# every way. Any set of arguments to the builtin will work for this
# method as well.
sub splice {
	my $self = shift;
	unless ( @_ ) {
		# Remove and return all.
		# Handle this case seperately for speed
		my $tokens = $self->{tokens};
		$tokens = [];
		$self->{index} = {};
		return @$tokens;
	}
	
	# Prepare
	my ( $offset, $len, @insert ) = @_;
	my $tokens = $self->{tokens};
	my $index = $self->{index};
	
	# Handle negative offsets
	if ( $offset < 0 ) {
		if ( ($offset + scalar @$tokens) < 0 ) {
			# Negative offset is too negative
			# Use the same die that perl does
			die "Modification of non-creatable array value attempted, subscript $offset";
		}
		$offset = $offset + scalar @$tokens;
	}
	
	# Handle negative length
	if ( $len < 0 ) {
		my $endAt = $#$tokens + $len;
		$len = $endAt - $offset + 1;
		$len = 0 if $len < 0;
	}
	
	# Work out the index delta for those left behind after
	# the insert/remove point. Add the delta to their index entries.
	my $delta = scalar(@insert) - $len;
	if ( $self->{index} ) {
		foreach ( ($offset + $len) .. $#$tokens ) {
			$index->{ "$tokens->[$_]" } += $delta;
		}
	}
	
	# Do the splice to the token array
	my @remove = splice( @$tokens, $offset, $len, @insert );
	
	if ( $self->{index} ) {
		# Remove the index entries for those tokens removed
		foreach ( @remove ) { delete $index->{"$_"} }

		# Add the index entries for the new ones
		my $cursor = $offset;
		foreach ( @insert ) {
			$index->{"$_"} = $cursor++;
		}
	}
	
	# Done, return in accordance to the splice command
	return (scalar @remove)
		? (wantarray ? @remove : $remove[-1])
		: (wantarray ? () : undef );
}

# Get the entire token array
sub getTokenArray {
	my $self = shift;
	return $self->{tokens};
}

# Completely replace the token array
sub setTokenArray {
	my $self = shift;
	my $token_ref = shift;
	return undef unless isa( $token_ref, 'ARRAY' );
	
	# Set the tokens
	$self->{tokens} = $token_ref;
	
	# Rebuild the index
	$self->buildIndex();
	return 1;
}

	



#####################################################################
# Miscellaneous methods

# Stringifies the document back into something suitable for writing
# into a file
sub toString {
	my $self = shift;
	return join '', map { $_->{content} } @{ $self->{tokens} };
}

# Find the line/column position for an arbitrary token
# Return [ $line, $col ] on success
# Returns 0 if $token isn't in document
sub getLineChar {
	my $self = shift;
	my $token = shift;
	unless ( isa( $token, 'PPI::Lexer::Token' ) ) {
		return $self->andError( "Non PPI::Lexer::Token passed to getLineColumn" );
	}	
	unless ( $self->{index} ) {
		return $self->andError( "Cannot getLineChar while index is turned off" );
	}
	
	# Is it in the index
	my $position = $self->{index}->{"$token"};
	return undef unless defined $position;
	
	# Build a merged document to analyse
	my $before = join '', map { $_->{content} } @{$self->{tokens}}[0..($position-1)];
	
	# Split to determine line count
	my @lines = split /\n/, $before;
	my $line = scalar @lines;
	my $char = length $lines[-1];
	my $content = $self->{tokens}->[$position]->{content};
	if ( substr( $content, 0, 1 ) eq "\n" ) {
		$line += 1;
		$char = 1;
	} else { 
		$char += 1;
	}
	return [ $line, $char ];
}

sub getLineCharText {
	my $self = shift;
	my $lineChar = $self->getLineChar( shift ) or return undef;
	return "line $lineChar->[0], character $lineChar->[1]";
}

# Return the token at a particular position
sub getToken { $_[0]->{tokens}->[ $_[1] ] }
sub token { $_[0]->{tokens}->[ $_[1] ] }

# Get the first token
sub getFirstToken { $_[0]->{tokens}->[0] }

# Get the last token
sub getLastToken { $_[0]->{tokens}->[-1] }

# Get the position or a particular token
sub getPosition { 
	my $self = shift;
	return undef unless $self->{index};
	return $self->{index}->{$_[0]};
}

# Get a token in a relative position to an existing one
# Returns the token if found
# Returns 0 if no token there
# Returns token on succes
sub relativeToken {
	my $self = shift;
	my $token = shift;
	my $change = shift;
	return undef unless $self->{index};
	
	# Get the tokens position
	my $position = $self->{index}->{$token};
	return undef unless defined $position;
	
	# Add the change
	$position += $change;
	
	return $self->{tokens}->[$position] || 0;
}




#####################################################################
# Give the Document a cursor

# Reset the cursor
sub resetCursor { $_[0]->{cursor} = 0 }

# Get the next token for the cursor
sub nextToken {
	my $self = shift;
	return $self->{tokens}->[ $self->{cursor}++ ];
}

# As above, but just return the position, not the token itself
sub nextPosition { 
	my $self = shift;
	if ( defined $self->{tokens}->[ $self->{cursor} ] ) {
		return $self->{cursor}++;
	} else {
		return undef;
	}
}
	




#####################################################################
# Index enable/disable

sub enableIndex {
	my $self = shift;
	unless ( $self->{index} ) {
		$self->{index} = {};
		$self->buildIndex();
	}
	return 1;
}
sub disableIndex {
	my $self = shift;
	$self->{index} = undef;
	return 1;
}

1;
