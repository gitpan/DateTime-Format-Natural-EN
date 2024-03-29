# Note: this file has been initially created by Make::Build::Convert 0.20_01

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new
  (
   module_name => 'DateTime::Format::Natural::EN',
   dist_author => 'Steven Schubiger <schubiger@cpan.org>',
   dist_version_from => 'lib/DateTime/Format/Natural/EN.pm',
   requires => {
                 'Date::Calc' => 0,
                 'DateTime' => 0,
               },
   build_requires => { 'Test::More' => 0 },
   recommends => {
                   'Test::Pod' => '1.14',
                   'Test::Pod::Coverage' => '1.04',
                 },
   license => 'perl',
   create_readme => 1,
   create_makefile_pl => 'traditional',
  );
  
$build->create_build_script;
