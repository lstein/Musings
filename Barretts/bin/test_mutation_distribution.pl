#!/usr/bin/perl

use strict;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Simulate::MutationDistribution;

my $md = Simulate::MutationDistribution->new;
$md->generate(100,100_000,5);
$md->print_distribution;

exit 0;


