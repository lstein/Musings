#!/usr/bin/perl

use strict;
use warnings;
use Module::Build;
use FindBin '$Bin';

my $build = Module::Build->new
    (
     module_name => 'Simulate::Barretts',
     license  => 'perl',
     dist_author        => 'Lincoln Stein <lincoln.stein@gmail.com>',
     requires => {
	 'perl'          => '5.6.1',
     },
    );
$build->create_build_script;
1;
