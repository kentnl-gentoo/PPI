use inc::Module::Install;

name          ( 'PPI'                           );
abstract      ( 'Analyze and manipulate Perl code without using perl itself' );
author        ( 'Adam Kennedy<cpan@ali.as>'     );
version_from  ( 'lib/PPI.pm'                    );
license       ( 'perl'                          );

requires      ( 'perl'             => '5.005'   );
requires      ( 'Class::Inspector' => '1.07'    );
requires      ( 'Class::Autouse'   => '1.12'    );
requires      ( 'Clone'            => '0.13'    );
requires      ( 'File::Slurp'      => '9999.04' );
requires      ( 'List::Util'       => '1.11'    );
requires      ( 'List::MoreUtils'  => '0.04'    );
requires      ( 'Storable'         => '1.13'    );

build_requires( 'File::Spec'       => '0.82'    );
build_requires( 'Test::More'       => '0.47'    );
build_requires( 'Test::ClassAPI'   => '1.02'    );

# Bundle rare pure-perl build-time-only modules,
# and their non-core pure-perl dependencies.
include       ( 'Test::ClassAPI'                );
include       ( 'Config::Tiny'                  );

# Our test data might contain valid-looking modules.
# Don't index anything in the test data directory.
no_index      ( directory          => 't.data' );

auto_install();

&WriteAll;
