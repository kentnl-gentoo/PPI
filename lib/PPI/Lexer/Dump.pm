package PPI::Lexer::Dump;

# Simple package to provide a dumped version of a PPI::Element struct,
# usefull for debugging.

use strict;
use UNIVERSAL 'isa';
use Scalar::Util ();





# Create a new dumper object, configuring the display options.
sub new {
	my $class = shift;
	my $root = isa( $_[0], 'PPI::Element' ) ? shift : return undef;

	# Create the object
	my $self = bless {
		root    => $root,
		display => {
			memaddr    => '', # Show the refaddr of the item
			indent     => 1,  # Indent the structures
			class      => 1,  # Show the object class
			content    => 1,  # Show the object contents
			whitespace => 1,  # Show whitespace tokens
			comments   => 1,  # Show comment tokens
			},
		}, $class;

	# Handle the options
	my %options = map { lc $_ } @_;
	foreach ( keys %{$self->{display}} ) {
		if ( exists $options{$_} ) {
			$self->{display}->{$_} = !! $options{$_};
		}
	}

	$self;
}

sub print { shift->dump_element }

# The function/class method shortcut 
sub dump_element {
	my $self = ref $_[0] ? shift : shift->new(shift);
	my $element = isa( $_[0], 'PPI::Element' ) ? shift : $self->{root};
	my $indent = shift || '';

	# Print the element if needed
	my $show = 1;
	if ( isa( $element, 'PPI::Token::Whitespace' ) ) {
		$show = 0 unless $self->{display}->{whitespace};
	} elsif ( isa( $element, 'PPI::Token::Comment' ) ) {
		$show = 0 unless $self->{display}->{comments};
	}
	print $self->element_string( $element, $indent ) if $show;

	# Recurse into our children
	if ( isa( $element, 'PPI::ParentElement' ) ) {
		my $child_indent = $indent . '  ';
		foreach my $child ( @{$element->{elements}} ) {
			$self->dump_element( $child, $child_indent );
		}
	}

	1;
}

sub element_string {
	my $self = ref $_[0] ? shift : shift->new(shift);
	my $element = isa( $_[0], 'PPI::Element' ) ? shift : $self->{root};
	my $indent = shift || '';
	my $string = '';

	# Add the memory location
	if ( $self->{display}->{memaddr} ) {
		$string .= Scalar::Util::refaddr($element) . '  ';
	}

	# Add the indent
	if ( $self->{display}->{indent} ) {
		$string .= $indent;
	}

	# Add the class name
	if ( $self->{display}->{class} ) {
		$string .= ref($element);
	}

	if ( isa( $element, 'PPI::Token' ) ) {
		# Add the content
		if ( $self->{display}->{content} ) {
			my $content = $element->content;
			$content =~ s/\n/\\n/g;
			$content =~ s/\t/\\t/g;
			$string .= "  \t'$content'";
		}

	} elsif ( isa( $element, 'PPI::Structure' ) ) {
		# Add the content
		if ( $self->{display}->{content} ) {
			my $start = $element->start
				? $element->start->content
				: '???';
			my $finish = $element->finish
				? $element->finish->content
				: '???';
			$string .= "  \t$start ... $finish";
		}
	}

	$string . "\n";
}
	
1;
