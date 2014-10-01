#!/usr/bin/perl

use strict;

my %tally;

while (<>) {
    chomp;
    my @genes = split /\s+/;
    $tally{$_}++ foreach @genes;
}

my @genes = sort {$tally{$b}<=>$tally{$a}} keys %tally;
for my $g (@genes) {
    print $g,"\t",$tally{$g},"\n";
}


exit 0;
