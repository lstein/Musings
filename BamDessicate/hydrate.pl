#!/usr/bin/perl

# Stupid way to do it.
# Real implementation is to compress dessicated file in blocks, whilst building
# an index of which read IDs are in each block.

use strict;
@ARGV == 2 or die "Usage: hydrate.pl <fastq_file> <dam_file>";
my $fastq  = shift;
my $dam    = shift;

# Create an in-memory index to hold the entire file. Won't scale!
my %dam;
open my $in,"gunzip -c $dam|" or die $!;
while (<$in>) {
    print if /^@/; #header
    chomp;
    my @fields = split "\t";
    $dam{$fields[0]} = $_;   # don't store an array; space crazy!
}
close $in or die $!;

{
    # Now deal with the fastq file
    if ($fastq =~ /\.gz$/) {
	open $in,"gunzip -c $fastq|" or die;
    } else {
	open $in,$fastq or die;
    }

    local $/ = '@';
    while (<$in>) {
	chomp;
	next unless $_;
	my ($id,$seq,undef,$qual) = split "\n";
	$id =~ s/\s.+//;  # get rid of description
	my $dam_line    = $dam{$id} or next;
	my @dam_fields  = split "\t",$dam_line;
	print join("\t",@dam_fields[0..8],$seq,$qual,@dam_fields[9..$#dam_fields]),"\n";
    }
}

exit 0;
