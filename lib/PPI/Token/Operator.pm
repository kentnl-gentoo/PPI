package PPI::Token::Operator;

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION %OPERATOR};
BEGIN {
	$VERSION = '0.830';

	# Build the operator index
	%OPERATOR = map { $_ => 1 } (
		qw{
		-> ++ -- ** ! ~ + -
		=~ !~ * / % x + - . << >>
		< > <= >= lt gt le ge
		== != <=> eq ne cmp
		& | ^ && || // .. ...
		? : = += -= *= .=
		=>
		and or dor not
		}, ',' 	# Avoids "comma in qw{}" warning
		);
}

sub _on_char {
	my $t    = $_[1];
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Are we still an operator if we add the next character
	return 1 if $OPERATOR{ $t->{token}->{content} . $char };

	# Unless this is the heredoc operator...
	unless ( $t->{token}->{content} eq '<<' and $char =~ /[\w'" ]/ ) {
		# ...handle normally
		return $t->_finalize_token->_on_char( $t );
	}

	# This is a heredoc operator
	# Finalize the operator under a different class...
	$t->_set_token_class('RawInput::Operator');
	$t->_finalize_token;

	# ... and add a marker to the multiline input queue
	# to signal that we need to be looked at at the end
	# of the line.
	$t->{rawinput_queue} ||= [];
	push @{ $t->{rawinput_queue} }, $#{ $t->{tokens} };

	# Now deal with what should ( hopefully ) be either a
	# normal single quoted string, or a bareword, maybe with some
	# whitespace located before it, normally.
	$t->{class}->_on_char( $t );
}

1;
