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
    my ($organ_system,$tumour_histological_code,$tumour_histological_type,$tumour_type_abbrev,$tumour_germ_layer,$project) 
	= @fields{'organ_system','tumour_histological_code','tumour_histological_type','tumour_type_abbrev','tumour_germ_layer','project_code'};
    die "missing organ system for $_" unless $organ_system;
    next unless $tumour_histological_code;
    $subtypes{$organ_system}{$tumour_germ_layer}{$tumour_histological_type}{$tumour_type_abbrev}{$project}++;
}

printf("%-20s %-18s %-40s %-8s %-8s %-8s\n",qw(Organ Germ_Layer Tumour_Type Abbrev Project Count));
for my $o (sort keys %subtypes) {
    for my $g (sort keys %{$subtypes{$o}}) {
	for my $t (sort keys %{$subtypes{$o}{$g}}) {
	    for my $a (sort keys %{$subtypes{$o}{$g}{$t}}) {
		for my $p (sort keys %{$subtypes{$o}{$g}{$t}{$a}}) {
		    printf("%-20s %-18s %-40s %-8s %-8s %3d\n",$o,$g,$t,$a,$p,$subtypes{$o}{$g}{$t}{$a}{$p});
		}
	    }
	}
    }
}
