require 5.000;
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'         => 'PPI',
	'VERSION_FROM' => 'lib/PPI.pm',
	'PREREQ_PM'    => {
		# Module dependency
		Class::Autouse   => '1.04',
		Clone            => '0.13',
		File::Spec       => '0.82',
		File::Slurp      => '9999.04',
		List::MoreUtils  => '0.04',
		List::Util       => '1.11',

		# Testing dependency
		Test::More       => '0',
		Test::ClassAPI   => '0.7',
	},
	($] >= 5.005) ? (
		'AUTHOR'   => 'Adam Kennedy (cpan@ali.as)',
		'ABSTRACT' => 'Parse and manipulate Perl code non-destructively, with using perl itself',
	) : (),
);
