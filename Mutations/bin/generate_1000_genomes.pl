#!/usr/bin/perl

use lib './lib';
use SimpleGenome;


for my $tumor_no (1..1000) {
    my $g = SimpleGenome->new;
    my @h   = $g->mutated_genes;
    my $cnt = $g->mutation_count;
    print $tumor_no,": ","cnt=$cnt, ",join(' ',@h),"\n";
}

1;

