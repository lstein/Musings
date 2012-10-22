#!/usr/bin/perl

use strict;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Simulate::MutationDistribution;

my $md = Simulate::MutationDistribution->new;
$md->generate_mutations();
$md->print_distribution;

print ">>>>>>>>>>>>>>>\n";

my @clones = map {[$md->generate_clone]} (1..100);

my (%freq,$total);
for my $c (@clones) {
    my @mutations = @$c;
    $freq{$_}++ foreach @mutations;
    $total   += @mutations;
}

foreach (sort {$freq{$b} <=> $freq{$a}} keys %freq) {
    $total += $freq{$_};
    printf("%5s %5.4f\n",$_,$freq{$_}/100);
}
print $total,"\n";

exit 0;


