package PPI::Format::Obfuscate;

# The PPI::Format::Obfuscate package provides the ability to make
# perl source code more difficult to read, thus helping to prevent
# theft of code, should that be your intent.
#
# Initially the obfuscate will perform two types of obfuscation.
#
# 1. Information removal
#    Removal of any and all comments, pod, and un-needed content
#
# 2. Whitespace compression
#    Compression of the layout into something more compact.
#    Initially, this will just change all base areas into a single
#    space, and reflow the code so that while it does fit into 
#    80 characters, it does so in the most tight way possible.

use strict;
use UNIVERSAL 'isa';
use base qw{PPI::Common Exporter};
use vars qw{@EXPORT_OK};
BEGIN {
	@EXPORT_OK = qw{obfuscate};
}

# Constructor.
# It can be passed either a PPI::Tokenizer object, or raw source code
sub new {
	my $class = shift;
	my $source = shift;
	
	# Create the object
	my $self = {
		tokens => [],
		processed => 0,
		};
	bless $self, $class;
	
	# Get the tokens
	unless ( defined $source ) {
		return $class->andError( "You did pass anything to create the obfuscate from" );
	}
	if ( ! ref $source and length $source ) {
		# It's a string.
		# Create the tokenizer for it
		$source = PPI::Tokenizer->new( source => $source );
		unless ( $source ) {
			return $class->andError( "Error creating tokenizer for obfuscate" );
		}
	}
		
	if ( isa( $source, 'PPI::Tokenizer' ) ) {
		# Get the tokens
		my $tokens = $source->allTokens;
		unless ( $tokens ) {
			return $class->andError( "Error getting tokens from tokenizer" );
		}
		$self->{tokens} = $tokens;
	} else {
		return $class->andError( "Bad argument" );
	}
	
	return $self;
}

# Get the obfuscated content
sub getObfuscated {
	my $self = shift;
	
	# Do the obfuscation if needed
	unless ( $self->{processed} ) {
		$self->doObfuscation or return undef;
	}
	
	# Return the output
	return $self->output;
}

# Generate output from the tokens.
# Basically, just join all the token's contents.
sub output {
	my $self = shift;
	return join '', map { $_->content } @{ $self->{tokens} };
}

# Do the actual obfuscation
# Note that this is fairly heavily inlined, due to the large 
# amount of time spent in here
sub doObfuscation {
	my $self = shift;
	
	# Stage one.
	# Remove all comments and pod
	my @stage1 = ();
	my $first = $self->{tokens}->[0];
	if ( $first and $first->{class} eq 'Comment' ) {
		if ( $first->{content} =~ /^#!/ ) {
			# We need to keep the hashbang line intact
			push @stage1, shift( @{ $self->{tokens} } );
		}
	}
	my %discard = ( 'Comment' => 1, 'Pod' => 1, );
	push @stage1, grep { ! $discard{$_->{class}} } @{$self->{tokens}};
	
	# Stage two, compress whitespace.
	# Remove duplicates, and convert all to a single space
	my @stage2 = ();
	my ($token, $next, $last, $lcls, $ncls, $tlen) = ();
	my $linelength = 0;
	my %op = ( ',' => 1, '=' => 1, '.' => 1 );
	for( my $i = 0;$i < scalar @stage1; $i++ ) {
		$token = $stage1[$i];
		$last = $stage1[$i-1] || $self->emptyToken;
		$next = $stage1[$i+1] || $self->emptyToken;

		if ( $token->{class} eq 'Base' ) {
			# Remove un-needed whitespace
			$lcls = $last->{class};
			$ncls = $next->{class};
			if ( $lcls eq 'Base' or $lcls eq 'Comment'
			  or $lcls eq 'Structure' or $ncls eq 'Structure' 
			) {
			  	next;
			}
			next if ( $lcls eq 'Operator' and $op{$last->{content}} );
			next if ( $ncls eq 'Operator' and $op{$next->{content}} );
			next if $linelength > 79;
			$token->{content} = " ";
		}
		$tlen = length $token->{content};
		if ( $linelength + $tlen > 80 ) {
			my $newline = PPI::Tokenizer::Token::Base->new( $last->zone, "\n" ) or return undef;
			push @stage2, $newline;
			$linelength = 0;
		}
		push @stage2, $token;
		$linelength += $tlen;
	}

	# Add a final trailing carriage return	
	my $newline = PPI::Tokenizer::Token::Base->new( $last->zone, "\n" ) or return undef;
	push @stage2, $newline;

	# Done
	$self->{tokens} = \@stage2;
	return 1;
}

# The obfuscate sub is an exportable one step function.
# Simple call obfuscate( $source ).
# Returns the obfuscated content.
# Returns undef on error.
sub obfuscate {
	my $source = shift;
	
	# Create a new obfuscate
	my $obfuscate = PPI::Format::Obfuscate->new( $source ) or return undef;
	return $obfuscate->getObfuscated;
}

# Create a new, empty token to use as a default.
# This ensures that methods like this, previous, etc will always
# return something. This should make the context scanning code easier
sub emptyToken { PPI::Tokenizer::Token->new( 'Base', '' ) }

1;
