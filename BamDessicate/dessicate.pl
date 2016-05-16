#!/usr/bin/perl

use strict;

open OUT,"|gzip -c" or die $!;
while (@ARGV) {
    my $file = shift;

    my $fh;
    if ($file =~ /\.bam$/) {
	open $fh,"samtools view $file | " or die $!;
    } else {
	open $fh,$file or die $!;
    }
    while (<$fh>) {
	chomp;
	if (/^@/) { print OUT $_,"\n"; next; }
	my @fields = split "\t";
	print OUT join("\t",@fields[0,1,2,3,4,5,6,7,8,11..$#fields]),"\n";
    }
}
