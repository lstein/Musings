#!/usr/bin/perl

use strict;
@ARGV = 'October2015_Dataset/histological_subtypes_and_clinical_release_merged_harmonized_oct2015.tsv' unless @ARGV;

my %subtypes;

chomp (my $header = <>);
$header =~ s/^#\s+//;
my @fieldnames = split "\t",$header;

while (<>) {
    my %fields;
    chomp;
    next if /^#/;
    @fields{@fieldnames} = split "\t";
    my ($organ_system,$tumour_histological_code,$tumour_histological_type,$project) = @fields{'organ_system','tumour_histological_code','tumour_histological_type','project_code'};
    die "missing organ system for $_" unless $organ_system;
    $tumour_histological_type ||= "[histology field absent]";
    $tumour_histological_code ||= "XXXX/X";
#    $tumour_histological_type =~ s/"//g;
#    $tumour_histological_type = ucfirst($tumour_histological_type);
    $organ_system             = substr($organ_system,0,40) if length $organ_system > 40;
    $subtypes{$organ_system}{"$tumour_histological_code $tumour_histological_type"}++;
}

for my $o (sort keys %subtypes) {
    for my $t (sort keys %{$subtypes{$o}}) {
	printf("%-40s %-60s %3d\n",$o,$t,$subtypes{$o}{$t});
    }
}
