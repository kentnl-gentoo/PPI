require 5.000;
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'PPI',
	'VERSION_FROM' => 'lib/PPI.pm',
	'PREREQ_PM'    => {
		Test::More    => 0,
		Class::Handle => 0.2,
		File::Spec    => 0.82,
		File::Flat    => 0.6,
		File::Find::Rule => 0,
	},	
	($] >= 5.005) ? (
		'AUTHOR'   => 'Adam Kennedy (adam@ali.as)',
		'ABSTRACT' => 'System for parsing and working with Perl source code',
	) : (),
);
