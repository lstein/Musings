#!/usr/bin/perl

use strict;

use lib './lib';
use Bio::DB::DamFile;

use constant TEST_BAM     => './test.bam';
use constant TEST_OUTPUT  => './test.dam';

my $in  = shift || TEST_BAM;
my $out = shift || TEST_OUTPUT;

my $bd = Bio::DB::DamFile->new();
$bd->dessicate(TEST_BAM,TEST_OUTPUT);

exit 0;

