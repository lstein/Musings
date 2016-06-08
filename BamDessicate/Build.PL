#!/usr/bin/perl

use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new (
    module_name => 'Bio::DB::DamFile',
    license     => 'perl',
    dist_author => 'Lincoln Stein <lincoln.stein@gmail.com>',
    dist_abstract => 'Shrink BAM files by removing sequence and quality scores',
    dist_version_from => 'lib/Bio/DB/DamFile.pm',
    requires    => {
	'perl'                    => '5.6.1',
	'IO::Uncompress::Bunzip2'          => '2.063',
	'List::BinarySearch'               => '0.25',
	'Tie::Cache'                       => '0.17',
	'File::GlobMapper'                 => '1.000',
	'IO::Compress::Base'               => '2.063',
	'Compress::Raw::Bzip2'             => '2.063',
	'IO::Uncompress::Adapter::Bunzip2' => '2.063',
	'IO::Uncompress::Base'             => '2.063',
	'IO::Compress::Base::Common'       => '2.063',
    });
$build->create_build_script;
1;
