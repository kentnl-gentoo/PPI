package PPI::Lexer::Dump;

# Simple package to provide a dumped version of a PPI::Element struct,
# usefull for debugging.

use strict;
use UNIVERSAL 'isa';
use Scalar::Util ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.817';
}





# Create a new dumper object, configuring the display options.
sub new {
	my $class = shift;
	my $root = isa( $_[0], 'PPI::Element' ) ? shift : return undef;

	# Create the object
	my $self = bless {
		root    => $root,
		display => {
			memaddr    => '', # Show the refaddr of the item
			indent     => 2,  # Indent the structures
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
			if ( $_ eq 'indent' ) {
				$self->{display}->{indent} = $options{$_};
			} else {
				$self->{display}->{$_} = !! $options{$_};
			}
		}
	}

	$self->{indent_string} = join '', (' ' x $self->{display}->{indent});

	$self;
}





#####################################################################
# Generate the dump

# The function/class method shortcut 
sub dump_array_ref {
	my $self = ref $_[0] ? shift : shift->new(shift);
	my $element = isa( $_[0], 'PPI::Element' ) ? shift : $self->{root};
	my $indent = shift || '';
	my $output = shift || [];

	# Print the element if needed
	my $show = 1;
	if ( isa( $element, 'PPI::Token::Whitespace' ) ) {
		$show = 0 unless $self->{display}->{whitespace};
	} elsif ( isa( $element, 'PPI::Token::Comment' ) ) {
		$show = 0 unless $self->{display}->{comments};
	}
	push @$output, $self->_element_string( $element, $indent ) if $show;

	# Recurse into our children
	if ( isa( $element, 'PPI::Node' ) ) {
		my $child_indent = $indent . $self->{indent_string};
		foreach my $child ( @{$element->{elements}} ) {
			$self->dump_array_ref( $child, $child_indent, $output );
		}
	}

	$output;
}

sub _element_string {
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
	
	$string;
}





#####################################################################
# Alternative ways to get it

sub dump_array {
	my $array_ref = shift->dump_array_ref;
	isa( $array_ref, 'ARRAY' ) ? @$array_ref : ();
}

sub dump_string { join '', map { "$_\n" } shift->dump_array }

sub print { print shift->dump_string }

1;
