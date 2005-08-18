use inc::Module::Install;

name           ( 'PPI'                          );
abstract       ( 'Parse, Analyze and Manipulate Perl (without perl)' );
author         ( 'Adam Kennedy <cpan@ali.as>'   );
version_from   ( 'lib/PPI.pm'                   );
license        ( 'perl'                         );
requires       ( 'perl'             => '5.005'  );
requires       ( 'Clone'            => '0.17'   );
requires       ( 'List::Util'       => '1.11'   );
requires       ( 'List::MoreUtils'  => '0.04'   );
requires       ( 'Params::Util'     => '0.05'   );
requires       ( 'IO::Scalar'       => '2.105'  );
build_requires ( 'File::Spec'       => '0.80'   );
build_requires ( 'Test::More'       => '0.47'   );
build_requires ( 'Test::ClassAPI'   => '1.02'   );
include        ( 'Test::ClassAPI'               );
include        ( 'Class::Inspector'             );
include        ( 'Config::Tiny'                 );
no_index       ( directory          => 't.data' );

auto_install();

&WriteAll;
