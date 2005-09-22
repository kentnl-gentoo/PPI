use inc::Module::Install;

name           ( 'PPI'                          );
abstract       ( 'Parse, Analyze and Manipulate Perl (without perl)' );
author         ( 'Adam Kennedy <cpan@ali.as>'   );
version_from   ( 'lib/PPI.pm'                   );
license        ( 'perl'                         );
requires       ( 'perl'             => '5.005'  );
requires       ( 'Carp'             => 0        );
requires       ( 'Clone'            => '0.17'   );
requires       ( 'List::Util'       => '1.11'   );
requires       ( 'List::MoreUtils'  => '0.04'   );
requires       ( 'Params::Util'     => '0.05'   );
requires       ( 'IO::Scalar'       => '2.105'  );

# Modules needed for PPI::Cache
requires       ( 'Digest::MD5'      => '2.27'   );
requires       ( 'Storable'         => '2.14'   );

# Test-time dependencies
build_requires ( 'Test::More'       => '0.47'   );
build_requires ( 'Test::ClassAPI'   => '1.02'   );
build_requires ( 'Test::SubCalls'   => '0.01'   );
build_requires ( 'File::Spec'       => '0.84'   );
build_requires ( 'File::Remove'     => '0.22'   );
include        ( 'Test::ClassAPI'               );
include        ( 'Test::SubCalls'               );
include        ( 'File::Remove'                 );

# Include dependencies of the main build-time includes
include        ( 'Class::Inspector'             );
include        ( 'Config::Tiny'                 );
include        ( 'Hook::LexWrap'                );

# Ignore anything perl-ish in the test data directory
no_index       ( directory          => 't.data' );

auto_install();

&WriteAll;
