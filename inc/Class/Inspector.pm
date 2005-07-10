#line 1 "inc/Class/Inspector.pm - /usr/local/share/perl/5.8.4/Class/Inspector.pm"
package Class::Inspector;

# Class::Inspector contains a range of static methods that can be used
# to get information about a class ( or package ) in a convient way.

# In this module we use $class to refer to OUR class, and $name to
# refer to class names being passed to us to be acted upon.
#
# Almost everything in here can be done in other ways, but a lot
# involve playing with special varables, symbol table, and the like.

# Load Overhead: 236k

# We don't want to use strict refs, since we do a lot of things in here
# that arn't strict refs friendly.
use strict 'vars', 'subs';
use File::Spec ();

# Globals
use vars qw{$VERSION $RE_SYMBOL $RE_CLASS $UNIX};
BEGIN {
	$VERSION = '1.08';

	# Predefine some regexs
	$RE_SYMBOL  = qr/\A[^\W\d]\w*\z/;
	$RE_CLASS   = qr/\A[^\W\d]\w*(?:(?:'|::)[^\W\d]\w*)*\z/;

	# Are we on Unix?
	$UNIX = !! ( $File::Spec::ISA[0] eq 'File::Spec::Unix' );
}





#####################################################################
# Basic Methods

# Is the class installed on the machine, or rather, is it available
# to Perl. This is basically just a wrapper around C<resolved_filename>.
# It is installed if it is either already available in %INC, or we
# can resolve a filename for it.
sub installed {
	my $class = shift;
	!! ($class->loaded_filename($_[0]) or $class->resolved_filename($_[0]));
}

# Is the class loaded.
# We do this by seeing if the namespace is "occupied", which basically
# means either we can find $VERSION or @ISA, or at least one subroutine.
sub loaded {
	my $class = shift;
	my $name = $class->_class(shift) or return undef;

	# Handle by far the two most common cases
	# This is very fast and handles 99% of cases.
	return 1 if defined ${"${name}::VERSION"};
	return 1 if defined @{"${name}::ISA"};

	# Are there any symbol table entries other than other namespaces
	foreach ( keys %{"${name}::"} ) {
		next if substr($_, -2, 2) eq '::';
		return 1 if defined &{"${name}::$_"};
	}

	# No functions, and it doesn't have a version, and isn't anything.
	# As an absolute last resort, check for an entry in %INC
	my $filename = $class->_inc_filename($name);
	return 1 if defined $INC{$filename};

	'';
}

# Convert to a filename, in the style of
# First::Second -> First/Second.pm
sub filename {
	my $class = shift;
	my $name = $class->_class(shift) or return undef;
	File::Spec->catfile( split /(?:'|::)/, $name ) . '.pm';
}

# Resolve the full filename for the class.
sub resolved_filename {
	my $class = shift;
	my $filename = $class->_inc_filename(shift) or return undef;
	my @try_first = @_;

	# Look through the @INC path to find the file
	foreach ( @try_first, @INC ) {
		my $full = "$_/$filename";
		next unless -e $full;
		return $UNIX ? $full : $class->_inc_to_local($full);
	}

	# File not found
	'';
}

# Get the loaded filename for the class.
# Look the base filename up in %INC
sub loaded_filename {
	my $class = shift;
	my $filename = $class->_inc_filename(shift);
	$UNIX ? $INC{$filename} : $class->_inc_to_local($INC{$filename});
}





#####################################################################
# Sub Related Methods

# Get a reference to a list of function names for a class.
# Note: functions NOT methods.
# Only works if the class is loaded
sub functions {
	my $class = shift;
	my $name  = $class->_class(shift) or return undef;
	return undef unless $class->loaded( $name );

	# Get all the CODE symbol table entries
	my @functions = sort grep { /$RE_SYMBOL/o }
		grep { defined &{"${name}::$_"} }
		keys %{"${name}::"};
	\@functions;
}

# As above, but returns a ref to an array of the actual 
# CODE refs of the functions.
# The class must be loaded for this to work.
sub function_refs {
	my $class = shift;
	my $name  = $class->_class(shift) or return undef;
	return undef unless $class->loaded( $name );

	# Get all the CODE symbol table entries, but return
	# the actual CODE refs this time.
	my @functions = map { \&{"${name}::$_"} }
		sort grep { /$RE_SYMBOL/o }
		grep { defined &{"${name}::$_"} }
		keys %{"${name}::"};
	\@functions;
}

# Does a particular function exist
sub function_exists {
	my $class    = shift;
	my $name     = $class->_class( shift ) or return undef;
	my $function = shift or return undef;

	# Only works if the class is loaded
	return undef unless $class->loaded( $name );

	# Does the GLOB exist and its CODE part exist
	defined &{"${name}::$function"};
}

# Get all the available methods for the class
sub methods {
	my $class     = shift;
	my $name      = $class->_class( shift ) or return undef;
	my @arguments = map { lc $_ } @_;

	# Process the arguments to determine the options
	my %options = ();
	foreach ( @arguments ) {
		if ( $_ eq 'public' ) {
			# Only get public methods
			return undef if $options{private};
			$options{public} = 1;

		} elsif ( $_ eq 'private' ) {
			# Only get private methods
			return undef if $options{public};
			$options{private} = 1;

		} elsif ( $_ eq 'full' ) {
			# Return the full method name
			return undef if $options{expanded};
			$options{full} = 1;

		} elsif ( $_ eq 'expanded' ) {
			# Returns class, method and function ref
			return undef if $options{full};
			$options{expanded} = 1;

		} else {
			# Unknown or unsupported options
			return undef;
		}
	}

	# Only works if the class is loaded
	return undef unless $class->loaded( $name );

	# Get the super path ( not including UNIVERSAL )
	# Rather than using Class::ISA, we'll use an inlined version
	# that implements the same basic algorithm.
	my @path  = ();
	my @queue = ( $name );
	my %seen  = ( $name => 1 );
	while ( my $cl = shift @queue ) {
		push @path, $cl;
		unshift @queue, grep { ! $seen{$_}++ }
			map { s/^::/main::/; s/\'/::/g; $_ }
			( @{"${cl}::ISA"} );
	}

	# Find and merge the function names across the entire super path.
	# Sort alphabetically and return.
	my %methods = ();
	foreach my $namespace ( @path ) {
		my @functions = grep { ! $methods{$_} }
			grep { /$RE_SYMBOL/o }
			grep { defined &{"${namespace}::$_"} } 
			keys %{"${namespace}::"};
		foreach ( @functions ) {
			$methods{$_} = $namespace;
		}
	}

	# Filter to public or private methods if needed
	my @methodlist = sort keys %methods;
	@methodlist = grep { ! /^\_/ } @methodlist if $options{public};
	@methodlist = grep { /^\_/ }   @methodlist if $options{private};

	# Return in the correct format
	@methodlist = map { "$methods{$_}::$_" } @methodlist if $options{full};
	@methodlist = map { 
		[ "$methods{$_}::$_", $methods{$_}, $_, \&{"$methods{$_}::$_"} ] 
		} @methodlist if $options{expanded};

	\@methodlist;
}





#####################################################################
# Children Related Methods

# These can go undocumented for now, until I decide if its best to
# just search the children in namespace only, or if I should do it via
# the file system.

# Find all the loaded classes below us
sub children {
	my $class = shift;
	my $name  = $class->_class(shift) or return ();

	# Find all the Foo:: elements in our symbol table
	no strict 'refs';
	map { "${name}::$_" } sort grep { s/::$// } keys %{"${name}::"};
}

# As above, but recursively
sub recursive_children {
	my $class    = shift;
	my $name     = $class->_class(shift) or return ();
	my @children = ( $name );

	# Do the search using a nicer, more memory efficient 
	# variant of actual recursion.
	my $i = 0;
	no strict 'refs';
	while ( my $namespace = $children[$i++] ) {
		push @children, map { "${namespace}::$_" }
			grep { ! /^::/ } # Ignore things like ::ISA::CACHE::
			grep { s/::$// }
			keys %{"${namespace}::"};
	}

	sort @children;
}





#####################################################################
# Private Methods

# Checks and expands ( if needed ) a class name
sub _class {
	my $class = shift;
	my $name  = shift or return '';

	# Handle main shorthand
	return 'main' if $name eq '::';
	$name =~ s/\A::/main::/;

	# Check the class name is valid
	$name =~ /$RE_CLASS/o ? $name : '';
}

# Create a INC-specific filename, which always uses '/'
# regardless of platform.
sub _inc_filename {
	my $class = shift;
	my $name  = $class->_class(shift) or return undef;
	join( '/', split /(?:'|::)/, $name ) . '.pm';
}

# Convert INC-specific file name to local file name
sub _inc_to_local {
	my $class = shift;

	# Shortcut in the Unix case
	return $_[0] if $UNIX;

	# Get the INC filename and convert
	my $inc_name = shift or return undef;
	my ($vol, $dir, $file) = File::Spec::Unix->splitpath( $inc_name );
	$dir = File::Spec->catdir( File::Spec::Unix->splitdir( $dir || "" ) );
	File::Spec->catpath( $vol, $dir, $file || "" );
}

1;

__END__

#line 509
