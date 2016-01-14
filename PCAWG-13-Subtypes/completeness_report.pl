#!/usr/bin/perl

# report on the completeness of the various fields
use strict;

# get fields
chomp (my $fields = <>);
$fields =~ s/^\#\s+//;
my @field_names = split "\t",$fields;

my ($total,%donors,%missing,%field_present,%field_informative);

my $comments = create_comments();

while (<>) {
    chomp;
    $total++;

    my %fields;
    @fields{@field_names} = split "\t";

    if (/MISSING FROM DCC/) {
	my ($id) = /^\#\s*(\S+)/;
	next unless $id;
	$donors{$id}++;
	$missing{$id}++;
	next;
    } else {
	$donors{$fields{'donor_unique_id'}}++;
    }
    next if $donors{$fields{'donor_unique_id'}} > 1;  # don't overcount donors that have multiple specimens

    for my $f (@field_names) {
	$field_present{$f}++      if $fields{$f} =~ /\S/;
	$field_informative{$f}++  if $fields{$f} =~ /\S/ && $fields{$f} !~ /unknown|not sure|don't know|not documented/i;
    }
}

my $donors  = keys %donors;
my $present = $donors - keys %missing;
my $percent = sprintf("%2.1f",$present/$donors*100);

print "TOTAL PCAWG DONORS:    $donors\n";
print "TOTAL PCAWG SPECIMENS: $total\n";
print "DONORS IN DCC:         $present ($percent%)\n";
print "\n";

printf("%-36s %-17s %-17s %-17s\n",'FIELD','PRESENT (%)','INFORMATIVE (%)','COMMENT');
for my $f (@field_names) {
    my $present_pct     = $field_present{$f}/$present*100;
    my $informative_pct = $field_informative{$f}/$present*100;
    my $comment         = $comments->{$f};
    printf("%-36s %6d (%5.1f%%) %6d (%5.1f%%)     %-50s\n",$f,$field_present{$f},$present_pct,$field_informative{$f},$informative_pct,$comment);
}
print "\n(Percentages given in this table are per donor present in DCC)\n";

print "\n\n";
print "Missing donors:\n";
print join "\n",(sort keys %missing),"\n";

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
	tumour_histological_type            => "Histological type using free text",
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
    };
}
