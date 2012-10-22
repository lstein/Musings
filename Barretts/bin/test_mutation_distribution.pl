#!/usr/bin/perl

use strict;
use FindBin '$Bin';
use lib "$Bin/../lib";
use Simulate::MutationDistribution;

my $md = Simulate::MutationDistribution->new;
$md->generate_power_distribution();
#$md->generate_mutations();
#$md->print_distribution;

exit 0;


