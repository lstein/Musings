#!/usr/bin/perl

use strict;
use strict;
use lib './lib';
use Bio::DB::DamFile;

my $start = shift;

my $dam = Bio::DB::DamFile->new('./test.dam');

$dam->seek_to_read($start) if $start;

while (my $line = $dam->next_read) {
    print $line,"\n";
}
