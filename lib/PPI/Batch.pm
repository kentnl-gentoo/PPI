package PPI::Batch;

# Package to provide batch processing capabilities.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';
use File::Spec;

use vars qw{$VERSION};
BEGIN {
	$VERSION   = '0.814';
}

sub new {
	bless {
		files              => {},
		transforms         => [],
		transforms_applied => 0,
		callback           => undef,
		}, shift;
}

sub load {
	my $self = shift;
	my $filename = shift;
	return undef if $self->{files}->{$filename};

	# Create a new processor, and try to load the file
	my $PSP = Perl->load( $filename ) or return undef;

	# Add any pending transforms
	foreach ( @{ $self->{transforms} } ) {
		$PSP->add_transform( $_ ) or return undef;
	}

	# Add the PSP to the batch
	$self->{files}->{$filename} = $PSP;

	1;
}

sub load_directory {
	my $self = shift;
	my $directory = shift;
	return $self->_error( "You did not specify a directory" ) unless $directory;

	# Get the list of files from the directory
	my $files = File::Flat->list( $directory, {
		recursive => 1,
		custom => '\.p(?:m|l)$',
		} );
	unless ( defined $files ) {
		return $self->_error( "Error getting files for directory '$directory'" );
	}
	return 1 unless $files;

	# Add the files
	foreach my $file ( @$files ) {
		$self->load( File::Spec->catfile( $directory, $file )
		  or return $self->_error( "Error loading file '$file'" );
	}

	1;
}

# Specify a transform to apply
sub add_transform {
	my $self = shift;
	my $transform = shift;
	unless ( $transform eq 'tidy' ) {
		return $self->_error( "Invalid transform '$transform'" );
	}

	# If effects have already been applied, remove them
	if ( $self->{transforms_applied} ) {
		foreach ( keys %{$self->{files}} ) {
			$self->{files}->{$_}->{Tree} = undef;
			$self->{files}->{$_}->{transforms_applied} = 0;
		}
		$self->{transforms_applied} = 0;
	}

	# Add the transform
	push @{ $self->{transforms} }, $transform;
	foreach ( keys %{$self->{files}} ) {
		$self->{files}->{$_}->add_transform( $_ );
	}

	1;
}

sub set_callback {
	my $self = shift;
	my $code = ref $_[0] eq 'CODE' ? shift
		: return $self->_error( "Callback must be a CODE reference" );
	$self->{callback} = $code;
	1;
}





#####################################################################
# Main interface methods

# Provide a generic mechanism to pass through multiple commands.
# IF a filename is provided, that files xxxx is returned.
# Otherwise a hash ref of files -> xxxx is returned.
sub _multicommand {
	my $self = shift;
	my $command = shift;
	my $filename = shift;

	# Pass through to a specific file
	if ( $filename ) {
		# Does the file exist?
		if ( $self->{files}->{$filename} ) {
			# Pass through the command
			return $self->{files}->{$filename}->$command();
		} else {
			return $self->_error( "Filename '$filename' does not exist in the batch" );
		}
	}

	# Provide a generic tree
	my %hash = ();
	foreach ( keys %{$self->{files}} ) {
		# Trigger the callback if required
		if ( $self->{callback} ) {
			unless ( &{ $self->{callback} }( $self, $command, $filename ) ) {
				return $self->_error( "Command cancelled" );
			}
		}

		$hash{$_} = $self->{files}->{$_}->$command();
	}

	\%hash;
}

# Pass through some commands
sub document { shift->_multicommand( 'document', @_ ) }
sub tree     { shift->_multicommand( 'tree', @_ ) }
sub output   { shift->_multicommand( 'output', @_ ) }
sub to_string { shift->_multicommand( 'to_string', @_ ) }
sub html     { shift->_multicommand( 'html', @_ ) }
sub html_page { shift->_multicommand( 'html_page', @_ ) }


# Save the batch somewhere
sub save {
	my $self = shift;
	my $root = shift;
	my $filename = shift;
	unless ( isa( $filename, 'CODE' ) ) {
		return $self->_error( "For batch jobs, filename should be expressed as a code reference" );
	}
	my $command = shift or return undef;
	my @args = @_;

	# Get the filenames and content
	my $saveas = {};
	my $content = {};
	my @files = sort keys %{$self->{files}};
	foreach my $key ( @files ) {
		$saveas->{$key} = &{ $filename }( $key );
		unless ( defined $saveas->{$key} ) {
			return $self->_error( "Error getting location to save file '$key' to" );
		}

		# Trigger the callback if required
		if ( $self->{callback} ) {
			unless ( &{ $self->{callback} }( $self, $command, $key ) ) {
				return $self->_error( "Command cancelled" );
			}
		}

		$content->{$key} = $self->{files}->{$key}->$command( @args );
		unless ( defined $content->{$key} ) {
			return $self->_error( "Error getting content for file '$key'" );
		}

		# Remove the Processor to recover memory
		delete $self->{files}->{$key};
	}

	# Create and save the index file
	my $indexContent = $self->generate_index_page( $saveas );
	my $rv = File::Flat->save( File::Spec->catfile($root, 'index.html'), $indexContent );
	return $self->_error( "Error saving index file" ) unless defined $rv;

	# Go through and save the content
	foreach my $key ( @files ) {
		$rv = File::Flat->save( File::Spec->catfile($root, $saveas->{$key}), $content->{$key} );
		return $self->_error( "Error saving output for file '$key'" ) unless defined $rv;
	}

	1;
}

sub generate_index_page {
	my $self = shift;
	my $saveas = shift or return undef;

	# Create the links
	my $html = '';
	foreach ( sort keys %$saveas ) {
		$html .= "  <a href='$saveas->{$_}'>$_</a><br>\n";
	}

	# Wrap the links in the page
	$html = qq~<html>
<head>
  <title>Source Code Index</title>
</head>
<body bgcolor="#FFFFFF">
  <b>Source Code Browser Index</b><br>
  $html
</body>
</html>
~;

	$html;
}

1;