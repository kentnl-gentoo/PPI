require 5.000;
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'PPI',
	'VERSION_FROM' => 'lib/PPI.pm',
	'PREREQ_PM'    => {
		CGI              => 0,
		CGI::Carp        => 0,
		Test::More       => 0,
		Class::Autouse   => 0,
		Class::Handle    => 0.2,
		File::Spec       => 0.82,
		File::Flat       => 0.6,
		File::Find::Rule => 0,
		List::Util       => 1.11,
		Test::ClassAPI   => 0,
		Config::Tiny     => 0,
	},
	($] >= 5.005) ? (
		'AUTHOR'   => 'Adam Kennedy (cpan@ali.as)',
		'ABSTRACT' => 'Parse and manipulate perl code',
	) : (),
);
