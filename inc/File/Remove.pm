#line 1
package File::Remove;

use strict;
use vars qw(@EXPORT_OK @ISA $VERSION $debug $unlink $rmdir);
BEGIN {
	$VERSION   = '0.34';
	@ISA       = qw(Exporter);
	@EXPORT_OK = qw(remove rm trash); # nothing by default :)
}

# If we ever need a Mac::Glue object,
# we will want to cache it.
my $glue;

use File::Spec ();
use File::Path ();
use File::Glob qw(bsd_glob);

sub expand (@) {
	map { File::Glob::bsd_glob($_) } @_;
}

# Are we on VMS?
# If so copy File::Path and assume VMS::Filespec is loaded
use constant IS_VMS => $^O eq 'VMS';





#####################################################################
# Main Functions

# acts like unlink would until given a directory as an argument, then
# it acts like rm -rf ;) unless the recursive arg is zero which it is by
# default
sub remove (@) {
	my $recursive = (ref $_[0] eq 'SCALAR') ? shift : \0;
	my @files     = expand @_;

	# Iterate over the files
	my @removes;
	foreach my $path ( @files ) {
		unless ( -e $path ) {
			print "missing: $path\n" if $debug;
			push @removes, $path; # Say we deleted it
			next;
		}
		unless ( IS_VMS ? VMS::Filespec::candelete($path) : -w $path ) {
			print "nowrite: $path\n" if $debug;
			next;
		}

		if ( -f $path or -l $path ) {
			print "file: $path\n" if $debug;
			if ( $unlink ? $unlink->($path) : unlink($path) ) {
				push @removes, $path;
			}

		} elsif ( -d $path ) {
			print "dir: $path\n" if $debug;
			my $dir = File::Spec->canonpath( $path );
			if ( $$recursive ) {
				if ( File::Path::rmtree( [ $dir ], $debug, 0 ) ) {
					push @removes, $path;
				}

			} else {
				my ($save_mode) = (stat $dir)[2];
				chmod $save_mode & 0777, $dir; # just in case we cannot remove it.
				if ( $rmdir ? $rmdir->($dir) : rmdir($dir) ) {
					push @removes, $path;
				}
			}

		} else {
			print "???: $path\n" if $debug;
		}
	}

	return @removes;
}

sub rm (@) {
	goto &remove;
}

sub trash (@) {
	local $unlink = $unlink;
	local $rmdir  = $rmdir;

	if ( ref $_[0] eq 'HASH' ) {
		my %options = %{+shift @_};
		$unlink = $options{unlink};
		$rmdir  = $options{rmdir};

	} elsif ( $^O eq 'cygwin' || $^O =~ /^MSWin/ ) {
		eval 'use Win32::FileOp ();';
		die "Can't load Win32::FileOp to support the Recycle Bin: \$@ = $@" if length $@;
		$unlink = \&Win32::FileOp::Recycle;
		$rmdir  = \&Win32::FileOp::Recycle;

	} elsif ( $^O eq 'darwin' ) {
		unless ( $glue ) {
			eval 'use Mac::Glue ();';
			die "Can't load Mac::Glue::Finder to support the Trash Can: \$@ = $@" if length $@;
			$glue = Mac::Glue->new('Finder');
		}
		my $code = sub {
			my @files = map { Mac::Glue::param_type(Mac::Glue::typeAlias() => $_) } @_;
			$glue->delete(\@files);
		};
		$unlink = $code;
		$rmdir  = $code;
	} else {
		die "Support for trash() on platform '$^O' not available at this time.\n";
	}
	goto &remove;
}

sub undelete (@) {
	goto &trash;
}

1;

__END__

#line 230
