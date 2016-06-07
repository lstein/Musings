#!/usr/bin/perl

use strict;

use lib './lib';
use Bio::DB::DamFile;

use constant TEST_BAM  => './test.bam';
use constant TEST_DAM  => './test.dam';
use constant TEST_OUT  => './test_rehydrated.bam';

my $bam = shift || TEST_BAM;
my $dam = shift || TEST_DAM;

my $bd = Bio::DB::DamFile->new($dam);
$bd->rehydrate(TEST_BAM,TEST_OUT);

0;



