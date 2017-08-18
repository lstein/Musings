#!/usr/bin/perl

use strict;
# script to patch diagnostic codes for a series of specimens
# for which this was originally wrong

my $revisions = shift;

my %diagnosis;
open my $f,$revisions or die "$revisions: $!";
while (<$f>) {
    next if /^#/;
    my ($specimen_id,$original_icd,$new_icd,@rest) = split /\s+/;
    my $comment             = join " ",@rest;
    my ($histological_type) = $comment=~/->(.+)/;
    $diagnosis{$specimen_id}= [$new_icd,$histological_type];
}
close $f;

# expects file in the format of histological_subtypes_and_clinical_data_merged_filled_XXXX.tsv
chomp (my $first_line = <>);

$first_line =~ s/^#\s+//;
my @fields = split "\t",$first_line;

print "# $first_line\n";
my %fields;
while (<>) {
    chomp;
    @fields{@fields} = split "\t";
    my $dx = $diagnosis{$fields{'icgc_specimen_id'}} or next;
    $fields{'tumour_histological_code'} = $dx->[0];
    $fields{'tumour_histological_type'} = $dx->[1];
} continue {
    print join("\t",@fields{@fields}),"\n";
}

