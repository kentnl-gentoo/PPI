package PPI::Transform::Tidy;

# The PPI::Transform::Tidy package contains functionality to
# take a PPI::Lexer::Tree and tidy up the code layout

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';

# The class uses a constructor behind the scenes to maintain
# state data. Do not call this method directly.
sub new {
	my $class = shift;
	my $Tree = shift;
	return undef unless isa( $Tree, 'PPI::Lexer::Tree' );
	
	# Create the object
	my $self = {
		Tree => $Tree,
		depth => 0,
		};
	return bless $self, $class;
}





#####################################################################
# Main methods

# Takes a PPI::Lexer::Tree as an argument and alters it.
# Returns true on success.
# Returns undef on error.
sub tidyTree {
	my $class = shift;
	my $Tree = shift;
	unless ( isa( $Tree, 'PPI::Lexer::Tree' ) ) {
		return $class->_error( "You did not pass a Lexer Tree to tidy" );
	}
	
	# Create the instance
	my $Tidier = $class->new( $Tree );
	
	# First remove all the whitespace
	$Tidier->{Tree}->remove_whitespace or return undef;
	
	# Start the actual tidy
	$Tidier->{tmp}->{depth} = 0;
	$Tidier->_tidyTreeBlock( $Tidier->{Tree} ) or return undef;
	delete $Tidier->{tmp};
	
	# Done
	return 1;
}





#####################################################################
# Working methods

# Tidy a single block
sub _tidyTreeBlock {
	my $self = shift;
	my $Block = shift;
	
	# Never do anything to empty blocks
	if ( ! scalar @{ $Block->{elements} } ) {
		return 1;
	}		

	# Prepare
	my $tmp = {
		first => 1,
		newline => ($Block->{type} eq 'top' ? 1 : 0),
		newelements => [],
		};
	$self->{tmp}->{$Block} = $tmp;		

	# Get the rule for the current block and apply
	my $blockRule = $self->_getBlockRule( $Block ) or return undef;	
	my $tokens = $self->_tidyTreeApplyRule( $Block, $blockRule->[0] ) or return undef;
	
	# Handle our elements
	my $previous = undef;
	foreach my $element ( @{ $Block->{elements} } ) {
		# Handle the join whitespace
		my $joinRule = '';
		if ( $tmp->{first} ) {
			# Do nothing
		
		} elsif ( $previous->is_a( 'Operator', ',' ) ) {
			# Special handling for commas
			if ( $tmp->{newlineOnComma} 
			  or $Block->{class} eq 'AnonHashRef'
			) { 
				$joinRule = 'n';
			} else {
				$joinRule = 's';
			}
		
		} else {
			# Get the generic join rule
			$joinRule = $self->_getJoinRule( $previous, $element );
			return undef unless defined $joinRule;
		
		}

		# Add the tokens for the rule
		$tokens = $self->_tidyTreeApplyRule( $Block, $joinRule );

		# Recurse down blocks
		if ( isa( $element, 'PPI::Lexer::Block' ) ) {
			$self->_tidyTreeBlock( $element ) or return undef;
		} 

		# Handle comment specially
		if ( $element->{class} eq 'Comment' ) {
			if ( $element->{tags}->{line} ) {
				unless ( $tmp->{first} == 1 ) {
					my $linesToAdd = $self->_linesToAdd( $tmp, $element );
					if ( $linesToAdd > 0 ) {
						push @{ $tmp->{newelements} }, ($self->newBlockNewline) x $linesToAdd;
						$tmp->{newline} = 1;
					}
				}					

				# Add the comment				
				$self->_tidyTreeAddTokens( $Block, $element );
			} else {
				# Add as normal
				$self->_tidyTreeAddTokens( $Block, $element );
			}
			
			# All comments get a trailing carriage return
			$self->_tidyTreeAddTokens( $Block, $self->newBlockNewline() );
			
			# Add an extra line below the comments
			if ( $element->{tags}->{bottom} ) {
				push @{ $tmp->{newelements} }, $self->newBlockNewline;
			}
		} else {
			# Add the current element
			$self->_tidyTreeAddTokens( $Block, $element );
		}
		
		# Special stuff to handle commas in hash and arrays
		if ( $element->is_a( 'Operator', '=>' ) ) {
			$tmp->{newlineOnComma} = 1;
		} elsif ( $element->is_a( 'Structure ;' ) ) {
			$tmp->{newlineOnComma} = 0;
		}
		
		$tmp->{first} = 0 if $tmp->{first};
		$previous = $element;
	}

	# Handle the "before close token" case
	$tokens = $self->_tidyTreeApplyRule( $Block, $blockRule->[1] );
	
	# If the very last token is a newline, we need to add an indent
	my $lastElement = $tmp->{newelements}->[-1];
	if ( $lastElement and $lastElement->{content} eq "\n" ) {
		push @{ $tmp->{newelements} }, $self->newBlockIndent();
	}
	
	# Done
	$Block->{elements} = $tmp->{newelements};
	delete $self->{tmp}->{$Block};
	return 1;
}

sub _tidyTreeAddTokens {
	my $self = shift;
	my $Block = shift;
	my $tmp = $self->{tmp}->{$Block};
	
	# Add the tokens
	foreach my $token ( @_ ) {
		if ( $token->{content} eq "\n" ) {
			$tmp->{newline} = 1;
		} elsif ( $tmp->{newline} ) {
			push @{ $tmp->{newelements} }, $self->newBlockIndent() if $self->{tmp}->{depth};
			$tmp->{newline} = 0;
		}
		push @{ $tmp->{newelements} }, $token;
	}
	
	return 1;
}

sub _linesToAdd {
	my $self = shift;
	my $tmp = shift;
	my $element = shift;
	my ($token, $previous) = ();

	# Find the existing blanks and previous token
	my $current = 0;
	for ( my $i = scalar(@{$tmp->{newelements}}) - 1; $i > 0; $i-- ) {
		$token = $tmp->{newelements}->[$i];
		if ( $token->{content} eq "\n" ) {
			$current++;
		} elsif ( $token->{class} eq 'Base' ) {
			next;
		} else {
			$previous = $token;
			last;
		}
	}
	
	# Work out the amount we want
	my $wantSpaces = 1;
	if ( $element->{tags}->{top} ) {
		$wantSpaces = 2;
	} elsif ( $previous->{class} ne 'Comment' ) {
		$wantSpaces = 2;
	} elsif ( $previous->{class} eq 'Comment' and $previous->{tags}->{bottom} ) {
		$wantSpaces = 2;
	}
	if ( $element->{content} =~ /^#{5,}$/ ) {
		$wantSpaces = 6;
	}
	
	return $wantSpaces - $current;
}
	
use vars qw{$defaultBlockRule};
BEGIN { $defaultBlockRule = [ undef, undef ] }
sub _getBlockRule {
	my $self = shift;
	my $Block = shift;
	my $type = $Block->{type};
	my $class = $Block->{class};
	
	# Get the rules for blocks
	my $rules = $self->getBlockRuleMap or return undef;
	return $defaultBlockRule unless $rules->{$type};
	return $defaultBlockRule unless $rules->{$type}->{$class};
	return $rules->{$type}->{$class};
}

sub _getJoinRule {
	my $self = shift;
	my $left = shift;
	my $right = shift;
	$left = $left->get_summary_strings();
	$right = $right->get_summary_strings();

	# Get the rules
	my $rules = $self->getJoinRuleSet() or return undef;
	
	# Try to match the left and right values
	foreach my $rule ( @$rules ) {
		if ( 
			($left->[0] eq $rule->[0] or $left->[1] eq $rule->[0] or $rule->[0] eq '*')
			and
			($right->[0] eq $rule->[1] or $right->[1] eq $rule->[1] or $rule->[1] eq '*')
		) {
			return $rule->[2];
		}
	}
	
	return undef;
}

sub _tidyTreeApplyRule {
	my $self = shift;
	my $Block = shift;
	my $rule = shift;
	my $tmp = $self->{tmp}->{$Block};
	my $indentRules = $self->getIndentRules();
	
	# Split into characters
	foreach ( split //, $rule ) {
		next if $_ eq '';
		if ( $_ eq '>' ) {
			$self->{tmp}->{depth} += $indentRules->{width};
		} elsif ( $_ eq '<' ) {
			$self->{tmp}->{depth} -= $indentRules->{width};
		} elsif ( $_ eq 's' ) {
			$self->_tidyTreeAddTokens( $Block, $self->newBlockSpace() );			
		} elsif ( $_ eq 'n' ) {
			$self->_tidyTreeAddTokens( $Block, $self->newBlockNewline() );			
		} else {
			return $self->_error( "Unknown rule character '$rule'" );
		}
	}
	return 1;
}




use vars qw{$indentRules};
BEGIN {
	# This controls indenting.
	$indentRules = {
		width => 8,
		useTab => 0,
		};
}
sub getIndentRules { return $indentRules; }



use vars qw{$blockRuleMap};
BEGIN {
	# The block rules work as follows.
	# Each block context is dealt with seperately.
	# The rule contains four value, which represent
	#    1. Before the open token
	#    2. After the open token
	#    3. Before the end token
	#    4. After the end token
	# The individual rules are
	#    undef - Nothing
	#    's'   - Add a whitespace ( add more space for more space )
	#    'n'  - Add a new line
	#    '>'   - "Indent" = Add to the tab depth
	#    '<'   - "Outdent" = Subtract from the tab depth
	# 
	# These rules can be combined in any order
	$blockRuleMap = {
		'{}' => {
			HashKey     => [ undef, undef ],
			Conditional => [ '>n', '<n' ],
			Scope       => [ '>n', '<n' ],
			Sub         => [ '>n', '<n' ],
			TimingBlock => [ '>n', '<n' ],
			MapGrepSort => [ 's', 's' ],
			AnonHashRef => [ 's', 's' ],
			CastSelecor => [ undef, undef ],
			ForBlock => [ '>n', '<n' ],
			},
		'[]' => {
			ArrayKey    => [ undef, undef ],
			AnonHashRef => [ undef, undef ],
			},
		'()' => {
			Precedence  => [ undef, undef ],
			Condition => [ 's', 's' ],
			ForCondition => [ 's', 's' ],
			},
		};
}
sub getBlockRuleMap { $blockRuleMap }




use vars qw{$joinRuleSet};
BEGIN {
	# The join rules describe how individual tokens are joined together. 
	# Each rule is comprised of three parts.
	# The first part represents the token on the left of the join.
	# The second part represents the token on the right of the join.
	# The third is a rule string as in the block rules above.
	#
	# Rules are searched from beginning to end, until a match is found.
	$joinRuleSet = [
		# Control structure related
		[ 'Conditional', 'Bareword elsif', 's' ],
		[ 'Conditional', 'Bareword else', 's' ],
		[ 'Conditional', '*', 'n' ],
		[ 'TimingBlock', '*', 'n' ],
		[ '*', 'Condition', 's' ],
		
		# Semi-colon related
		[ '*', 'Structure ;', '' ],
		[ 'Structure ;', '*', 'n' ],

		# Sub related
		[ 'Sub', '*', 'nn' ],
		[ '*', 'Arguments', '' ],
				
		# Make sure comments don't do anything
		[ 'Comment', '*', '' ],
		[ '*', 'Comment', '' ],
		
		# Operator related
		[ '*', 'Operator ->', '' ],
		[ 'Operator ->', '*', '' ],
		[ 'Cast', '*', '' ],
		[ '*', 'Operator ,', '' ],
		[ '*', 'ArrayKey', '' ],
		[ 'HashKey', 'HashKey', '' ],
		[ 'HashKey', 'ArrayKey', '' ],
		[ 'ArrayKey', 'HashKey', '' ],
		[ 'ArrayKey', 'ArrayKey', '' ],
		
		# Pre/post increment/decrement
		[ 'Symbol', 'Operator ++', '' ],
		[ 'Symbol', 'Operator --', '' ],
		[ 'HashKey', 'Operator ++', '' ],
		[ 'HashKey', 'Operator --', '' ],
		[ 'ArrayKey', 'Operator ++', '' ],
		[ 'ArrayKey', 'Operator --', '' ],
		[ 'Operator ++', 'Symbol', '' ],
		[ 'Operator --', 'Symbol', '' ],
		[ 'Operator ++', 'HashKey', '' ],
		[ 'Operator --', 'HashKey', '' ],
		[ 'Operator ++', 'ArrayKey', '' ],
		[ 'Operator --', 'ArrayKey', '' ],
	
		# Default rule
		[ '*', '*', 's' ],
		];
}
sub getJoinRuleSet { $joinRuleSet }
		
		
	

#####################################################################
# Block Generators

sub newBlockSpace   { PPI::Lexer::Token->new( 'Base', defined $_[1] ? $_[1] : ' ' ) }
sub newBlockNewline { PPI::Lexer::Token->new( 'Base', "\n" ) }
sub newBlockIndent  { PPI::Lexer::Token->new( 'Base', ' ' x $_[0]->{tmp}->{depth} ) }

1;
