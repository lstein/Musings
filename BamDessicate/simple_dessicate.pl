#!/usr/bin/perl

use strict;
use constant TEST_BAM => './test.bam';
use constant TEST_OUT => './test-dessicated.bam';

my $infile  = shift || TEST_BAM;
my $outfile = shift || TEST_OUT;

$infile && $outfile or die "Usage: simple_dessicate.pl <\$in.bam> <\$out.bam>";

open my $outfh,"| samtools view -b -S - >$outfile " or die "samtools out: $!";
open my $infh, "  samtools view -H $infile | "      or die "samtools in: $!";  # header only for now

print $outfh $_ while <$infh>;
close $infh;

# reopen on a sorted sam stream
open my $infh,"samtools view $infile | sort -k1,1 |" or die "samtools in: $!";

while (<$infh>) {
    chomp;
    my @fields = split "\t";
    @fields[9,10] = ('*','*');
    print $outfh join("\t",@fields),"\n";
}
