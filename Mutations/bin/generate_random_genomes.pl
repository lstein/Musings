#!/usr/bin/perl

use lib './lib','../lib';
use SimpleGenome;

my $genomes         = shift || 1000;
my $decrease_factor = shift || 1.001;

$|=1;

my $g = SimpleGenome->new(-drivers=>0,-nondriver_weight=>20000,-weight_decrease_factor=>$decrease_factor); # 1.0000001);

for my $tumor_no (1..$genomes) {
    my $cnt = $g->mutation_count;
    my @h   = $g->mutated_genes($cnt);
    $cnt    = 0 if $cnt < 0;
    print $tumor_no,": ","cnt=$cnt, ",join(' ',@h),"\n";
}

1;

