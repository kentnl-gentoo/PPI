package PPI::Token::Whitespace;

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

# The 'Whitespace' class represents the normal default state of the parser.
# That is, the whitespace area 'outside' the code.

use vars qw{$VERSION @CLASSMAP @COMMITMAP};
BEGIN {
	$VERSION = '0.902';

	# Build the class and commit maps
        @CLASSMAP = ();
        foreach ( 'a' .. 'w', 'y', 'z', 'A' .. 'Z', '_' ) { $COMMITMAP[ord $_] = 'PPI::Token::Word'  }
	foreach ( qw!; [ ] { } )! )                       { $COMMITMAP[ord $_] = 'PPI::Token::Structure' }
        foreach ( 0 .. 9 )                                { $CLASSMAP[ord $_]  = 'Number'   }
	foreach ( qw{= ? | + > . ! ~ ^} )                 { $CLASSMAP[ord $_]  = 'Operator' }
	foreach ( qw{* $ @ & : - %} )                     { $CLASSMAP[ord $_]  = 'Unknown'  }

	# Miscellaneous remainder
        $COMMITMAP[ord '#'] = 'PPI::Token::Comment';
        $CLASSMAP[ord ',']  = 'PPI::Token::Operator';
	$CLASSMAP[ord "'"]  = 'Quote::Single';
	$CLASSMAP[ord '"']  = 'Quote::Double';
	$CLASSMAP[ord '`']  = 'QuoteLike::Backtick';
	$CLASSMAP[ord '\\'] = 'Cast';
	$CLASSMAP[ord '_']  = 'Word';
	$CLASSMAP[32]       = 'Whitespace'; # A normal space
}

# Create a null whitespace token
sub null { $_[0]->new('') }

### XS -> PPI/XS.xs:_PPI_Token_Whitespace__significant 0.900+
sub significant { '' }

sub _on_line_start {
	my $t = $_[1];
	$_ = $t->{line};

	# Can we classify the entire line in one go
	if ( /^\s*$/ ) {
		# A whitespace line
		$t->_new_token( 'Whitespace', $t->{line} ) or return undef;
		return 0;

	} elsif ( /^\s*#/ ) {
		# Add the comment token, and finalize it immediately
		$t->_new_token( 'Comment', $_ ) or return undef;
		$t->_finalize_token;
		return 0;

	} elsif ( /^=(\w+)/ ) {
		# A Pod tag... change to pod mode
		$t->_new_token( 'Pod', $t->{line} ) or return undef;
		if ( $1 eq 'cut' ) {
			# This is an error, but one we'll ignore
			# Don't go into Pod mode, since =cut normally
			# signals the end of Pod mode
		} else {
			$t->{class} = 'PPI::Token::Pod';
		}
		return 0;
	}

	1;
}

sub _on_char {
	my $t = $_[1];
	$_ = ord substr $t->{line}, $t->{line_cursor}, 1;

	# Do we definately know what something is?
	return $COMMITMAP[$_]->_commit($t) if $COMMITMAP[$_];

	# Handle the simple option first
	return $CLASSMAP[$_] if $CLASSMAP[$_];

	if ( $_ == 40 ) {  # $_ eq '('
		# Finalise any whitespace token...
		$t->_finalize_token if $t->{token};

		# Is this the beginning of a sub prototype?
		# We are a sub prototype IF
		# 1. The previous significant token is a bareword.
		# 2. The one before that is the word 'sub'.
		# 3. The one before that is a 'structure'

		# Get the three previous significant tokens
		my $tokens = $t->_previous_significant_tokens( 3 );
		if ( $tokens ) {
			# A normal subroutine declaration
		     	if ( $tokens->[0]->_isa('Word')
		     		and $tokens->[1]->_isa('Word', 'sub')
		     	 	and (
			     		$tokens->[2]->_isa('Structure')
					or $tokens->[2]->_isa('Whitespace', '')
			     		)
		     	) {
				# This is a sub prototype
				return 'Prototype';
			}

			# An prototyped anonymous subroutine
			if ( $tokens->[0]->_isa( 'Word', 'sub' ) ) {
				return 'Prototype';
			}
		}

		# This is a normal open bracket
		return 'Structure';

	} elsif ( $_ == 60 ) { # $_ eq '<'
		# Finalise any whitespace token...
		$t->_finalize_token if $t->{token};

		# This is either "less than" or "readline quote-like"
		# Do some context stuff to guess which.
		my $previous = $t->_last_significant_token;

		# The most common group of less-thans are used like
		# $foo < $bar
		# 1 < $bar
		# $#foo < $bar
		return 'Operator' if $previous->_isa( 'Symbol'     );
		return 'Operator' if $previous->_isa( 'Magic'      );
		return 'Operator' if $previous->_isa( 'Number'     );
		return 'Operator' if $previous->_isa( 'ArrayIndex' );

		# If it is <<... it's a here-doc instead
		my $next_char = substr $t->{line}, $t->{line_cursor} + 1, 1;
		if ( $next_char eq '<' ) {
			return 'Operator';
		}

		# The most common group of readlines are used like
		# while ( <...> )
		# while <>;
		return 'QuoteLike::Readline' if $previous->_isa( 'Structure', '('     );
		return 'QuoteLike::Readline' if $previous->_isa( 'Word',      'while' );
		return 'QuoteLike::Readline' if $previous->_isa( 'Operator',  '='     );

		if ( $previous->_isa( 'Structure', '}' ) ) {
			# Could go either way... do a regex check
			# $foo->{bar} < 2;
			# grep { .. } <foo>;
			my $line = substr( $t->{line}, $t->{line_cursor} );
			if ( $line =~ /^<[^\W\d]\w*>/ ) {
				# Almost definitely readline
				return 'QuoteLike::Readline';
			}
		}

		# Otherwise, we guess operator, which has been the default up
		# until this more comprehensive section was created.
		return 'Operator';

	} elsif ( $_ == 47 ) { #  $_ eq '/'
		# Finalise any whitespace token...
		$t->_finalize_token if $t->{token};

		# This is either a "divided by" or a "start regex"
		# Do some context stuff to guess ( ack ) which.
		# Hopefully the guess will be good enough.
		my $previous = $t->_last_significant_token;

		# Most times following an operator, we are a regex.
		# This includes cases such as:
		# ,  - As an argument in a list 
		# .. - The second condition in a flip flop
		# =~ - A bound regex
		# !~ - Ditto
		return 'Regexp::Match' if $previous->_isa( 'Operator' );

		# After a symbol
		return 'Operator' if $previous->_isa( 'Symbol' );
		return 'Operator' if $previous->_isa( 'Structure', ']' );

		# After another number
		return 'Operator' if $previous->_isa( 'Number' );

		# After going into scope/brackets
		return 'Regexp::Match' if $previous->_isa( 'Structure', '(' );
		return 'Regexp::Match' if $previous->_isa( 'Structure', '{' );
		return 'Regexp::Match' if $previous->_isa( 'Structure', ';' );

		# Functions that we know use commonly use regexs as an argument
		return 'Regexp::Match' if $previous->_isa( 'Word', 'split' );

		# After a keyword
		return 'Regexp::Match' if $previous->_isa( 'Word', 'if' );
		return 'Regexp::Match' if $previous->_isa( 'Word', 'unless' );
		return 'Regexp::Match' if $previous->_isa( 'Word', 'grep' );

		# What about the char after the slash? There's some things
		# that would be highly illogical to see if its an operator.
		my $next_char = substr $t->{line}, $t->{line_cursor} + 1, 1;
		if ( defined $next_char and length $next_char ) {
			if ( $next_char =~ /(?:\^|\[|\\)/ ) {
				return 'Regexp::Match';
			}
		}

		# Otherwise... erm... assume operator?
		# Add more tests here as potential cases come to light
		return 'Operator';

	} elsif ( $_ == 120 ) { # $_ eq 'x'
		# Handle an arcane special case where "string"x10 means the x is an operator.
		# String in this case means ::Single, ::Double or ::Execute, or the operator versions or same.
		my $nextchar = substr $t->{line}, $t->{line_cursor} + 1, 1;
		my $previous = $t->_previous_significant_tokens(1);
		$previous = ref $previous->[0];
		if ( $nextchar =~ /\d/ and $previous ) {
			if ( $previous =~ /::Quote::(?:Operator)?(?:Single|Double|Execute)$/ ) {
				return 'Operator';
			}
		}

		# Otherwise, commit like a normal bareword
		return PPI::Token::Word->_commit($t);
	}

	# This SHOULD BE is just normal base stuff
	'Whitespace';
}

sub _on_line_end { $_[1]->_finalize_token if $_[1]->{token} }

# Horozintal space before a newline is not needed.
# The ->tidy method removes it.
sub tidy {
	my $self = shift;
	$self->{content} =~ s/^\s+?(?>\n)//;
	1;
}

1;
