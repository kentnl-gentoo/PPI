package PPI::Batch;

# Package to provide batch processing capabilities.

use strict;
use UNIVERSAL 'isa';
use base 'PPI::Common';

sub new {
	my $class = shift;
	
	my $self = {
		files => {},
		transforms => [],
		transforms_applied => 0,
		callback => undef,
		};
	bless $self, $class;
	
	return $self;
}

sub load {
	my $self = shift;
	my $filename = shift;
	return undef if $self->{files}->{$filename};
	
	# Create a new processor, and try to load the file
	my $PSP = Perl->load( $filename ) or return undef;
	
	# Add any pending transforms
	foreach ( @{ $self->{transforms} } ) {
		$PSP->addTransform( $_ ) or return undef;
	}
	
	# Add the PSP to the batch
	$self->{files}->{$filename} = $PSP;
	
	return 1;
}

sub loadDirectory {
	my $self = shift;
	my $directory = shift;
	return $self->andError( "You did not specify a directory" ) unless $directory;
	
	# Get the list of files from the directory
	my $files = File::Flat->list( $directory, {
		recursive => 1,
		custom => '\.p(?:m|l)$',
		} );
	unless ( defined $files ) {
		return $self->andError( "Error getting files for directory '$directory'" );
	}
	return 1 unless $files;
	
	# Add the files
	foreach my $file ( @$files ) {
		$self->load( "$directory/$file" )
		  or return $self->andError( "Error loading file '$file'" );
	}
	
	# Done
	return 1;
}

# Specify a transform to apply
sub addTransform {
	my $self = shift;
	my $transform = shift;
	unless ( $transform eq 'tidy' ) {
		return $self->andError( "Invalid transform '$transform'" );
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
		$self->{files}->{$_}->addTransform( $_ );
	}
	
	return 1;
}

sub setCallback {
	my $self = shift;
	my $code = shift;
	unless ( isa( $code, 'CODE' ) ) {
		return $self->andError( "Callback must be a CODE reference" );
	}
	
	$self->{callback} = $code;
	return 1;
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
			return $self->andError( "Filename '$filename' does not exist in the batch" );
		}
	}
		
	# Provide a generic tree
	my %hash = ();
	foreach ( keys %{$self->{files}} ) {
		# Trigger the callback if required
		if ( $self->{callback} ) {
			unless ( &{ $self->{callback} }( $self, $command, $filename ) ) {
				return $self->andError( "Command cancelled" );
			}
		}
		
		$hash{$_} = $self->{files}->{$_}->$command();
	}
	
	return \%hash;
}

# Pass through some commands
sub document { shift->_multicommand( 'document', @_ ) }
sub tree     { shift->_multicommand( 'tree', @_ ) }
sub output   { shift->_multicommand( 'output', @_ ) }
sub toString { shift->_multicommand( 'toString', @_ ) }
sub html     { shift->_multicommand( 'html', @_ ) }
sub htmlPage { shift->_multicommand( 'htmlPage', @_ ) }


# Save the batch somewhere
sub save {
	my $self = shift;
	my $root = shift;
	my $filename = shift;
	unless ( isa( $filename, 'CODE' ) ) {
		return $self->andError( "For batch jobs, filename should be expressed as a code reference" );
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
			return $self->andError( "Error getting location to save file '$key' to" );
		}

		# Trigger the callback if required
		if ( $self->{callback} ) {
			unless ( &{ $self->{callback} }( $self, $command, $key ) ) {
				return $self->andError( "Command cancelled" );
			}
		}
	
		$content->{$key} = $self->{files}->{$key}->$command( @args );
		unless ( defined $content->{$key} ) {
			return $self->andError( "Error getting content for file '$key'" );
		}
		
		# Remove the Processor to recover memory
		delete $self->{files}->{$key};
	}

	# Create and save the index file
	my $indexContent = $self->generateIndexPage( $saveas );
	my $rv = File::Flat->save( "$root/index.html", $indexContent );
	return $self->andError( "Error saving index file" ) unless defined $rv;
	
	# Go through and save the content
	foreach my $key ( @files ) {
		$rv = File::Flat->save( "$root/$saveas->{$key}", $content->{$key} );
		return $self->andError( "Error saving output for file '$key'" ) unless defined $rv;
	}
	
	# Done
	return 1;
}		

sub generateIndexPage {
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

	return $html;
}

1;