require 5.000;
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'PPI',
	'VERSION_FROM' => 'lib/PPI.pm',
	'PREREQ_PM'    => {
		# Module dependency
		CGI              => '0',
		CGI::Carp        => '0',
		Class::Autouse   => '1.04',
		Class::Handle    => '1.0',
		Clone            => '0.13',
		Config::Tiny     => '1.9',
		File::Spec       => '0.82',
		File::Slurp      => '9999.04',
		File::Find::Rule => '0',
		List::MoreUtils  => '0.04',
		List::Util       => '1.11',
		Test::ClassAPI   => '0.5',

		# Testing dependency
		Test::More       => '0',
		Scalar::Util     => '0',
	},
	($] >= 5.005) ? (
		'AUTHOR'   => 'Adam Kennedy (cpan@ali.as)',
		'ABSTRACT' => 'Parse and manipulate Perl code non-destructively, with using perl itself',
	) : (),
);
