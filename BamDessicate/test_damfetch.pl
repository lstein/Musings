#!/usr/bin/perl

use strict;
use lib './lib';
use Bio::DB::DamFile;

my $dam = Bio::DB::DamFile->new('./test.dam');
print join ("\n",
	    $dam->header_magic,
	    $dam->header_offset,
	    $dam->block_offset,
	    $dam->index_offset,
	    $dam->source_path),"\n";


for my $read (qw(NA06984-SRR006041.831210
                 NA06984-SRR006041.831209
                 NA06984-SRR006041.1383757
                 NA06984-SRR006041.831209
                 NA06984-SRR006041.1552758
                 NA06984-SRR006041.1184038
                 NA06984-SRR006041.287724
                 NA06984-SRR006041.831249
                 NA06984-SRR006041.831209
                 NA06984-SRR006041.83099
                 NA06984-SRR006041.830991
                 NA06984-SRR006041.831)) {
    my $result = eval {$dam->fetch_read($read)};
    unless ($result) {
	warn "$read not found in DAM file";
	next;
    }
    print join("\n",@$result),"\n";
}

print "\n\n";
my $stats = $dam->cache_stats;
my $total = $stats->{hits} + $stats->{misses};
print "cache hits   = ",$stats->{hits},sprintf('(%2.1f%%)',100* $stats->{hits}/$total),"\n";
print "cache misses = ",$stats->{misses},sprintf('(%2.1f%%)',100* $stats->{misses}/$total),"\n";

exit 0;
