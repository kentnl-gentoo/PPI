package PPI::Token;

# This package represents a single token ( chunk of characters ) in a perl
# source code file

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Element';

# When we load PPI::Token, make sure all our children are loaded.
# Note that the load order is important here.
use PPI::Token::Attribute     ();
use PPI::Token::Bareword      ();
use PPI::Token::Comment       ();
use PPI::Token::Magic         ();
use PPI::Token::Number        ();
use PPI::Token::Operator      ();
use PPI::Token::Pod           ();
use PPI::Token::Quote         ();
use PPI::Token::Quote::Simple ();
use PPI::Token::Quote::Full   ();
use PPI::Token::Symbol        ();
use PPI::Token::Unknown       ();
use PPI::Token::Whitespace    ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.827';
}





# Create a new token
sub new {
	if ( @_ == 2 ) {
		# PPI::Token->new( $content );
		my $class = $_[0] eq __PACKAGE__ ? 'PPI::Token::Whitespace' : shift;
		return bless {
			content => (defined $_[0] ? "$_[0]" : '')
			}, $class;
	} elsif ( @_ == 3 ) {
		# PPI::Token->new( $class, $content );
		my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::' ? $_[1] : "PPI::Token::$_[1]";
		return bless {
			content => (defined $_[2] ? "$_[2]" : '')
			},  $class;
	}

	# Invalid argument count
	undef;
}

sub set_class {
	my $self = shift;
	return undef unless @_;
	my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::' ? shift : 'PPI::Token::' . shift;

	# Find out if the current and new classes are complex
	my $old_quote = (ref($self) =~ /\b(?:Quote|Regex)\b/o) ? 1 : 0;
	my $new_quote = ($class =~ /\b(?:Quote|Regex)\b/o) ? 1 : 0;

	# No matter what happens, we will have to rebless
	bless $self, $class;

	# If we are changing to or from a Quote style token, we
	# can't just rebless and need to do some extra thing
	# Otherwise, we have done enough
	return 1 if ($old_quote - $new_quote) == 0;

	# Make a new token from the old content, and overwrite the current
	# token's attributes with the new token's attributes.
	my $token = $class->new( $self->{content} ) or return undef;
	delete $self->{$_} foreach keys %$self;
	$self->{$_} = $token->{$_} foreach keys %$token;

	1;
}





#####################################################################
# Overloaded PPI::Element methods

sub _line { $_[0]->{_line} }
sub _col  { $_[0]->{_col}  }





#####################################################################
# Content related

sub content     { $_[0]->{content}                }
sub set_content { $_[0]->{content} = $_[1]        }
sub add_content { $_[0]->{content} .= $_[1]       }
sub length      { &CORE::length($_[0]->{content}) }





#####################################################################
# Tokenizer Default Methods

sub _on_line_start { 1 }
sub _on_line_end   { 1 }
sub _on_char       { 'Unknown' }





#####################################################################
# Structure Related Tests

sub _opens  { ref($_[0]) eq 'PPI::Token::Structure' and $_[0]->{content} =~ /(?:\(|\[|\{)/ }
sub _closes { ref($_[0]) eq 'PPI::Token::Structure' and $_[0]->{content} =~ /(?:\)|\]|\})/ }





#####################################################################
# Miscellaneous Analysis and Utilities

# Provide a more detailed test on a token
sub _isa {
	my $self = shift;

	# Test the class
	my $class = substr( $_[0], 0, 12 ) eq 'PPI::Token::' ? shift
		: 'PPI::Token::' . shift;
	return '' unless isa( $self, $class );

	# Test the content if needed
	! (@_ and $self->{content} ne shift);
}





#####################################################################
# After the __DATA__ tag

package PPI::Token::Data;

BEGIN {
	$PPI::Token::Data::VERSION = '0.827';
	@PPI::Token::Data::ISA     = 'PPI::Token';
}

sub _on_char { 1 }




#####################################################################
# After the __END__ tag

package PPI::Token::End;

BEGIN {
	$PPI::Token::End::VERSION = '0.827';
	@PPI::Token::End::ISA     = 'PPI::Token';
}

sub significant { 0 }

sub _on_char { 1 }

sub _on_line_start {
	my $t = $_[1];

	# Can we classify the entire line in one go
	$_ = $t->{line};
	if ( /^=(\w+)/ ) {
		# A Pod tag... change to pod mode
		$t->_new_token( 'Pod', $_ ) or return undef;
		unless ( $1 eq 'cut' ) {
			# Normal start to pod
			$t->{class} = 'PPI::Token::Pod';
		}

		# This is an error, but one we'll ignore
		# Don't go into Pod mode, since =cut normally
		# signals the end of Pod mode
	} else {
		if ( defined $t->{token} ) {
			# Add to existing token
			$t->{token}->{content} .= $t->{line};
		} else {
			$t->_new_token( 'End', $t->{line} );
		}
	}

	0;
}





#####################################################################
# A Label

package PPI::Token::Label;

BEGIN {
	$PPI::Token::Label::VERSION = '0.827';
	@PPI::Token::Label::ISA     = 'PPI::Token';
}





#####################################################################
# Characters used to create heirachal structure

package PPI::Token::Structure;

BEGIN {
	$PPI::Token::Structure::VERSION = '0.827';
	@PPI::Token::Structure::ISA     = 'PPI::Token';
}

sub _on_char {
	# Structures are one character long, always.
	# Finalize and process again.
	$_[1]->_finalize_token->_on_char( $_[1] );
}

sub _commit {
	my $t = $_[1];
	$t->_new_token( 'Structure', substr( $t->{line}, $t->{line_cursor}, 1 ) );
	$t->_finalize_token;
	0;
}

use vars qw{@match};
BEGIN {
	my @tmp = (
		'{' => '}', '}' => '{',
		'[' => ']', ']' => '[',
		'(' => ')', ')' => '(',
		);
	@match = ();
	while ( @tmp ) {
		$match[ord shift @tmp] = shift @tmp;
	}
}

# For a given brace, find it's opposing pair
sub _opposite { $match[ord $_[0]->{content} ] }





#####################################################################
# An array index thingy

package PPI::Token::ArrayIndex;

BEGIN {
	$PPI::Token::ArrayIndex::VERSION = '0.827';
	@PPI::Token::ArrayIndex::ISA     = 'PPI::Token';
}

sub _on_char {
	my $t = $_[1];

	# Suck in till the end of the arrayindex
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^([\w:']+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# End of token
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# Casting operator

package PPI::Token::Cast;

BEGIN {
	$PPI::Token::Cast::VERSION = '0.827';
	@PPI::Token::Cast::ISA     = 'PPI::Token';
}

# A cast is either % @ $ or $#
sub _on_char {
	$_[1]->_finalize_token->_on_char( $_[1] );
}





#####################################################################
# Subroutine prototype

package PPI::Token::SubPrototype;

BEGIN {
	$PPI::Token::SubPrototype::VERSION = '0.827';
	@PPI::Token::SubPrototype::ISA     = 'PPI::Token';
}

sub _on_char {
	my $class = shift;
	my $t = shift;

	# Suck in until we find the closing bracket
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(.*?\))/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Finish off the token and process the next char
	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# A Dashed Bareword ( -foo )

package PPI::Token::DashedBareword;

# This should be a string... but I'm still musing on whether that's a good idea

BEGIN {
	$PPI::Token::DashedBareword::VERSION = '0.827';
	@PPI::Token::DashedBareword::ISA     = 'PPI::Token';
}

sub _on_char {
	my $t = $_[1];

	# Suck to the end of the dashed bareword
	my $line = substr( $t->{line}, $t->{line_cursor} );
	if ( $line =~ /^(\w+)/ ) {
		$t->{token}->{content} .= $1;
		$t->{line_cursor} += length $1;
	}

	# Are we a file test operator?
	if ( $t->{token}->{content} =~ /^\-[rwxoRWXOezsfdlpSbctugkTBMAC]$/ ) {
		# File test operator
		$t->_set_token_class( 'Operator' ) or return undef;
	} else {
		# No, normal dashed bareword
		$t->_set_token_class( 'Bareword' ) or return undef;
	}

	$t->_finalize_token->_on_char( $t );
}





#####################################################################
# The __END__ and __DATA__ "seperator" tokens

package PPI::Token::Separator;

# These don't have any method, they are just for identification

BEGIN {
	$PPI::Token::Separator::VERSION = '0.827';
	@PPI::Token::Separator::ISA     = 'PPI::Token::Bareword';
}





#####################################################################
# All the quote and quote like operators

# Single Quote
package PPI::Token::Quote::Single;

BEGIN {
	$PPI::Token::Quote::Single::VERSION = '0.827';
	@PPI::Token::Quote::Single::ISA     = 'PPI::Token::Quote::Simple';
}

# Double Quote
package PPI::Token::Quote::Double;

BEGIN {
	$PPI::Token::Quote::Single::VERSION = '0.827';
	@PPI::Token::Quote::Double::ISA     = 'PPI::Token::Quote::Simple';
}

# Initially return true/fales for if there are ANY interpolations.
# Upgrade: Return the interpolated substrings.
# Upgrade: Returns parsed expressions.
sub interpolations {
	my $self = shift;

	# Are there any unescaped $things in the string
	!! $self->content =~ /(?<!\\)(?:\\\\)*\$/;
}

# Simplify a double-quoted string into a single-quoted string
sub simplify {
	# This only works on EXACTLY this class
	my $self = (ref $_[0] eq 'PPI::Token::Quote::Double') ? shift : return undef;

	# Don't bother if there are characters that could complicate things
	my $content = $self->content;
	my $value   = substr($content, 1, length($content) - 1);
	return '' if $value =~ /[\\\$\'\"]/;

	# Change the token to a single string
	$self->{content} = '"' . $value . '"';
	bless $self, 'PPI::Token::Quote::Single';
}

# Back Ticks
package PPI::Token::Quote::Execute;

BEGIN {
	$PPI::Token::Quote::Execute::VERSION = '0.827';
	@PPI::Token::Quote::Execute::ISA     = 'PPI::Token::Quote::Simple';
}

# Single Quote
package PPI::Token::Quote::OperatorSingle;

BEGIN {
	$PPI::Token::Quote::OperatorSingle::VERSION = '0.827';
	@PPI::Token::Quote::OperatorSingle::ISA     = 'PPI::Token::Quote::Full';
}

# Double Quote
package PPI::Token::Quote::OperatorDouble;

BEGIN {
	$PPI::Token::Quote::OperatorDouble::VERSION = '0.827';
	@PPI::Token::Quote::OperatorDouble::ISA     = 'PPI::Token::Quote::Full';
}

# Back Ticks
package PPI::Token::Quote::OperatorExecute;

BEGIN {
	$PPI::Token::Quote::OperatorExecute::VERSION = '0.827';
	@PPI::Token::Quote::OperatorExecute::ISA     = 'PPI::Token::Quote::Full';
}

# Quote Words
package PPI::Token::Quote::Words;

BEGIN {
	$PPI::Token::Quote::Words::VERSION = '0.827';
	@PPI::Token::Quote::Words::ISA     = 'PPI::Token::Quote::Full';
}

# Quote Regex Expression
package PPI::Token::Quote::Regex;

BEGIN {
	$PPI::Token::Quote::Regex::VERSION = '0.827';
	@PPI::Token::Quote::Regex::ISA     = 'PPI::Token::Quote::Full';
}

# Operator or Non-Operator Match Regex
package PPI::Token::Regex::Match;

BEGIN {
	$PPI::Token::Regex::Match::VERSION = '0.827';
	@PPI::Token::Regex::Match::ISA     = 'PPI::Token::Quote::Full';
}

# Operator Pattern Regex
### Either this of PPI::Token::Quote::Regex is probably a duplicate
package PPI::Token::Regex::Pattern;

BEGIN {
	$PPI::Token::Regex::Pattern::VERSION = '0.827';
	@PPI::Token::Regex::Pattern::ISA     = 'PPI::Token::Quote::Full';
}

# Replace Regex
package PPI::Token::Regex::Replace;

BEGIN {
	$PPI::Token::Regex::Replace::VERSION = '0.827';
	@PPI::Token::Regex::Replace::ISA     = 'PPI::Token::Quote::Full';
}

# Transform regex
package PPI::Token::Regex::Transform;

BEGIN {
	$PPI::Token::Regex::Transform::VERSION = '0.827';
	@PPI::Token::Regex::Transform::ISA     = 'PPI::Token::Quote::Full';
}





#####################################################################
# Classes to support multi-line inputs

package PPI::Token::RawInput::Operator;

BEGIN {
	$PPI::Token::RawInput::Operator::VERSION = '0.827';
	@PPI::Token::RawInput::Operator::ISA     = 'PPI::Token';
}

package PPI::Token::RawInput::Terminator;

BEGIN {
	$PPI::Token::RawInput::Terminator::VERSION = '0.827';
	@PPI::Token::RawInput::Terminator::ISA     = 'PPI::Token';
}

package PPI::Token::RawInput::String;

BEGIN {
	$PPI::Token::RawInput::String::VERSION = '0.827';
	@PPI::Token::RawInput::String::ISA     = 'PPI::Token';
}

1;
