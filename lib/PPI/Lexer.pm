package PPI::Lexer;

# The PPI::Lexer package does some rudimentary structure analysis of
# the token stream produced by the tokenizer.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';

sub new {
	my $class = shift;
	
	my $self = {
		Document => undef,
		tree => undef,
		treecursor => undef,
		treeLoaded => 0,
		};
	bless $self, $class;
	
	# Initialize
	$self->init( shift ) or return undef;
	
	return $self;
}	





#####################################################################
# Basic getters and setters

sub getDocument { $_[0]->{Document} }
sub top { $_[0]->{tree} }





#####################################################################
# Large functional blocks

# Initialise the Lexer with a tokenizer
sub init {
	my $self = shift;
	my $createFrom = shift;
	if ( isa( $createFrom, 'PPI::Tokenizer' ) ) {
		# Build a Lexer Document from the Tokenizer
		my $Document = PPI::Document->new( $self->{tokenizer} )
			or return $self->andError( "Error building Document from Tokenizer" );
		$self->{Document} = $Document;

	} elsif ( isa( $createFrom, 'PPI::Document' ) ) {
		$self->{Document} = $createFrom;
		
	} else {
		return $self->andError( "You passed an invalid argument to initialise the lexer with." );
	}

	# Init the Lexer tree
	$self->{tree} = PPI::Lexer::Tree->new();
	$self->{tree}->setLexer( $self );

	return 1;
}





#####################################################################
# Tree parser

sub getTree {
	my $self = shift;
	unless ( $self->{treeloaded} ) {
		$self->_loadTree() or return undef;
	}
	return $self->top;
}

sub _loadTree {
	my $self = shift;

	# Classify the comments
	$self->_loadTreeClassifyComments() or return undef;
	
	# Do the initial block scanning and tree building
	$self->_loadTreeInitialBlockParse() or return undef;
	
	# Next, go through and classify the blocks
	$self->_loadTreeClassifyBlocksWithin( $self->{tree} ) or return undef;
	
	# Done
	$self->{treeloaded} = 1;
	return 1;
}	

# Tag some additional meta-data on comments so we will know how to
# better lay them out later
sub _loadTreeClassifyComments {
	my $self = shift;
	my $d = $self->{Document};

	# Iterate over the tokens
	$d->enableIndex; 
	$d->resetCursor;
	while ( my $token = $d->nextToken ) {
		# Is this a comment
		next unless $token->{class} eq 'Comment';
		
		# Ignore non-line comments
		next unless $token->{tags}->{line};
		
		# Is it a comment at the top of a set of comments
		my $before = $d->relativeToken( $token, -1 );
		return undef unless defined $before;
		unless ( $before 
		     and $before->{class} eq 'Comment' 
		     and $before->{tags}->{line} ) {
			$token->{tags}->{top} = 1;
		}

		# Is there a gap below it
		my $after = $d->relativeToken( $token, 1 );
		return undef unless defined $after;
		if ( $after 
		 and $after->{class} eq 'Base'
		 and $after->{content} =~ /\n$/ ) {
		     	$token->{tags}->{bottom} = 1;
		}				
	}
	
	# Done
	return 1;
}

# Build the initial tree structure via the block scan
use vars qw{$openOrClose $matching};
BEGIN {
	$openOrClose = {
		'{' => 'open',
		'}' => 'close',
		'[' => 'open',
		']' => 'close',
		'(' => 'open',
		')' => 'close',
		};
	$matching = {
		'{' => '}',
		'}' => '{',
		'[' => ']',
		']' => '[',
		'(' => ')',
		')' => '(',
		};
}
sub _loadTreeInitialBlockParse {
	my $self = shift;
	my $d = $self->{Document};
	
	# Get ready to start
	$self->{treecursor} = $self->{tree};
	
	my ($token, $type, $Block);
	$d->resetCursor;
	while ( $token = $d->nextToken ) {
		# Handle a normal token ( most likely )
		unless ( $token->{class} eq 'Structure' ) {
			# Add token to current block
			$self->{treecursor}->addToken( $token ) or
				return $self->lexError( $token, "Error adding token to block" );
			next;
		}
		
		if ( $token->{content} eq ';' ) {
			### Just add normally for now
			$self->{treecursor}->addToken( $token ) or
				return $self->lexError( $token, "Error adding token to block" );
			next;
		}			
		
		# Handle structure changes
		$type = $openOrClose->{ $token->{content} };
		if ( $type eq 'open' ) {
			# Open a new block
			
			# Create a new block
			$Block = PPI::Lexer::Block->new( $token )
				or return $self->lexError( $token, "Error creating block" );

			# Add it to the current block, and update the cursor
			$self->{treecursor}->addElement( $Block )
				or return $self->lexError( $token, "Error creating block" );
			$self->{treecursor} = $Block;
			
		} elsif ( $type eq 'close' ) {
			unless ( $matching->{ $token->{content} } ) {
				return $self->lexError( $token, "Unexpected closing '$token->{content}'" );				
			}
			
			# Close the current block and update the cursor
			$self->{treecursor}->setCloseToken( $token )
				or return $self->lexError( $token, "Failed to close block" );
			$self->{treecursor} = $self->{treecursor}->parent;
		} else {
			return $self->lexError( $token, "Unknown Structure token content '$token->{content}'" );
		}
	}

	return 1;
}

# Classify the blocks based on their surroundings
sub _loadTreeClassifyBlocksWithin {
	my $self = shift;
	my $container = shift;
	
	# Get all the significant elements inside the block
	my @elements = grep { $_->significant } @{$container->{elements}};
	
	# Iterate through and looks for blocks to classify
	my ( $element, $type, $previous, $previous2, $class );
	foreach my $p ( 0 .. $#elements ) {
		$element = $elements[$p];
		next unless isa( $element, 'PPI::Lexer::Block' );
		
		# It's a block
		$type = $element->{type};
		$previous = $elements[$p-1] || PPI::Lexer::Token->emptyToken;
		$previous2 = $elements[$p-2] || PPI::Lexer::Token->emptyToken;
		if ( $type eq '()' ) {
			if ( $previous->is_a( 'Bareword' )
			 and $previous2->is_a( 'Bareword', 'sub' ) ) {
				$class = 'SubPrototype';

			} elsif ( $previous->{class} eq 'Bareword' ) {
				if ( $previous->{content} eq 'if'
				  or $previous->{content} eq 'elsif'
				  or $previous->{content} eq 'unless'
				  or $previous->{content} eq 'while'
				  or $previous->{content} eq 'for'
				  or $previous->{content} eq 'foreach' ) {
					$class = 'Condition';
					
				} elsif ( $previous->{content} eq 'my' ) {
					$class = 'List';
				} else {
					$class = 'Arguments';
				}
			} elsif ( $previous->is_a( '{}' ) ) {
				$class = 'Arguments';
			} else {
				my $previous3 = $elements[$p-3] || PPI::Lexer::Token->emptyToken;
				if ( 
					( $previous3->is_a( 'Bareword', 'for' ) or $previous3->is_a( 'Bareword', 'foreach' ) )
					and 
					( $previous2->is_a( 'Bareword', 'my' ) or $previous2->is_a( 'Bareword', 'local' ) )
				 	and 
				 	$previous->is_a( 'Symbol' )
				) {
					$class = 'ForCondition';
				} elsif (
					( $previous2->is_a( 'Bareword', 'for' ) or $previous2->is_a( 'Bareword', 'foreach' ) )
					and 
				 	$previous->is_a( 'Symbol' )
				) {
					$class = 'ForCondition';
				} else {
					$class = 'Precedence';
				}
			}
			
		} elsif ( $type eq '[]' ) {
			if ( $previous->is_a( 'Operator', '->' ) 
			  or $previous->is_a( 'Symbol' ) 
			  or $previous->is_a( 'HashKey' )
			  or $previous->is_a( 'ArrayLey' )
			  ) {
				$class = 'ArrayKey';
			} else {
				$class = 'AnonArrayRef';
			}
			
		} elsif ( $type eq '{}' ) {
			if ( $previous->{class} eq 'Bareword' ) {
				if ( $previous->{content} eq 'sub' ) {
					$class = 'AnonymousSub';
				} elsif ( $previous->{content} eq 'else' ) {
					$class = 'Conditional';
				} elsif ( $previous->{content} eq 'BEGIN'
				       or $previous->{content} eq 'INIT'
				       or $previous->{content} eq 'END' ) {
					$class = 'TimingBlock';
				} elsif ( $previous->{content} eq 'map' 
				       or $previous->{content} eq 'grep'
				       or $previous->{content} eq 'sort' ) {
				       	$class = 'MapGrepSort';
				} elsif ( $previous2->is_a( 'Bareword', 'sub' )
				       or $previous2->is_a( 'SubPrototype' ) ) {
				       	$class = 'Sub';
				} elsif ( $previous->{content} eq 'eval' ) {
					$class = 'Scope';
				} else {
					# This is something of a guess
					$class = 'AnonHashRef';
				}
			} elsif ( $previous->is_a( 'Operator', '->' ) 
			       or $previous->is_a( 'Symbol' )
			       or $previous->is_a( 'HashKey' )
			       or $previous->is_a( 'ArrayKey' ) ) {
				$class = 'HashKey';
			} elsif ( $previous->is_a( '()', 'SubPrototype' ) ) {
				$class = 'Sub';
			} elsif ( $previous->is_a( '()', 'Condition' ) ) {
				$class = 'Conditional';
			} elsif ( $previous->is_a( '()', 'ForCondition' ) ) {
				$class = 'ForBlock';
			} elsif ( $previous->is_a( 'Cast' ) ) {
				$class = 'CastSelector';
				
			### MORE NEEDED HERE
			} else {
				$class = 'Scope';
			}
		} else {
			# Huh?
			return $self->andError( "Unexpected block type '$type'" );
		}
		
		unless ( $element->setClass( $class ) ) {
			return $self->andError( "Error setting class for Block at position $p" );
		}
		
		# Now do inside the block itself
		unless ( $self->_loadTreeClassifyBlocksWithin( $element ) ) {
			return $self->andError( "Error classifying within Block $p" );
		}
	}
	return 1;
}

sub lexError {
	my $self = shift;
	my $element = shift;
	my $message = shift;
	
	if ( isa( $element, 'PPI::Lexer::Block' ) ) {
		$element = $element->getOpenToken;
	}
	return $self->andError( "$message at " . $self->{Document}->getLineCharText( $element ) );
}

1;
