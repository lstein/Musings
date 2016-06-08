#!/usr/bin/perl

use strict;
use lib './lib','../lib';
use Bio::DB::DamFile;

@ARGV == 3 or die "Usage: hydrate.pl <in.dam> <reads.{sam,bam,fastq}> <out.bam>";

my $dam_in   = shift;
my $reads_in = shift;
my $bam_out  = shift;

my $bd = Bio::DB::DamFile->new($dam_in);
$bd->rehydrate($reads_in,$bam_out);

0;



