package PPI::Lexer;

# The PPI::Lexer package does some rudimentary structure analysis of
# the token stream produced by the tokenizer.

use strict;
use UNIVERSAL 'isa';
use PPI           ();
use PPI::Token    ();
use PPI::Document ();
use base 'PPI::Base';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.817';
}





#####################################################################
# Constructor

# Create a new lexer object
sub new {
	bless {
		Tokenizer => undef, # Where we store the tokenizer for a run
		buffer    => [],    # The input token buffer
		delayed   => [],    # The "delayed insignificant tokens" buffer
		# stack     => [],    # Since we add_element post-lex, keep the stack
		}, shift;
}





#####################################################################
# Main Lexing Methods

# Takes a file name, returns a ::Document object
sub lex_file {
	my $self = ref $_[0] ? shift : shift->new;
	my $file = (-f $_[0] and -r $_[0]) ? shift : return undef;

	# Load the source from the file
	local $/ = undef;
	open( FILE, $file ) or return undef;
	my $source = <FILE>;
	return undef unless defined $source;
	close FILE or return undef;

	# Hand off to the next method
	$self->lex_source( $source );
}

# Takes raw source, returns a ::Document object
sub lex_source {
	my $self   = ref $_[0] ? shift : shift->new;
	my $source = defined $_[0] ? shift : return undef;

	# Create the Tokenizer
	my $Tokenizer = PPI::Tokenizer->new( $source ) or return undef;

	# Hand off the next method
	$self->lex_tokenizer( $Tokenizer );
}

# Takes a ::Tokenizer object, returns a ::Document object
sub lex_tokenizer {
	my $self      = ref $_[0] ? shift : shift->new;
	my $Tokenizer = isa($_[0], 'PPI::Tokenizer') ? shift : return undef;

	# Create the Document
	my $Document = PPI::Document->new;

	# Lex the token stream into the document
	$self->{Tokenizer} = $Tokenizer;
	$self->_lex_document( $Document ) or return undef;
	$self->{Tokenizer} = undef;

	# Return the Document
	$Document;
}





#####################################################################
# Lex Methods - Document Object

sub _lex_document {
	my $self = shift;
	my $Document = isa($_[0], 'PPI::Document') ? shift : return undef;

	# Start the processing loop
	my $Token;
	while ( $Token = $self->_get_token ) {
		# Add insignificant tokens directly beneath us
		unless ( $Token->significant ) {
			$self->_add_element( $Document, $Token ) or return undef;
			next;
		}

		if ( $Token->content eq ';' ) {
			# It's a semi-colon on it's own.
			# We call this a null statement.
			my $Statement = PPI::Statement::Null->new( $Token ) or return undef;
			$self->_add_element( $Document, $Statement ) or return undef;
			next;
		}

		# Handle anything other than a structural element
		unless ( $Token->class eq 'PPI::Token::Structure' ) {
			# Determine the class for the Statement, and create it
			my $_class = $self->_resolve_statement($Document, $Token) or return undef;
			my $Statement = $_class->new( $Token ) or return undef;

			# Move the lexing down into the statement
			# $self->{stack} = [ $Document ];
			$self->_add_delayed( $Document ) or return undef;
			$self->_lex_statement( $Statement ) or return undef;
			# delete $self->{stack};

			# Add the completed Statement to the document
			$self->_add_element( $Document, $Statement ) or return undef;
			next;
		}

		# Is this the opening of a structure?
		if ( $Token->_opens ) {
			# Resolve the class for the Structure and create it
			my $_class = $self->_resolve_structure($Document, $Token) or return undef;
			my $Structure = $_class->new( $Token ) or return undef;

			# Move the lexing down into the structure
			# $self->{stack} = [ $Document ];
			$self->_add_delayed( $Document ) or return undef;
			$self->_lex_structure( $Structure ) or return undef;
			# delete $self->{stack};

			# Add the resolved Structure to the Document $self-
			$self->_add_element( $Document, $Structure ) or return undef;
			next;
		}

		# Is this the close of a structure.
		# Because we are at the top of the tree, this is an error.
		# This means either a mis-parsing, or an mistake in the code.
		return undef;
	}

	# Did we leave the main loop because of an error?
	return undef unless defined $Token;

	# No error, it's just the end of file.
	# Add any insignificant trailing tokens.
	$self->_add_delayed( $Document );
}





#####################################################################
# Lex Methods - Statement Object

use vars qw{%STATEMENT_CLASSES};
BEGIN {
	# Keyword -> Statement Subclass
	%STATEMENT_CLASSES = (
		# Things that affect the timing of execution
		'BEGIN'   => 'PPI::Statement::Scheduled',
		'INIT'    => 'PPI::Statement::Scheduled',
		'LAST'    => 'PPI::Statement::Scheduled',
		'END'     => 'PPI::Statement::Scheduled',

		# Loading and context statement
		'package' => 'PPI::Statement::Package',
		'use'     => 'PPI::Statement::Include',
		'no'      => 'PPI::Statement::Include',
		'require' => 'PPI::Statement::Include',

		# Various declerations
		'sub'     => 'PPI::Statement::Sub',
		'my'      => 'PPI::Statement::Variable',
		'local'   => 'PPI::Statement::Variable',
		'our'     => 'PPI::Statement::Variable',

		# Compound statement
		'if'      => 'PPI::Statement::Compound',
		'unless'  => 'PPI::Statement::Compound',
		'for'     => 'PPI::Statement::Compound',
		'foreach' => 'PPI::Statement::Compound',
		'while'   => 'PPI::Statement::Compound',

		'redo'    => 'PPI::Statement::Break',
		'next'    => 'PPI::Statement::Break',
		'last'    => 'PPI::Statement::Break',
		'return'  => 'PPI::Statement::Break',
		);
}

sub _resolve_statement {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;
	my $Token  = isa($_[0], 'PPI::Token') ? shift : return undef;

	# If it's a token in our list, use that class
	if ( $STATEMENT_CLASSES{$Token->content} ) {
		return $STATEMENT_CLASSES{$Token->content};
	}

	# Beyond that, I have no frigging idea for now
	'PPI::Statement';
}

sub _lex_statement {
	my $self = shift;
	my $Statement = isa($_[0], 'PPI::Statement') ? shift : return undef;

	# Begin processing tokens
	my $Token;
	while ( $Token = $self->_get_token ) {
		# Delay whitespace and comments
		unless ( $Token->significant ) {
			$self->_delay_element( $Token ) or return undef;
			next;
		}

		# Add normal things
		unless ( isa($Token, 'PPI::Token::Structure') ) {
			unless ( $Statement->_implied_end ) {
				# Doesn't need the special logic
				$self->_add_element( $Statement, $Token ) or return undef;
				next;
			}

			# Does this token continue the statement
			my $add = $self->_statement_continues( $Statement, $Token );
			if ( $add ) {
				# The token belongs in this statement
				$self->_add_element( $Statement, $Token ) or return undef;
				next;

			} elsif ( defined $add ) {
				# The token represents the beginning of a new statement.
				# Rollback the token and return.
				return $self->_rollback( $Token );

			} else {
				# Error during the check
				return undef;
			}
		}

		# Does the token force the end of the this statement
		if ( $Token->content eq ';' ) {
			$self->_add_element( $Statement, $Token ) or return undef;
			return 1;
		}

		# Is it the opening of a structure within the statement
		if ( $Token->_opens ) {
			# Determine the class for the structure and create it
			my $_class = $self->_resolve_structure($Statement, $Token) or return undef;
			my $Structure = $_class->new( $Token ) or return undef;

			# Move the lexing down into the Structure
			# push @{$self->{stack}}, $Statement;
			$self->_add_delayed( $Statement ) or return undef;
			$self->_lex_structure( $Structure ) or return undef;
			# pop @{$self->{stack}};

			# Add the completed Structure to the statement
			$self->_add_element( $Statement, $Structure ) or return undef;
			next;
		}

		# Otherwise, it must be a structure close, which means
		# our statement ends by falling out of scope.

		# Roll back anything not added, so our parent structure can
		# process it.
		return $self->_rollback( $Token );
	}

	# Was it an error in the tokenizer?
	return undef unless defined $Token;

	# No, it's just the end of the file...
	# Add any insignificant trailing tokens.
	$self->_add_delayed( $Statement );
}

# For many statements, it can be dificult to determine the end-point.
# This method takes a statement and the next significant token, and attempts
# to determine if the there is a statement boundary between the two, or if
# the statement can continue with the token.
sub _statement_continues {
	my $self = shift;
	my $Statement = isa($_[0], 'PPI::Statement') ? shift : return undef;
	my $Token     = isa($_[0], 'PPI::Token')     ? shift : return undef;
	my $LastToken = $Statement->nth_significant_child(-1) or return undef;

	# Alrighty then, there are only three implied end statement types,
	# ::Scheduled blocks, ::Sub declarations, and ::Compound statements.
	# Of these, ::Scheduled and ::Sub both follow the same rule.
	unless ( $Statement->isa('PPI::Statement::Compound') ) {
		# If the last significant element of the statement is a block,
		# then a scheduled statement is done, no questions asked.
		return ! $LastToken->isa('PPI::Structure::Block');
	}

	# Now we get to compound statements, which kind of suck hard.
	# The simplest of these 'if' type statements.
	my $type = $Statement->type or return undef;
	if ( $type eq 'if' ) {
		# Unless the last token is a block, anything is fine
		unless ( $LastToken->isa('PPI::Structure::Block') ) {
			return 1;
		}

		# If the token before the block is an 'else',
		# it's over, no matter what.
		my $Before = $Statement->nth_significant_child(-2);
		if ( $Before and $Before->isa('PPI::Token') and $Before->is_a('Bareword','else') ) {
			return 0;
		}

		# Otherwise, we continue for 'elsif' or 'else' only.
		return 1 if $Token->is_a('Bareword', 'else');
		return 1 if $Token->is_a('Bareword', 'elsif');
		return 0;
	}

	### FIXME - Default to 1 for now so we can test
	1;
}



#####################################################################
# Lex Methods - Structure Object

use vars qw{%ROUND_CLASSES};
BEGIN {
	# Keyword -> Structure class maps
	%ROUND_CLASSES = (
		'if'     => 'PPI::Structure::Condition',
		'elsif'  => 'PPI::Structure::Condition',
		'unless' => 'PPI::Structure::Condition',
		'while'  => 'PPI::Structure::Condition',
		);
}

# Given a parent element, and a token which will open a structure, determine
# the class that the structure should be.
sub _resolve_structure {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;
	my $Token  = isa($_[0], 'PPI::Token::Structure') ? shift : return undef;

	return $self->_resolve_structure_round ($Parent) if $Token->content eq '(';
	return $self->_resolve_structure_square($Parent) if $Token->content eq '[';
	return $self->_resolve_structure_curly ($Parent) if $Token->content eq '{';
	undef;
}

# Given a parent element, and a ( token to open a structure, determine
# the class that the structure should be.
sub _resolve_structure_round {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Get the last significant element in the parent
	my $Element = $Parent->nth_significant_child( -1 );
	if ( isa( $Element, 'PPI::Token::Bareword' ) ) {
		# Can it be determined because it is a keyword?
		return $ROUND_CLASSES{$Element->content}
			|| 'PPI::Structure::List';
	}

	# Otherwise, we don't know what it is
	'PPI::Structure';
}

# Given a parent element, and a [ token to open a structure, determine
# the class that the structure should be.
sub _resolve_structure_square {
	my $self = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Get the last significant element in the parent
	my $Element = $Parent->nth_significant_child( -1 );

	# Is this a subscript, like $foo[1] or $foo{expr}
	if ( isa($Element, 'PPI::Token::Operator') and $Element->content eq '->' ) {
		# $foo->[]
		return 'PPI::Structure::Subscript';
	}
	if ( isa($Element, 'PPI::Structure::Subscript') ) {
		# $foo{}[]
		return 'PPI::Structure::Subscript';
	}
	if ( isa($Element, 'PPI::Token::Symbol') and $Element->content =~ /^(?:\$|\@)/ ) {
		# $foo[], @foo[]
		return 'PPI::Structure::Subscript';
	}
	# FIXME - More cases to catch

	# Otherwise, we assume that it's an anonymous arrayref constructor
	'PPI::Structure::Constructor';
}

# Given a parent element, and a { token to open a structure, determine
# the class that the structure should be.
sub _resolve_structure_curly {
	my $self = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Get the last significant element in the parent
	my $Element = $Parent->nth_significant_child( -1 );

	# Is this a subscript, like $foo[1] or $foo{expr}
	if ( isa($Element, 'PPI::Token::Operator') and $Element->content eq '->' ) {
		# $foo->{}
		return 'PPI::Structure::Subscript';
	}
	if ( isa($Element, 'PPI::Structure::Subscript') ) {
		# $foo[]{}
		return 'PPI::Structure::Subscript';
	}
	if ( isa($Element, 'PPI::Token::Symbol') and $Element->content =~ /^(?:\$|\@)/ ) {
		# $foo{}, @foo{}
		return 'PPI::Structure::Subscript';
	}
	### FIXME - More cases to catch

	# Is this an anonymous hashref constructor
	### FIXME - Much harder...

	# Otherwise, we assume at this point
	# that it is a block of some sort.
	'PPI::Structure::Block';
}

sub _lex_structure {
	my $self = shift;
	my $Structure = isa($_[0], 'PPI::Structure') ? shift : return undef;

	# Start the processing loop
	my $Token;
	while ( $Token = $self->_get_token ) {
		# Is this a direct type token
		unless ( $Token->significant ) {
			$self->_delay_element( $Token ) or return undef;
			next;
		}

		# Anything other than a Structure starts a Statement
		unless ( $Token->class eq 'PPI::Token::Structure' ) {
			# Determine the class for the Statement and create it
			my $_class = $self->_resolve_statement($Structure, $Token) or return undef;
			my $Statement = $_class->new( $Token ) or return undef;

			# Move the lexing down into the Statement
			# push @{$self->{stack}}, $Statement;
			$self->_add_delayed( $Structure ) or return undef;
			$self->_lex_statement( $Statement ) or return undef;
			# pop @{$self->{stack}};

			# Add the completed statement to our elements
			$self->_add_element( $Structure, $Statement ) or return undef;
			next;
		}

		# Is this the opening of a structure?
		if ( $Token->_opens ) {
			### FIXME - Now, we really shouldn't be creating Structures
			###         inside of Structures. There really should be an
			###         Statement::Expression in here somewhere.
			# Determine the class for the structure and create it
			my $_class = $self->_resolve($Structure, $Token) or return undef;
			my $Structure2 = $_class->new( $Token ) or return undef;

			# Move the lexing down into the Structure
			# push @{$self->{stack}}, $Structure;
			$self->_add_delayed( $Structure ) or return undef;
			$self->_lex_structure( $Structure2 ) or return undef;
			# pop @{$self->{stack}};

			# Add the completed Structure to the statement
			$self->_add_element( $Structure, $Structure2 ) or return undef;
			next;
		}

		# Is this the close of a structure ( which would be an error )
		if ( $Token->_closes ) {
			# Is this OUR closing structure
			if ( $Token->content eq $Structure->start->_opposite ) {
				# Add any delayed tokens, and the finishing token
				$self->_add_delayed( $Structure ) or return undef;
				$Structure->{finish} = $Token;
				return 1;
			}

			# Unexpected close... error
			return undef;
		}

		# It's a semi-colon on it's own, just inside the block.
		# This is a null statement.
		my $Statement = PPI::Statement::Null->new( $Token ) or return undef;
		$self->_add_element( $Structure, $Statement ) or return undef;
	}

	# Is this an error
	return undef unless defined $Token;

	# No, it's just the end of file.
	# Add any insignificant trailing tokens.
	$self->_add_delayed( $Structure );
}





#####################################################################
# Support Methods

# Get the next token for processing, handling buffering
sub _get_token {
	my $self = shift;
	$self->{Tokenizer} or return undef;

	# First from the buffer
	if ( @{$self->{buffer}} ) {
		# Take from the front, add to the end
		return shift @{$self->{buffer}};
	}

	# Then from the Tokenizer
	$self->{Tokenizer}->get_token;
}

# Delay the addition of a insignificant elements
sub _delay_element {
	my $self = shift;
	my $Element = isa($_[0], 'PPI::Element') ? shift : return undef;

	# Take from the front, add to the end
	push @{$self->{delayed}}, $Element;
}

# Add an Element to a Node, including any delayed Elements
sub _add_element {
	my $self = shift;
	my $Parent  = isa($_[0], 'PPI::Node') ? shift : return undef;
	my $Element = isa($_[0], 'PPI::Element') ? shift : return undef;

	# Add first the delayed, from the front, then the passed element
	foreach my $el ( @{$self->{delayed}}, $Element ) {
		$Parent->add_element( $el ) or return undef;
	}

	# Clear the delated elements
	$self->{delayed} = [];
	1;
}

# Specifically just add any delayed tokens, if any.
sub _add_delayed {
	my $self = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Add any delayed
	foreach my $el ( @{$self->{delayed}} ) {
		$Parent->add_element( $el ) or return undef;
	}

	# Clear the delayed elements
	$self->{delayed} = [];
	1;
}

# Rollback the delayed tokens, plus any passed. Once all the tokens
# have been moved back on to the buffer, the order should be.
# <--- @{$self->{delayed}}, @_, @{$self->{buffer}} <----
sub _rollback {
	my $self = shift;

	# First, put any passed objects back
	if ( @_ ) {
		unshift @{$self->{buffer}}, splice @_;
	}

	# Then, put back anything delayed
	if ( @{$self->{delayed}} ) {
		unshift @{$self->{buffer}}, splice @{$self->{delayed}};
	}

	1;
}
	
1;
