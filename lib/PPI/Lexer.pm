package PPI::Lexer;

=pod

=head1 NAME

PPI::Lexer - The PPI Lexer

=head1 SYNOPSIS

  use PPI;
  
  # Create a new Lexer
  my $Lexer = PPI::Lexer->new;
  
  # Build a PPI::Document object from a Token stream
  my $Tokenizer = PPI::Tokenizer->load( 'My/Module.pm' );
  my $Document = $Lexer->lex_tokenizer( $Tokenizer );
  
  # Build a PPI::Document object for some raw source
  my $source = File::Slurp::read_file( 'My/Module.pm' );
  $Document = $Lexer->lex_source( $source );
  
  # Build a PPI::Document object for a particular file name
  $Document = $Lexer->lex_file( 'My/Module.pm' );

=head1 DESCRIPTION

The is the PPI Lexer. In the larger scheme of things, its job is to take
token streams, in a variety of forms, and "lex" them into nested structures.

Pretty much everything in this module happens behind the scenes at this
point. In fact, at the moment you don't really need to instantiate the lexer
at all, the three main methods will auto-instantiate themselves a PPI::Lexer
object as needed.

All methods do a one-shot "lex this and give me a PPI::Document object".

=head1 METHODS

=cut

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Base';
use File::Slurp   ();
use PPI           ();
use PPI::Token    ();
use PPI::Document ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.846';
}





#####################################################################
# Constructor

=pod

=head2 new

The C<new> constructor creates a new PPI::Lexer object. The object itself
is merely used to hold various buffers and state data during the lexing
process, and holds no significant data between -E<gt>lex_xxxxx calls.

Returns a new PPI::Lexer object

=cut

sub new {
	bless {
		Tokenizer => undef, # Where we store the tokenizer for a run
		buffer    => [],    # The input token buffer
		delayed   => [],    # The "delayed insignificant tokens" buffer
		}, shift;
}





#####################################################################
# Main Lexing Methods

=pod

=head2 lex_file $filename

The C<lex_file> method takes a filename as argument. It then loads the file,
creates a PPI::Tokenizer for the content and lexes the token stream
produced by the tokenizer. Basically, a sort of all-in-one method for
getting a PPI::Document object from a file name.

Returns a PPI::Document object, or C<undef> on error.

=cut

sub lex_file {
	my $self = ref $_[0] ? shift : shift->new;
	my $file = (-f $_[0] and -r $_[0]) ? shift : return undef;

	# Load the source and hand off to the next method
	$self->lex_source( scalar File::Slurp::read_file $file );
}

=pod

=head2 lex_source $string

The C<lex_source> method takes a normal scalar string as argument. It
creates a PPI::Tokenizer object for the string, and then lexes the
resulting token stream.

Returns a PPI::Document object, or C<undef> on error.

=cut

sub lex_source {
	my $self   = ref $_[0] ? shift : shift->new;
	my $source = defined $_[0] ? shift : return undef;

	# Create the Tokenizer and hand off to the next method
	my $Tokenizer = PPI::Tokenizer->new( $source ) or return undef;
	$self->lex_tokenizer( $Tokenizer );
}

=pod

=head2 lex_tokenizer $Tokenizer

The C<lex_tokenizer> takes as argument a PPI::Tokenizer object. It
lexes the token stream from the tokenizer into a PPI::Document object.

Returns a PPI::Document object, or C<undef> on error.

=cut

sub lex_tokenizer {
	my $self      = ref $_[0] ? shift : shift->new;
	my $Tokenizer = isa(ref $_[0], 'PPI::Tokenizer') ? shift : return undef;

	# Create the Document
	my $Document = PPI::Document->new;

	# Lex the token stream into the document
	$self->{Tokenizer} = $Tokenizer;
	my $rv = $self->_lex_document( $Document );
	$self->{Tokenizer} = undef;
	return $Document if $rv;

	# If an error occurs, DESTROY the partially built document.
	$Document->DESTROY;
	undef;
}





#####################################################################
# Lex Methods - Document Object

sub _lex_document {
	my $self = shift;
	my $Document = isa(ref $_[0], 'PPI::Document') ? shift : return undef;

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
		unless ( ref $Token eq 'PPI::Token::Structure' ) {
			# Determine the class for the Statement, and create it
			my $_class = $self->_resolve_new_statement($Document, $Token) or return undef;
			my $Statement = $_class->new( $Token ) or return undef;

			# Move the lexing down into the statement
			$self->_add_delayed( $Document ) or return undef;
			$self->_lex_statement( $Statement ) or return undef;

			# Add the completed Statement to the document
			$self->_add_element( $Document, $Statement ) or return undef;
			next;
		}

		# Is this the opening of a structure?
		if ( $Token->_opens ) {
			# Resolve the class for the Structure and create it
			my $_class = $self->_resolve_new_structure($Document, $Token) or return undef;
			my $Structure = $_class->new( $Token ) or return undef;

			# Move the lexing down into the structure
			$self->_add_delayed( $Document ) or return undef;
			$self->_lex_structure( $Structure ) or return undef;

			# Add the resolved Structure to the Document $self-
			$self->_add_element( $Document, $Structure ) or return undef;
			next;
		}

		# Is this the close of a structure.
		if ( $Token->_closes ) {
			# Because we are at the top of the tree, this is an error.
			# This means either a mis-parsing, or an mistake in the code.
			# To handle this, we create a "Naked Close" statement
			my $UnmatchedBrace = PPI::Statement::UnmatchedBrace->new( $Token ) or return undef;
			$self->_add_element( $Document, $UnmatchedBrace ) or return undef;
			next;
		}

		# Shouldn't be able to get here
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
		'BEGIN'    => 'PPI::Statement::Scheduled',
		'CHECK'    => 'PPI::Statement::Scheduled',
		'INIT'     => 'PPI::Statement::Scheduled',
		'END'      => 'PPI::Statement::Scheduled',

		# Loading and context statement
		'package'  => 'PPI::Statement::Package',
		'use'      => 'PPI::Statement::Include',
		'no'       => 'PPI::Statement::Include',
		'require'  => 'PPI::Statement::Include',

		# Various declarations
		'my'       => 'PPI::Statement::Variable',
		'local'    => 'PPI::Statement::Variable',
		'our'      => 'PPI::Statement::Variable',
		# Statements starting with 'sub' could be any one of...
		# 'sub'    => 'PPI::Statement::Sub',
		# 'sub'    => 'PPI::Statement::Scheduled',
		# 'sub'    => 'PPI::Statement',

		# Compound statement
		'if'       => 'PPI::Statement::Compound',
		'unless'   => 'PPI::Statement::Compound',
		'for'      => 'PPI::Statement::Compound',
		'foreach'  => 'PPI::Statement::Compound',
		'while'    => 'PPI::Statement::Compound',

		# Various ways of breaking out of scope
		'redo'     => 'PPI::Statement::Break',
		'next'     => 'PPI::Statement::Break',
		'last'     => 'PPI::Statement::Break',
		'return'   => 'PPI::Statement::Break',

		# Special sections of the file
		'__DATA__' => 'PPI::Statement::Data',
		'__END__'  => 'PPI::Statement::End',
		);
}

sub _resolve_new_statement {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;
	my $Token  = isa($_[0], 'PPI::Token') ? shift : return undef;

	# If it's a token in our list, use that class
	if ( $STATEMENT_CLASSES{$Token->content} ) {
		return $STATEMENT_CLASSES{$Token->content};
	}

	# Handle the more in-depth sub detection
	if ( $Token->content eq 'sub' ) {
		# Read ahead to the next significant token
		my $Next;
		while ( $Next = $self->_get_token ) {
			unless ( $Next->significant ) {
				$self->_delay_element( $Next ) or return undef;
				next;
			}

			# Got the next significant token
			my $_class = $STATEMENT_CLASSES{$Next->content};
			if ( $_class and $_class eq 'PPI::Statement::Scheduled' ) {
				$self->_rollback( $Next );
				return 'PPI::Statement::Scheduled';
			}
			if ( $Next->isa('PPI::Token::Word') ) {
				$self->_rollback( $Next );
				return 'PPI::Statement::Sub';
			}

			### Comment out these two, as they would return PPI::Statement anyway
			# if ( $content eq '{' ) {
			#	Anonymous sub at start of statement
			#	return 'PPI::Statement';
			# }
			#
			# if ( $Next->isa('PPI::Token::Prototype') ) {
			#	Anonymous sub at start of statement
			#	return 'PPI::Statement';
			# }

			# PPI::Statement is the safest fall-through
			$self->_rollback( $Next );
			return 'PPI::Statement';
		}

		# End of file... PPI::Statement::Sub is the most likely
		$self->_rollback( $Next );
		return 'PPI::Statement::Sub';
	}

	# If our parent is a Condition, we are an Expression
	if ( $Parent->isa('PPI::Structure::Condition') ) {
		return 'PPI::Statement::Expression';
	}

	# If our parent is a List, we are also an expression
	if ( $Parent->isa('PPI::Structure::List') ) {
		return 'PPI::Statement::Expression';
	}

	if ( isa($Token, 'PPI::Token::Label') ) {
		return 'PPI::Statement::Compound';
	}

	# Beyond that, I have no idea for the moment.
	# Just keep adding more conditions above this.
	'PPI::Statement';
}

sub _lex_statement {
	my $self = shift;
	my $Statement = isa($_[0], 'PPI::Statement') ? shift : return undef;

	# Handle some special statements
	if ( $Statement->isa('PPI::Statement::End') ) {
		return $self->_lex_statement_end( $Statement );
	}

	# Begin processing tokens
	my $Token;
	while ( $Token = $self->_get_token ) {
		# Delay whitespace and comment tokens
		unless ( $Token->significant ) {
			$self->_delay_element( $Token ) or return undef;
			next;
		}

		# Structual closes, and __DATA__ and __END__ tags implicitly
		# end every type of statement
		if ( $Token->_closes or $Token->isa('PPI::Token::Separator') ) {
			# Rollback and end the statement
			return $self->_rollback( $Token );
		}

		# Normal statements never implicitly end
		unless ( $Statement->__LEXER__normal ) {
			# Have we hit an implicit end to the statement
			unless ( $self->_statement_continues( $Statement, $Token ) ) {
				# Rollback and finish the statement
				return $self->_rollback( $Token );
			}
		}

		# Any normal character just gets added
		unless ( isa($Token, 'PPI::Token::Structure') ) {
			$self->_add_element( $Statement, $Token ) or return undef;
			next;
		}

		# Handle normal statement terminators
		if ( $Token->content eq ';' ) {
			$self->_add_element( $Statement, $Token ) or return undef;
			return 1;
		}

		# Which leaves us with a new structure

		# Determine the class for the structure and create it
		my $sclass = $self->_resolve_new_structure($Statement, $Token) or return undef;
		my $Structure = $sclass->new( $Token ) or return undef;

		# Move the lexing down into the Structure
		$self->_add_delayed( $Statement )   or return undef;
		$self->_lex_structure( $Structure ) or return undef;

		# Add the completed Structure to the statement
		$self->_add_element( $Statement, $Structure ) or return undef;
	}

	# Was it an error in the tokenizer?
	return undef unless defined $Token;

	# No, it's just the end of the file...
	# Roll back any insignificant tokens, they'll get added at the Document level
	$self->_rollback;
}

sub _lex_statement_end {
	my $self = shift;
	my $Statement = isa($_[0], 'PPI::Statement::End') ? shift : return undef;
	
	# End of the file, EVERYTHING is ours
	my $Token;
	while ( $Token = $self->_get_token ) {
		$Statement->__add_element( $Token );
	}

	# Was it an error in the tokenizer?
	return undef unless defined $Token;

	# No, it's just the end of the file...
	# Roll back any insignificant tokens, they'll get added at the Document level
	$self->_rollback;
}

# For many statements, it can be dificult to determine the end-point.
# This method takes a statement and the next significant token, and attempts
# to determine if the there is a statement boundary between the two, or if
# the statement can continue with the token.
sub _statement_continues {
	my $self = shift;
	my $Statement = isa($_[0], 'PPI::Statement') ? shift : return undef;
	my $Token     = isa($_[0], 'PPI::Token')     ? shift : return undef;

	# Alrighty then, there are only three implied end statement types,
	# ::Scheduled blocks, ::Sub declarations, and ::Compound statements.
	unless ( ref($Statement) =~ /\b(?:Scheduled|Sub|Compound)$/ ) {
		return 1;
	}

	# Of these three, ::Scheduled and ::Sub both follow the same simple
	# rule and can be handled first.
	my @part = $Statement->schildren;
	my $LastChild = $part[-1] or return undef;
	unless ( $Statement->isa('PPI::Statement::Compound') ) {
		# If the last significant element of the statement is a block,
		# then a scheduled statement is done, no questions asked.
		return ! $LastChild->isa('PPI::Structure::Block');
	}

	# Now we get to compound statements, which kind of suck (to lex).
	# However, of them all, the 'if' type, which includes unless, are
	# relatively easy to handle compared to the others.
	my $type = $Statement->type or return undef;
	if ( $type eq 'if' ) {
		# This should be one of the following
		# if (EXPR) BLOCK
		# if (EXPR) BLOCK else BLOCK
		# if (EXPR) BLOCK elsif (EXPR) BLOCK ... else BLOCK

		# We only implicitly end on a block
		unless ( $LastChild->isa('PPI::Structure::Block') ) {
			# if (EXPR) ...
			# if (EXPR) BLOCK else ...
			# if (EXPR) BLOCK elsif (EXPR) BLOCK ...
			return 1;
		}

		# If the token before the block is an 'else',
		# it's over, no matter what.
		my $NextLast = $Statement->schild(-2);
		if ( $NextLast and $NextLast->isa('PPI::Token') and $NextLast->_isa('Word','else') ) {
			return '';
		}

		# Otherwise, we continue for 'elsif' or 'else' only.
		return 1 if $Token->_isa('Word', 'else');
		return 1 if $Token->_isa('Word', 'elsif');
		return '';
	}

	if ( $type eq 'label' ) {
		# We only have the label so far, could be any of
		# LABEL while (EXPR) BLOCK
		# LABEL while (EXPR) BLOCK continue BLOCK
		# LABEL for (EXPR; EXPR; EXPR) BLOCK
		# LABEL foreach VAR (LIST) BLOCK
		# LABEL foreach VAR (LIST) BLOCK continue BLOCK
		# LABEL BLOCK continue BLOCK

		# Handle cases with a work after the label
		if ( $Token->isa('PPI::Token::Word')
		and $Token->content =~ /^(?:while|for|foreach)$/ ) {
			return 1;
		}
	
		# Handle labelled blocks
		if ( $Token->isa('PPI::Structure::Block') ) {
			return 1;
		}

		return '';
	}

	# Handle the common "after round braces" case
	if ( isa($LastChild, 'PPI::Structure') and $LastChild->braces eq '()' ) {
		# LABEL while (EXPR) ...
		# LABEL while (EXPR) ...
		# LABEL for (EXPR; EXPR; EXPR) ...
		# LABEL foreach VAR (LIST) ...
		# LABEL foreach VAR (LIST) ...
		# Only a block will do
		return $Token->_isa('Structure', '{');
	}

	if ( $type eq 'for' ) {
		# LABEL for (EXPR; EXPR; EXPR) BLOCK
		if ( isa($LastChild, 'PPI::Token::Word') and $LastChild->content eq 'for' ) {
			# LABEL for ...
			# Only an open braces will do
			return $Token->_isa('Structure', '(');

		} elsif ( isa($LastChild, 'PPI::Structure::Block') ) {
			# LABEL for (EXPR; EXPR; EXPR) BLOCK
			# That's it, nothing can continue
			return '';
		}
	}

	# Handle the common continue case
	if ( isa($LastChild, 'PPI::Token::Word') and $LastChild->content eq 'continue' ) {
		# LABEL while (EXPR) BLOCK continue ...
		# LABEL foreach VAR (LIST) BLOCK continue ...
		# LABEL BLOCK continue ...
		# Only a block will do
		return $Token->_isa('Structure', '{');
	}

	# Handle the common continuable block case
	if ( isa($LastChild, 'PPI::Structure::Block') ) {
		# LABEL while (EXPR) BLOCK
		# LABEL while (EXPR) BLOCK ...
		# LABEL for (EXPR; EXPR; EXPR) BLOCK
		# LABEL foreach VAR (LIST) BLOCK
		# LABEL foreach VAR (LIST) BLOCK ...
		# LABEL BLOCK ...
		# Is this the block for a continue?
		if ( isa($part[-2], 'PPI::Token::Word') and $part[-2]->content eq 'continue' ) {
			# LABEL while (EXPR) BLOCK continue BLOCK
			# LABEL foreach VAR (LIST) BLOCK continue BLOCK
			# LABEL BLOCK continue BLOCK
			# That's it, nothing can continue this
			return '';
		}

		# Only a continue will do
		return $Token->_isa('Word', 'continue');
	}

	if ( $type eq 'block' ) {
		# LABEL BLOCK continue BLOCK
		# Every possible case is covered in the common cases above
	}

	if ( $type eq 'while' ) {
		# LABEL while (EXPR) BLOCK
		# LABEL while (EXPR) BLOCK continue BLOCK
		# The only case not covered is the while ...
		if ( isa($LastChild, 'PPI::Token::Word') and $LastChild->content eq 'while' ) {
			# LABEL while ...
			# Only a condition structure will do
			return $Token->_isa('Structure', '(');
		}
	}

	if ( $type eq 'foreach' ) {
		# LABEL foreach VAR (LIST) BLOCK
		# LABEL foreach VAR (LIST) BLOCK continue BLOCK
		# The only two cases that have not been covered already are
		# 'foreach ...' and 'foreach VAR ...'
		return undef unless isa($LastChild, 'PPI::Token');

		if ( isa($LastChild, 'PPI::Token::Symbol') ) {
			# LABEL foreach my $scalar ...
			# Only an open round brace will do
			return $Token->_isa('Structure', '(');
		}

		if ( $LastChild->content eq 'foreach' ) {
			# There are three possibilities here
			if ( $Token->_isa('Word', 'my') ) {
				# VAR == 'my ...'
				return 1;
			} elsif ( $Token->content =~ /^\$/ ) {
				# VAR == '$scalar'
				return 1;
			} elsif ( $Token->_isa('Structure', '(') ) {
				return 1;
			} else {
				return '';
			}
		}
		
		if ( $LastChild->content eq 'my' ) {
			# LABEL foreach my ...
			# Only a scalar will do
			return $Token->content =~ /^\$/;
		}
	}

	# Something we don't know about... what could it be
	warn("Illegal parse state in '$type' type compound statement");
	return undef;
}





#####################################################################
# Lex Methods - Structure Object

use vars qw{%ROUND_CLASSES};
BEGIN {
	# Keyword -> Structure class maps
	%ROUND_CLASSES = (
		# Conditions
		'if'     => 'PPI::Structure::Condition',
		'elsif'  => 'PPI::Structure::Condition',
		'unless' => 'PPI::Structure::Condition',
		'while'  => 'PPI::Structure::Condition',
		'until'  => 'PPI::Structure::Condition',

		# For(each)
		'for'     => 'PPI::Structure::ForLoop',
		'foreach' => 'PPI::Structure::ForLoop',
		);
}

# Given a parent element, and a token which will open a structure, determine
# the class that the structure should be.
sub _resolve_new_structure {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;
	my $Token  = isa($_[0], 'PPI::Token::Structure') ? shift : return undef;

	return $self->_resolve_new_structure_round ($Parent) if $Token->content eq '(';
	return $self->_resolve_new_structure_square($Parent) if $Token->content eq '[';
	return $self->_resolve_new_structure_curly ($Parent) if $Token->content eq '{';
	undef;
}

# Given a parent element, and a ( token to open a structure, determine
# the class that the structure should be.
sub _resolve_new_structure_round {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Get the last significant element in the parent
	my $Element = $Parent->schild(-1);
	if ( isa( $Element, 'PPI::Token::Word' ) ) {
		# Can it be determined because it is a keyword?
		if ( $ROUND_CLASSES{$Element->content} ) {
			return $ROUND_CLASSES{$Element->content};
		}
	}

	# If we are part of a for or foreach statement, we are a ForLoop
	if ( $Parent->isa('PPI::Statement::Compound') and $Parent->type =~ /^for(?:each)?$/ ) {
		return 'PPI::Structure::ForLoop';
	}

	# Otherwise, it must be a list

	# If the previous element is -> then we mark it as a dereference
	if ( isa($Element, 'PPI::Token::Operator') and $Element->content eq '->' ) {
		$Element->{_dereference} = 1;
	}

	'PPI::Structure::List'
}

# Given a parent element, and a [ token to open a structure, determine
# the class that the structure should be.
sub _resolve_new_structure_square {
	my $self   = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Get the last significant element in the parent
	my $Element = $Parent->schild(-1);

	# Is this a subscript, like $foo[1] or $foo{expr}
	if ( isa($Element, 'PPI::Token::Operator') and $Element->content eq '->' ) {
		# $foo->[]
		$Element->{_dereference} = 1;
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
sub _resolve_new_structure_curly {
	my $self = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Get the last significant element in the parent
	my $Element = $Parent->schild(-1);

	# Is this a subscript, like $foo[1] or $foo{expr}
	if ( isa($Element, 'PPI::Token::Operator') and $Element->content eq '->' ) {
		# $foo->{}
		$Element->{_dereference} = 1;
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

	# Are we in a compound statement
	if ( $Parent->isa('PPI::Statement::Compound') ) {
		# We will only encounter blocks in compound statements
		return 'PPI::Structure::Block';
	}

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
		unless ( ref $Token eq 'PPI::Token::Structure' ) {
			# Because _resolve_new_statement may well delay and
			# rollback itself, we need to add the delayed tokens early
			$self->_add_delayed( $Structure ) or return undef;

			# Determine the class for the Statement and create it
			my $_class = $self->_resolve_new_statement($Structure, $Token) or return undef;
			my $Statement = $_class->new( $Token ) or return undef;

			# Move the lexing down into the Statement
			$self->_lex_statement( $Statement ) or return undef;

			# Add the completed statement to our elements
			$self->_add_element( $Structure, $Statement ) or return undef;
			next;
		}

		# Is this the opening of another structure directly inside us?
		if ( $Token->_opens ) {
			### FIXME - Now, we really shouldn't be creating Structures
			###         inside of Structures. There really should be an
			###         Statement::Expression in here somewhere.
			# Determine the class for the structure and create it
			my $_class = $self->_resolve_new_structure($Structure, $Token) or return undef;
			my $Structure2 = $_class->new( $Token ) or return undef;

			# Move the lexing down into the Structure
			$self->_add_delayed( $Structure ) or return undef;
			$self->_lex_structure( $Structure2 ) or return undef;

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
				$Structure->_set_finish( $Token ) or return undef;
				return 1;
			}

			# Unmatched closing brace.
			# Either they typed the wrong thing, or haven't put
			# one at all. Either way it's an error we need to
			# somehow handle gracefully. For now, we'll treat it
			# as implicitly ending the structure. This causes the
			# least damage across the various reasons why this
			# might have happened.
			warn('Unexpected closing brace') if $self->{warnings};
			return $self->_rollback( $Token );
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

	# Handle a special case, where a statement is not fully resolved
	if ( ref $Parent eq 'PPI::Statement' ) {
		my $first  = $Parent->schild(0);
		my $second = $Parent->schild(1);
		if ( $first and $first->isa('Label') and ! $second ) {
			# It's a labelled statement
			if ( $STATEMENT_CLASSES{$second->content} ) {
				bless $Parent, $STATEMENT_CLASSES{$second->content};
			}
		}
	}

	# Add first the delayed, from the front, then the passed element
	foreach my $el ( @{$self->{delayed}}, $Element ) {
		$Parent->__add_element( $el );
	}

	# Clear the delayed elements if needed
	$self->{delayed} = [] if @{$self->{delayed}};

	1;
}

# Specifically just add any delayed tokens, if any.
sub _add_delayed {
	my $self = shift;
	my $Parent = isa($_[0], 'PPI::Node') ? shift : return undef;

	# Add any delayed
	foreach my $el ( @{$self->{delayed}} ) {
		$Parent->__add_element($el);
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

=pod

=head1 TO DO

- Add optional support for some of the more common soure filters

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

=head1 SEE ALSO

L<PPI>, L<PPI::Manual>

=head1 COPYRIGHT

Copyright 2004 - 2005 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
