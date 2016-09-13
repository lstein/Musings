#!/usr/bin/perl

use strict;
use LWP::Simple;

# for debugging
@ARGV = '/home/lstein/Common/ICGC/PanCancer/PCAWG-13/Subtypes/March2016_Dataset/histological_subtypes_and_clinical_data_harmonized_March2016_v1.tsv'
    unless @ARGV;

# This script applies the histological groupings of the google spreadsheet posted at
# https://docs.google.com/spreadsheets/d/1NqglNjsU4if6IC6A9yHQ55eImIuSmyTkrfAU7k7-kUI/edit#gid=1303912690
# to the "harmonized" version of the samples sheet, splitting it into clinical and histopathological files

# provide the path to the harmonized sample sheet as the argument

# The files will be written to the current working directory:
#    pcawg_specimen_histology.tsv
#    pcawg_donor_clinical.tsv

# this is the public sharing URL for the consolidation map
use constant CONSOLIDATION_SPREADSHEET => 'https://docs.google.com/spreadsheets/d/1NqglNjsU4if6IC6A9yHQ55eImIuSmyTkrfAU7k7-kUI/edit?usp=sharing';

# output fields for pcawg_clinical.tsv
my @clinical_fields = qw(
 donor_unique_id
 project_code
 icgc_donor_id
 submitted_donor_id
 tcga_donor_uuid
 donor_sex
 donor_vital_status
 donor_diagnosis_icd10
 first_therapy_type
 first_therapy_response
 donor_age_at_diagnosis
 donor_survival_time
 donor_interval_of_last_followup
 tobacco_smoking_history_indicator
 tobacco_smoking_intensity
 alcohol_history
 alcohol_history_intensity
 donor_wgs_included_excluded
);

# output fields for pcawg_specimen.tsv
my @specimen_fields = qw(
    icgc_specimen_id
    project_code
    submitted_specimen_id
    submitted_sample_id
    tcga_specimen_uuid
    icgc_sample_id
    tcga_sample_uuid
    donor_unique_id
    icgc_donor_id
    submitted_donor_id
    tcga_donor_uuid
    organ_system
    histology_abbreviation
    histology_tier1
    histology_tier2
    histology_tier3
    histology_tier4
    tumour_histological_code
    tumour_histological_type
    tumour_stage
    tumour_grade
    percentage_cellularity
    level_of_cellularity
    tcga_expert_re-review
    tumour_histological_comment
    specimen_donor_treatment_type
    donor_wgs_included_excluded
);

my $url      = CONSOLIDATION_SPREADSHEET;
#$url         =~ s!/edit.+!/export?gid=0&format=tsv!;
$url         =~ s!/edit.+!/export?format=tsv!;

# mirror to local
my $result = mirror($url,'consolidation_map.tsv');
warn "mirror result for '$url' = $result\n";
my $conso = parse_consolidation_map('consolidation_map.tsv');

open my $clin,'>','./pcawg_donor_clinical.tsv'      or die $!;
open my $spec,'>','./pcawg_specimen_histology.tsv'  or die $!;

print STDERR "Writing ./pcawg_donor_clinical.tsv and ./pcawg_specimen_histology.tsv\n";
print $clin "# ",join("\t",@clinical_fields),"\n";
print $spec "# ",join("\t",@specimen_fields),"\n";

chomp (my $header = <>);
$header =~ s/^#\s+//;
my @input_fields =  split "\t",$header;

my (%donors);
while (<>) {
    chomp;
    my %fields;
    @fields{@input_fields} = split "\t";

    my $donor    = $fields{donor_unique_id};
    my $specimen = $fields{icgc_specimen_id};
    my $sample   = $fields{icgc_sample_id};

    my $organ = substr($fields{organ_system},0,30);   # for matching purpose
    my $icd0  = $fields{tumour_histological_code};
    my $tiers = $conso->{$organ}{$icd0};

    # write out clinical fields unless we've seen this before
    print $clin join("\t",@fields{@clinical_fields}),"\n" unless $donors{$donor}++;

    # insert the tier information
    if ($tiers) {
	$fields{'histology_abbreviation'} = $tiers->{'Tier 3 Abbreviation'};
	$fields{"histology_tier$_"}       = $tiers->{"Tier $_"} for (1..4);
    }
    $fields{'tumour_histological_code'} = "'$fields{tumour_histological_code}";

    print $spec join("\t",@fields{@specimen_fields}),"\n" unless /MISSING FROM DCC/;
}

exit 0;

sub parse_consolidation_map {
    my $map = shift;
    open my $f,'<',$map or die $!;

    # read until we get to the header
    my @field_names;
    while (<$f>) {
	chomp;
	next unless /^organ/;
	@field_names = split "\t";
	last;
    }

    my (%map);
    while (<$f>) {
	chomp;
	my %f;
	@f{@field_names} = split "\t";
	my $organ = substr($f{'organ system'},0,30) or next;
	my $histo = $f{'Submitter histopathology (icd-0-3 + description)'};
	my ($code,$desc) = $histo =~ m!^(\w{4}/\w)\s+(.+)!;
	$map{$organ}{$code} = \%f;
    }

    return \%map;
}
