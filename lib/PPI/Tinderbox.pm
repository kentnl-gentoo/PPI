package PPI::Tinderbox;

=pod

=head1 NAME

PPI::Tinderbox - Process all of CPAN to find parsing bugs

=head1 SYNOPSIS

  # Create the new Tinderbox process
  my $Tinderbox = PPI::Tinderbox->new(
      # Paths
      remote             => 'http://cpan.pair.com/',
      local              => '~/tinderbox/minicpan',
      source             => '~/tinderbox/expanded',
      results            => '~/tinderbox/results.txt',
      archive_tar_report => '~/tinderbox/archive_tar_report.txt',

      # Options
      trace              => 1,
      # force_expand       => 1,
      force_processor    => 1,
      limit_processor    => 500,
      # flush_results      => 1,
      ) or die PPI::Tinderbox->errstr
      	. ": Failed to create PPI::Tinderbox object";

  # Execute the Tinderbox
  my $rv = $Tinderbox->run;

  if ( $rv ) {
      print "\nTinderbox run completed\n";
  } else {
      print "\nTinderbox run failed\n";
  }

=head1 DESCRIPTION

The nature of PPI means that it is never perfect at parsing files, just good
enough to get the job done.

In order to keep the accuracy of the parser improving it is necesary to run
various tasks against every known CPAN module in order to hunt down problems
in the parser.

The PPI Tinderbox package is designed to do just this. It implements a
PPI::Processor subclass that takes an installation of MiniCPAN and processes
every perl file, checking for a variety of different problems, including
parsing exceptions, crashing the parser, circular reference leaks, and
including searches within the lexed Documents for clues indicative of a
mis-parse.

=head2 Structure and Design

Initially, the PPI Tinderbox will be single-process and single-processor
only. This is primarily to enable the PPI::Processor base class to be
implemented easily, so that we can start to generate useful test data
as quickly as possible, to enable proper debugging of PPI for it's 1.0
release.

Given that the problem of parsing 35,000-odd perl files is
"embarrasingly parallel" it is expected that some sort of parallel
version of PPI::Processor will become available relatively quickly,
and once this occurs it would be expected that the PPI Tinderbox would
change to use that version instead.

=head1 EXTENDING

PPI::Tinderbox is generally considered an "end-use" module, and it may
be difficult to extend.

You may wish to take a look at the more general L<CPAN::Processor> instead.

=head1 METHODS

=cut

use strict;
use base 'CPAN::Processor';
use PPI::Processor       ();
use PPI::Tinderbox::Task ();

use vars qw{$VERSION};
BEGIN {
	$VERSION = '0.06';
}





#####################################################################
# Constructor

=pod

=head1 new minicpan => $CPAN::Mini, 

The C<new> constructor creates a new PPI Tinderbox top level object,
which stores the configuration and acts primarily as a management
class, setting up and launching the Processor.

Returns a new PPI::Tinderbox object, or C<undef> on error.

=cut

sub new {
	my $class  = ref $_[0] ? ref shift : shift;
	my %args = @_;

	# Create the Processor
	my $Processor = PPI::Processor->new(
		source     => delete($args{source}),
		flushstore => delete($args{flush_results}),
		limit      => delete($args{limit_processor}),
		);
	unless ( $Processor ) {
		return $class->_error( PPI::Processor->errstr );
	}

	# Initialise and add the main Task
	my %task = ( incremental_write => 1 );
	$task{file} = delete $args{results} if $args{results};
	$Processor->add_task( 'PPI::Tinderbox::Task', %task )
		or return $class->_error( "Failed to create PPI::Tinderbox::Task object" );

	# Set the appropriate defaults
	$args{processor} = $Processor;
	$args{file_filters} ||= [
		qr~\bt\b~,
		qr~/inc/~,
		qr~\bdemos\b~i,
		qr~\.pl$~,
		qr~\.t$~,
		qr~sample~,
		qr~\bexamples\b~,
		qr~\\\.\#~,
		];
	$args{module_filters} ||= [
		qr/^Acme::/,
		qr/^Meta::/,
		];
	$args{skip_perl} = 1 unless exists $args{skip_perl};
	$args{force}     = 1 unless exists $args{force};

	# If they want the missing Makefile.PL, we have to force expansion
	$args{force_expand} = 1 if $args{missing_makefile_report};

	# Create the CPAN Processor
	my $self = $class->SUPER::new( %args );
	return $self unless $self;

	# Manually add the callbacks
	$Processor->{before_file} = sub { $self->trace( "Processing $_[0]" ); 1 };
	$Processor->{after_file}  = sub { $self->trace( " ... done\n" ) };

	$self;
}

1;

=pod

=head1 SUPPORT

Bugs should always be submitted via the CPAN bug tracker

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PPI%3A%3ATinderbox>

For other issues, contact the maintainer

=head1 AUTHOR

Adam Kennedy (Maintainer), L<http://ali.as/>, cpan@ali.as

Funding provided by The Perl Foundation

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
