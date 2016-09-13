#!/usr/bin/perl

# report on the completeness of the various fields in the pcawg_specimen_histology table
use strict;

# get fields
chomp (my $fields = <>);
$fields =~ s/^\#\s+//;
my @field_names = split "\t",$fields;

my ($total,%donors,%specimens,%field_present,%field_informative,
    %excluded_donors,%graylist_donors,%non_excluded_specimens,%library);

my $comments = create_comments();

while (<>) {
    chomp;
    $total++;

    my %fields;
    @fields{@field_names} = split "\t";

    $donors         {$fields{icgc_donor_id}}++;
    $excluded_donors{$fields{icgc_donor_id}}++ if $fields{donor_wgs_included_excluded} eq 'Excluded';
    $graylist_donors{$fields{icgc_donor_id}}++ if $fields{donor_wgs_included_excluded} eq 'GrayList';
    $specimens      {$fields{icgc_specimen_id}}++;

    $library{$fields{specimen_library_strategy}}{$fields{donor_wgs_included_excluded}}++;

    next if $fields{donor_wgs_included_excluded} eq 'Excluded';

    $non_excluded_specimens{$fields{icgc_specimen_id}}++;
    for my $f (@field_names) {
	$field_present{$f}++      if $fields{$f} =~ /\S/;
	$field_informative{$f}++  if $fields{$f} =~ /\S/ && $fields{$f} !~ /unknown|not sure|don't know|not documented/i;
    }
}

my $donors          = keys %donors;
my $included_donors = keys(%donors) - keys(%excluded_donors) - keys(%graylist_donors);
my $non_excluded    = $included_donors + keys %graylist_donors;

my $specimens              = keys %specimens;
my $non_excluded_specimens = keys %non_excluded_specimens;

printf "TOTAL PCAWG DONORS:        %5d\n",scalar(keys %donors);
printf "TOTAL INCLUDED DONORS:     %5d\n",$included_donors;
printf "TOTAL GRAYLISTED DONORS:   %5d\n",scalar(keys %graylist_donors);
printf "TOTAL EXCLUDED DONORS:     %5d\n",scalar(keys %excluded_donors);
printf "TOTAL NON-EXCLUDED DONORS: %5d\n",$non_excluded;
printf "\n";
printf "TOTAL SPECIMENS:               %5d\n",$specimens;
printf "TOTAL NON-EXCLUDED SPECIMENS:  %5d\n",$non_excluded_specimens;
printf "TABLE ROWS (==specimens):      %5d\n",$total;
printf "\n";

printf "LIBRARY STRATEGY SUMMARY:\n";
printf "%7s   %10s  %10s\n",'Library','List','Count';
for my $l (sort keys %library) {
    for my $list (sort keys %{$library{$l}}) {
	printf "%-15s %-10s %5d\n",$l,$list,$library{$l}{$list};
    }
}

printf "\n";

printf("    %-38s %-15s %-17s %-17s\n",'FIELD','PRESENT (%)','INFORMATIVE (%)','COMMENT');
my $counter = 1;
for my $f (@field_names) {
    my $present_pct     = $field_present{$f}/$non_excluded_specimens*100;
    my $informative_pct = $field_informative{$f}/$non_excluded_specimens*100;
    my $comment         = $comments->{$f};
    printf("%2d. %-36s %6d (%5.1f%%) %6d (%5.1f%%)     %-50s\n",$counter++,$f,$field_present{$f},$present_pct,$field_informative{$f},$informative_pct,$comment);
}

print "(Denominator is non-excluded specimens)\n";

exit 0;

sub create_comments {
    return {
	donor_unique_id                     => 'PCAWG ID',
	project_code                        => 'DCC/TCGA project code',
	icgc_donor_id                       => 'ICGC donor ID',
	submitted_donor_id                  => "Submitter's donor ID",
	tcga_donor_uuid                     => 'TCGA donor UUID (TCGA only)',
	icgc_specimen_id                    => 'ICGC specimen ID',
	submitted_specimen_id               => "Submitter's specimen ID",
	tcga_specimen_uuid                  => "TCGA specimen ID (TCGA only)",
	icgc_sample_id                      => "ICGC sample ID",
	submitted_sample_id                 => "Submitter's sample ID",
	tcga_sample_uuid                    => "TCGA sample UUID (TCGA only)",
	donor_sex                           => "male|female",
	donor_vital_status                  => "alive|deceased",
	tumour_histological_code            => "Histological code using ICD-0-3 when available",
	tumour_histological_type            => "Histological type, harmonized using ICD-0-3 descriptions, when available",
	donor_diagnosis_icd10               => "Donor's disease ICD10 code",
	specimen_donor_treatment_type       => "no treatment|surgery|chemotherapy|radiation|combined chemo+radiation therapy|monoclonal antibodies|other therapy",
	first_therapy_type                  => "no treatment|surgery|chemotherapy|radiation|combined chemo+radiation therapy|monoclonal antibodies|other therapy",
	first_therapy_response              => "stable disease|disease progression|partial response|complete response",
	tumour_stage                        => "Pathological TNM",
	tumour_grade                        => "Tumour grade, nomenclature varies with tumour type",
	donor_age_at_diagnosis              => "Age at diagnosis, in years",
	donor_survival_time                 => "Survival time since diagnosis, in years",
	donor_interval_of_last_followup     => "Interval between diagnosis and last followup, in days",
	tobacco_smoking_history_indicator   => "Current reformed smoker, duration not specified|Current reformed smoker for <= 15 years|Current reformed smoker for > 15 years|Current smoker (includes daily smokers non-daily/occasional smokers)|Lifelong non-smoker (<100 cigarettes smoked in lifetime)|Smoking history not documented",
	tobacco_smoking_intensity           => "Smoking history, in pack-years",
	alcohol_history                     => "yes|no|Don't know/Not sure",
	alcohol_history_intensity           => "None|Social Drinker (> once a month, < once a week)|Weekly Drinker (>=1x a week)|Daily Drinker|Occassional Drinker (< once a month)|Not Documented",
	percentage_cellularity              => "Tumour cellularity, as a percentage of nuclei in sample",
	level_of_cellularity                => "Cellularity range, as XX-XX%",
	'tcga_expert_re-review'             => "Comments from TCGA pathology expert committee on selected specimens",
	organ_system                        => "Tumour organ or organ system of origin",
	tumour_original_histology           => "Verbatim histological description, before attempts at harmonization",
	tumour_histological_comment         => "Comments on tumour histology from donor source (not expert re-review)",
	donor_wgs_included_excluded         => "Included|Excluded|Graylist",
	specimen_library_strategy           => "WGS|RNA-Seq",
	histology_abbreviation              => 'Concise subtype description',
	histology_tier1                     => 'ENDODERM|MESODERM|ECTODERM|NEURAL CREST',
	histology_tier2                     => 'Organ of origin',
	histology_tier3                     => 'Harmonized tumour subtype description',
	histology_tier4                     => 'Detailed tumour subtype description',
    };
}
