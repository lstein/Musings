#!/usr/bin/perl

use strict;
use lib './lib';
use WeightedDistribution;

#my $dist = WeightedDistribution->new([0.9, 0.8, 0.7, 0.5, 0.2, 0.2, 0.2, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05, 0.05, 0.05]);
my $dist = WeightedDistribution->new([(1) x 20]);

my ($total,%items);
for (1..1000) {
    my @items = $dist->draw(1);
    warn "@items";
    $items{$_}++ foreach @items;
    $total += @items;
}

# frequency that comes out should match what went in
print "Item\tFrequency\n";
for my $i (sort {$items{$b}<=>$items{$a}} keys %items) {
    print $i,"\t",$items{$i}/$total,"\n";
}
