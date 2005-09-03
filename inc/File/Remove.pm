#line 1 "inc/File/Remove.pm - /usr/local/share/perl/5.8.4/File/Remove.pm"
package File::Remove;

#line 97

use strict;
use vars qw(@EXPORT_OK @ISA $VERSION $debug $unlink $rmdir);
@ISA = qw(Exporter);
# we export nothing by default :)
@EXPORT_OK = qw(remove rm trash);

use File::Spec;
use File::Path qw(rmtree);

$VERSION = '0.30';

our $glue;

sub expand (@)
{
    my @args;

    for (@_) {
        push @args, glob;
    }
    @args;
}

# acts like unlink would until given a directory as an argument, then
# it acts like rm -rf ;) unless the recursive arg is zero which it is by
# default
sub remove (@)
{
    my $recursive;
    if(ref $_[0] eq 'SCALAR') {
        $recursive = shift;
    }
    else {
        $recursive = \0;
    }
    my @files = expand @_;
    my @removes;

    my $ret;
    for (@files) {
        print "file: $_\n" if $debug;
        if(-f $_ || -l $_) {
            print "file unlink: $_\n" if $debug;
	    my $result = $unlink ? $unlink->($_) : unlink($_);
	    push(@removes, $_) if $result;
        }
        elsif(-d $_) {
	    print "dir: $_\n" if $debug;
	    # XXX: this regex seems unnecessary, and may trigger bugs someday.
	    # TODO: but better to trim trailing slashes for now.
	    s/\/$//;
	    if ($$recursive) {
		my $result = rmtree([$_], $debug, 1);
		push(@removes, $_) if $result;
	    } else {
		my ($save_mode) = (stat $_)[2];
		chmod $save_mode & 0777,$_; # just in case we cannot remove it.
		my $result = $rmdir ? $rmdir->($_) : rmdir($_);
		push(@removes, $_) if $result;
	    }
        } else {
	    print "???: $_\n" if $debug;
	}
    }

    @removes;
}

sub rm (@) { goto &remove }

sub trash (@) {
    our $unlink = $unlink;
    our $rmdir = $rmdir;
    if (ref($_[0]) eq 'HASH') {
	my %options = %{+shift @_};
	$unlink = $options{'unlink'};
	$rmdir = $options{'rmdir'};
    } elsif ($^O eq 'cygwin' || $^O =~ /^MSWin/) {
	eval 'use Win32::FileOp ();';
	die "Can't load Win32::FileOp to support the Recycle Bin: \$@ = $@" if length $@;
	$unlink = \&Win32::FileOp::Recycle;
	$rmdir = \&Win32::FileOp::Recycle;
    } elsif ($^O eq 'darwin') {
	unless ($glue) {
	    eval 'use Mac::Glue ();';
	    die "Can't load Mac::Glue::Finder to support the Trash Can: \$@ = $@" if length $@;
	    $glue = Mac::Glue->new('Finder');
	}
	my $code = sub {
	    my @files = map { Mac::Glue::param_type(Mac::Glue::typeAlias() => $_) } @_;
	    $glue->delete(\@files);
	};
	$unlink = $code;
	$rmdir = $code;
    } else {
	die "Support for trash() on platform '$^O' not available at this time.\n";
    }
    goto &remove;
}

sub undelete (@) { goto &trash }

1;
