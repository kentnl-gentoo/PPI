package PPI::Token::Operator;

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Token';

use vars qw{$VERSION %OPERATOR};
BEGIN {
	$VERSION = '0.902';

	# Build the operator index
	### NOTE - This is accessed several times explicitly
	###        in PPI::Token::Word. Do not rename this
	###        without also correcting them.
	%OPERATOR = map { $_ => 1 } (
		qw{
		-> ++ -- ** ! ~ + -
		=~ !~ * / % x + - . << >>
		< > <= >= lt gt le ge
		== != <=> eq ne cmp
		& | ^ && || // .. ...
		? : = += -= *= .=
		=> <>
		and or dor not
		}, ',' 	# Avoids "comma in qw{}" warning
		);
}

sub _on_char {
	my $t    = $_[1];
	my $char = substr( $t->{line}, $t->{line_cursor}, 1 );

	# Are we still an operator if we add the next character
	return 1 if $OPERATOR{ $t->{token}->{content} . $char };

	# Handle the special case if we might be a here-doc
	if ( $t->{token}->{content} eq '<<' ) {
		my $line = substr( $t->{line}, $t->{line_cursor} );
		if ( $line =~ /^(?:[^\W\d]|\s*['"`])/ ) {
			# This is a here-doc.
			# Change the class and move to the HereDoc's own _on_char method.
			$t->_set_token_class('HereDoc');
			return $t->{class}->_on_char( $t );
		}
	}

	# Handle the special case of the null Readline
	if ( $t->{token}->{content} eq '<>' ) {
		$t->_set_token_class('QuoteLike::Readline');
	}

	# Finalize normally
	$t->_finalize_token->_on_char( $t );
}

1;
