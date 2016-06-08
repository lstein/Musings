#!/usr/bin/perl

use strict;
use Bio::DB::DamFile;

my $bam_in = shift;
my $dam_in = shift;
my $bam_out = shift;

$bam_in && $dam_in && $bam_out or die "Usage: hydrate.pl <in.bam> <in.dam> <out.bam>";

my $bd = Bio::DB::DamFile->new($dam_in);
$bd->rehydrate($bam_in,$bam_out);

0;



