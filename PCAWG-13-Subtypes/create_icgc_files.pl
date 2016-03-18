#!/usr/bin/perl

use strict;

# this script's job is to take raw ICGC submission files and massage them
# into formats compatible with those produced by clinical donor dumps from
# the portal.

# the script argument is the path to a directory that contains unpacked tar files.
# The directory should look like this:

# total 32
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 09:51 BOCA-UK
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 09:51 BRCA-EU
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 09:52 CLLE-ES
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 09:53 CMDI-UK
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 09:59 EOPC-DE
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 10:04 ESAD-UK
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 10:00 MALY-DE
# drwxr-xr-x 2 lstein lstein 4096 Mar 15 10:01 PBCA-DE

# ./BOCA-UK:
# total 24
# -rw-r--r-- 1 lstein lstein  551 Mar 15 09:51 donor.20141211.txt.bz2
# -rw-r--r-- 1 lstein lstein  933 Mar 15 09:51 donor.txt.bz2
# -rw-r--r-- 1 lstein lstein  827 Mar 15 09:51 sample.20141211.txt.bz2
# -rw-r--r-- 1 lstein lstein  759 Mar 15 09:51 sample.txt.bz2
# -rw-r--r-- 1 lstein lstein 1411 Mar 15 09:51 specimen.20141211.txt.bz2
# -rw-r--r-- 1 lstein lstein 1304 Mar 15 09:51 specimen.txt.bz2

# the script pulls the project name from the directory, and concatenates the 
# "donor", "sample", "specimen", "family" and "exposure" files.

# if there is a file named "pcawg_sample_sheet.tsv" in the PARENT directory, it will be used
# to populate a mapping between ICGC donor ids and submitter donor ids, which is a GOOD THING

# The raw files have the same format as the output files, except that the order of fields
# is scrambled, and we have to make the following accomodations:
# 1. Assign temporary ICGC IDs for donor, specimen and sample
# 2. ID mappings:
#        raw file                 portal file
#        specimen_id        => submitted_specimen_id
#        analyzed_sample_id => submitted_sample_id
#        donor_id           => submitted_donor_id

# Six files result:
#   sample.tsv
#   specimen.tsv
#   donor.tsv
#   donor_therapy.tsv
#   donor_exposure.tsv
#   donor_family.tsv

my @specimen_fields = qw(icgc_specimen_id project_code
study_specimen_involved_in submitted_specimen_id icgc_donor_id
submitted_donor_id specimen_type specimen_type_other specimen_interval
specimen_donor_treatment_type specimen_donor_treatment_type_other
specimen_processing specimen_processing_other specimen_storage
specimen_storage_other tumour_confirmed specimen_biobank
specimen_biobank_id specimen_available tumour_histological_type
tumour_grading_system tumour_grade tumour_grade_supplemental
tumour_stage_system tumour_stage tumour_stage_supplemental
digital_image_of_stained_section percentage_cellularity
level_of_cellularity);

my @sample_fields = qw(icgc_sample_id project_code submitted_sample_id
icgc_specimen_id submitted_specimen_id icgc_donor_id
submitted_donor_id analyzed_sample_interval percentage_cellularity
level_of_cellularity study);

my @donor_fields = qw(icgc_donor_id project_code
study_donor_involved_in submitted_donor_id donor_sex
donor_vital_status disease_status_last_followup donor_relapse_type
donor_age_at_diagnosis donor_age_at_enrollment
donor_age_at_last_followup donor_relapse_interval
donor_diagnosis_icd10 donor_tumour_staging_system_at_diagnosis
donor_tumour_stage_at_diagnosis
donor_tumour_stage_at_diagnosis_supplemental donor_survival_time
donor_interval_of_last_followup prior_malignancy
cancer_type_prior_malignancy cancer_history_first_degree_relative);

my @donor_therapy_fields = qw(icgc_donor_id project_code
submitted_donor_id first_therapy_type first_therapy_therapeutic_intent
first_therapy_start_interval first_therapy_duration
first_therapy_response second_therapy_type
second_therapy_therapeutic_intent second_therapy_start_interval
second_therapy_duration second_therapy_response other_therapy
other_therapy_response);

my @donor_exposure_fields = qw(icgc_donor_id project_code
submitted_donor_id exposure_type exposure_intensity
tobacco_smoking_history_indicator tobacco_smoking_intensity
alcohol_history alcohol_history_intensity);

my @donor_family_fields = qw(icgc_donor_id project_code
submitted_donor_id donor_has_relative_with_cancer_history
relationship_type relationship_type_other relationship_sex
relationship_age relationship_disease_icd10 relationship_disease);

my $id_cache = {
    donor    => {},
    specimen => {},
    sample   => {},
};

my $counters = {
    donor    => 1,
    specimen => 1,
    sample   => 1,
};

my %specimen2donor;

#########################  code starts here ##############

my $directory = shift || '.';
chdir $directory or die "Couldn't chdir: $!";
parse_ids('../pcawg_sample_sheet.tsv') if -e '../pcawg_sample_sheet.tsv';

my @projects  = <????-??>;
for my $project (@projects) {
    write_donors($project);
    write_specimens($project);
    write_samples($project);
    write_family($project);
    write_exposure($project);
    write_therapy($project);
}

exit 0;

sub parse_ids {
    my $file = shift;
    open my $f,"<$file" or die "$file: $!";
    chomp(my $fields = <$f>);
    my @fields = split "\t",$fields;
    my %f;
    while (<$f>) {
	chomp;
	@f{@fields} = split "\t";
	$id_cache->{donor}{$f{submitter_donor_id}}       = $f{icgc_donor_id};
	$id_cache->{specimen}{$f{submitter_specimen_id}} = $f{icgc_specimen_id};
	$id_cache->{sample}{$f{submitter_sample_id}}     = $f{icgc_sample_id};
    }
}

sub get_icgc_id {
    my ($domain,$submitter_id) = @_;
    my $c = $id_cache->{$domain} or die "invalid id domain: $domain";
    return $c->{$submitter_id} ||= $domain.'_'.$counters->{$domain}++;
}

sub write_donors {
    my $project = shift;
    my @donor_files = <$project/donor*>;
    # potential bug here: assume that all files are compressed using
    # same compression system
    my $cat = cat(@donor_files);

    chomp(my $fields = <$cat>);
    my @fields = split "\t",$fields;
    my %f;

    open my $out,">>./donor.tsv" or die "$!";
    print $out join("\t",@donor_fields),"\n";

    while (<$cat>) {
	chomp;
	next if /^donor_id/;
	@f{@fields} = map {($_==-777 or $_==-888) ? '' : $_} map {trim($_)} split "\t";
	# jiggery pokery
	my $donor_id           = get_icgc_id('donor',$f{donor_id});
	$f{icgc_donor_id}      = $donor_id;
	$f{project_code}       = $project;
	$f{submitted_donor_id} = $f{donor_id};
	cv(\%f,'donor_sex',           {1=>'male',2=>'female'});
	cv(\%f,'donor_vital_status',  {1=>'alive',2=>'deceased'});
	cv(\%f,'disease_status_last_followup',  {1=>'complete remission',2=>'partial_remission',
						3=>'progression',       4=>'relapse',
						5=>'stable',            6=>'no evidence of disease'});
	cv(\%f,'disease_relapse_type',          {1=>'local recurrence',  
						2=>'distant recurrence/metastasis',
						3=>'progression (liquid tumours)',   
						4=>'local recurrence and distant metastasis'
	   });
	cv(\%f,'prior_malignancy',              {1=>'yes',  2=>'no', 3=>'unknown'});
	cv(\%f,'cancer_history_first_degree_relative', {1=>'yes',  2=>'no', 3=>'unknown'});

	print $out join("\t",@f{@donor_fields}),"\n";
    }

}

sub write_specimens {
    my $project = shift;
    my @specimen_files = <$project/specimen*>;
    # potential bug here: assume that all files are compressed using
    # same compression system
    my $cat = cat(@specimen_files);

    chomp(my $fields = <$cat>);
    my @fields = split "\t",$fields;
    my %f;

    open my $out,">>./specimen.tsv" or die "$!";
    print $out join("\t",@specimen_fields),"\n";

    while (<$cat>) {
	chomp;
	next if /^donor_id/;
	@f{@fields} = map {($_==-777 or $_==-888) ? '' : $_} map {trim($_)} split "\t";
	# jiggery pokery
	my $donor_id           = get_icgc_id('donor',   $f{donor_id});
	my $specimen_id        = get_icgc_id('specimen',$f{specimen_id});
	
	$f{project_code}          = $project;
	$f{icgc_specimen_id}      = $specimen_id;
	$f{icgc_donor_id}         = $donor_id;
	$f{submitted_donor_id}    = $f{donor_id};
	$f{submitted_specimen_id} = $f{specimen_id};

	# these mappings get used later when writing out the sample info!
	$specimen2donor{$specimen_id}{icgc}      = $donor_id;
	$specimen2donor{$specimen_id}{submitted} = $f{submitted_donor_id};
	
	cv(\%f,'study_specimen_involved_in',{1=>'PCAWG'});
	cv(\%f,'specimen_type', {
	    101 => 'Normal - solid tissue',
	    102 => 'Normal - blood derived',
	    103 => 'Normal - bone marrow',
	    104 => 'Normal - tissue adjacent to primary',
	    105 => 'Normal - buccal cell',
	    106 => 'Normal - EBV immortalized',
	    107 => 'Normal - lymph node',
	    108 => 'Normal - other',
	    109 => 'Primary tumour - solid tissue',
	    110 => 'Primary tumour - blood derived (peripheral blood)',
	    111 => 'Primary tumour - blood derived (bone marrow)',
	    112 => 'Primary tumour - additional new primary',
	    113 => 'Primary tumour - other',
	    114 => 'Recurrent tumour - solid tissue',
	    115 => 'Recurrent tumour - blood derived (peripheral blood)',
	    116 => 'Recurrent tumour - blood derived (bone marrow)',
	    117 => 'Recurrent tumour - other',
	    118 => 'Metastatic tumour - NOS',
	    119 => 'Metastatic tumour - lymph node',
	    120 => 'Metastatic tumour - metastasis local to lymph node',
	    121 => 'Metastatic tumour - metastasis to distant location',
	    122 => 'Metastatic tumour - additional metastatic',
	    123 => 'Xenograft - derived from primary tumour',
	    124 => 'Xenograft - derived from tumour cell line',
	    125 => 'Cell line - derived from tumour',
	    126 => 'Primary tumour - lymph node',
	    127 => 'Metastatic tumour - other',
	    128 => 'Cell line - derived from xenograft tumour',
	   });
	cv(\%f,'specimen_donor_treatment_type', {
	    1 => 'no treatment',
	    2 => 'chemotherapy',
	    3 => 'radiation therapy',
	    4 => 'combined chemo+radiation therapy',
	    5 => 'immunotherapy',
	    6 => 'combined chemo+immunotherapy',
	    7 => 'surgery',
	    8 => 'other therapy',
	    9 => 'bone marrow transplant',
	    10 => 'stem cell transplant',
	    11 => 'monoclonal antibodies (for liquid tumours)'
	   });
	cv(\%f,'specimen_processing',{
	    1 => 'cryopreservation in liquid nitrogen (dead tissue)',
	    2 => 'cryopreservation in dry ice (dead tissue)',
	    3 => 'cryopreservation of live cells in liquid nitrogen',
	    4 => 'cryopreservation, other',
	    5 => 'formalin fixed, unbuffered',
	    6 => 'formalin fixed, buffered',
	    7 => 'formalin fixed & paraffin embedded',
	    8 => 'fresh',
	    9 => 'other technique',
	   });
	cv(\%f,'specimen_storage',{
	    1 => 'frozen, liquid nitrogen',
	    2 => 'frozen, -70 freezer',
	    3 => 'frozen, vapor phase',
	    4 => 'RNA later frozen',
	    5 => 'paraffin block',
	    6 => 'cut slide',
	    7 => 'other',
	   });
	cv(\%f,'tumour_confirmed',    {1=>'yes',2=>'no'});
	cv(\%f,'specimen_available',  {1=>'yes',2=>'no'});
	cv(\%f,'level_of_cellularity',{
	    1 => '1-20%',
	    2 => '21-40%',
	    3 => '41-60%',
	    4 => '61-80%',
	    5 => '>81%',
	   });
	print $out join("\t",@f{@specimen_fields}),"\n";
    }
}


sub write_samples {
    my $project = shift;
    my @sample_files = <$project/sample*> or return;
    # potential bug here: assume that all files are compressed using
    # same compression system
    my $cat = cat(@sample_files);

    chomp(my $fields = <$cat>);
    my @fields = split "\t",$fields;
    my %f;

    open my $out,">>./sample.tsv"  or die "$!";
    print $out join("\t",@sample_fields),"\n";

    while (<$cat>) {
	chomp;
	next if /^analyzed_sample_id/;
	@f{@fields} = map {($_==-777 or $_==-888) ? '' : $_} map {trim($_)} split "\t";
	# jiggery pokery
	my $specimen_id        = get_icgc_id('specimen',$f{specimen_id});
	my $sample_id          = get_icgc_id('sample',  $f{analyzed_sample_id});
	
	$f{project_code}            = $project;
	$f{icgc_specimen_id}        = $specimen_id;
	$f{icgc_sample_id}          = $sample_id;
	$f{icgc_donor_id}           = $specimen2donor{$specimen_id}{icgc};
	$f{submitted_donor_id}    = $specimen2donor{$specimen_id}{submitted};
	$f{submitted_specimen_id} = $f{specimen_id};
	$f{submitted_sample_id}   = $f{analyzed_sample_id};

	cv(\%f,'level_of_cellularity',{
	    1 => '1-20%',
	    2 => '21-40%',
	    3 => '41-60%',
	    4 => '61-80%',
	    5 => '>81%',
	   });
	cv(\%f,'study',{1=>'PCAWG'});
	print $out join("\t",@f{@sample_fields}),"\n";
    }
}

sub write_family {
    my $project = shift;
    my @family_files = <$project/family*> or return;
    my $f = cat(@family_files);

    chomp(my $fields = <$f>);
    my @fields = split "\t",$fields;
    my %f;

    open my $out,">>./donor_family.tsv"  or die "$!";
    print $out join("\t",@donor_family_fields),"\n";

    while (<$f>) {
	chomp;
	next if /^donor_id/;
	@f{@fields} = map {($_==-777 or $_==-888) ? '' : $_} map {trim($_)} split "\t";
	# jiggery pokery
	my $donor_id          = get_icgc_id('donor',  $f{donor_id});
	
	$f{project_code}       = $project;
	$f{icgc_donor_id}      = $donor_id;
	$f{submitted_donor_id} = $f{donor_id};
	cv(\%f,'donor_has_relative_with_cancer_history',{1=>'yes',2=>'no',3=>'unknown'});
	cv(\%f,'relationship_type',{
	    1 => 'sibling',
	    2 => 'parent',
	    3 => 'grandparent',
	    4 => 'uncle/aunt',
	    5 => 'cousin',
	    6 => 'other',
	    7 => 'unknown'
	   });
	cv(\%f,'relationship_sex',{1=>'male',2=>'female',3=>'unknown'});
	print $out join("\t",@f{@donor_family_fields}),"\n";
    }
}

sub write_exposure {
    my $project = shift;
    my @exposure_files = <$project/exposure*> or return;
    my $cat = cat(@exposure_files);

    chomp(my $fields = <$cat>);
    my @fields = split "\t",$fields;
    my %f;

    open my $out,">>./donor_exposure.tsv"  or die "$!";
    print $out join("\t",@donor_exposure_fields),"\n";

    while (<$cat>) {
	chomp;
	next if /^donor_id/;
	@f{@fields} = map {($_==-777 or $_==-888) ? '' : $_} map {trim($_)} split "\t";
	# jiggery pokery
	my $donor_id          = get_icgc_id('donor',  $f{donor_id});
	
	$f{project_code}       = $project;
	$f{icgc_donor_id}      = $donor_id;
	$f{submitted_donor_id} = $f{donor_id};
	cv(\%f,'tobacco_smoking_history_indicator',{
	    1 => 'Lifelong non-smoker (<100 cigarettes smoked in lifetime)',
	    2 => 'Current smoker (includes daily smokers non-daily/occasional smokers)',
	    3 => 'Current reformed smoker for > 15 years',
	    4 => 'Current reformed smoker for <= 15 years',
	    5 => 'Current reformed smoker, duration not specified',
	    6 => 'Smoking history not documented',
	   });
	cv(\%f,'alcohol_history', {1=>'yes',2=>'no',3=>"Don't know/Not sure"});
	cv(\%f,'alcohol_history_intensity',{
	    1 => 'None',
	    2 => 'Social Drinker (> once a month, < once a week)',
	    3 => 'Weekly Drinker (>=1x a week)',
	    4 => 'Daily Drinker',
	    5 => 'Occasional Drinker (< once a month)',
	    6 => 'Not Documented',
	   });
	print $out join("\t",@f{@donor_exposure_fields}),"\n";
    }
}

sub write_therapy {
    my $project = shift;
    my @therapy_files = <$project/therapy*> or return;
    my $cat = cat(@therapy_files);

    chomp(my $fields = <$cat>);
    my @fields = split "\t",$fields;
    my %f;

    open my $out,">>./donor_therapy.tsv"  or die "$!";
    print $out join("\t",@donor_therapy_fields),"\n";

    while (<$cat>) {
	chomp;
	next if /^donor_id/;
	@f{@fields} = map {($_==-777 or $_==-888) ? '' : $_} map {trim($_)} split "\t";
	# jiggery pokery
	my $donor_id          = get_icgc_id('donor',  $f{donor_id});
	
	$f{project_code}       = $project;
	$f{icgc_donor_id}      = $donor_id;
	$f{submitted_donor_id} = $f{donor_id};
	for my $order ('first','second') {
	    cv(\%f,"${order}_therapy_type",{
		1 => 'no treatment',
		2 => 'chemotherapy',
		3 => 'radiation therapy',
		4 => 'combined chemo+radiation therapy',
		5 => 'immunotherapy',
		6 => 'combined chemo+immunotherapy',
		7 => 'surgery',
		8 => 'other therapy',
		9 => 'bone marrow transplant',
		10 => 'stem cell transplant',
		11 => 'monoclonal antibodies (for liquid tumours)',
	       });
	    cv(\%f,"${order}_therapy_response",{
		1 => 'complete response',
		2 => 'partial response',
		3 => 'disease progression',
		4 => 'stable disease',
		5 => 'unknown',
	       });
	    cv(\%f,"${order}_therapy_therapeutic_intent",{
		1 => 'not applicable',
		2 => 'adjuvant',
		3 => 'curative',
		4 => 'palliative',
	       });
	}
	print $out join("\t",@f{@donor_therapy_fields}),"\n";
    }
}

sub cat {
    my @files = @_;
    my $f;
    if ($files[0] =~ /\.gz$/) {
	open $f,"gunzip -c @files|";
    } elsif ($files[0] =~ /\.bz2$/) {
	open $f,"bunzip2 -c @files|";
    } else {
	open $f,"cat @files |";
    }
    return $f;
}

sub cv {
    my ($hash,$field,$dictionary) = @_;
    $hash->{$field} = $dictionary->{$hash->{$field}};
}

sub trim {
    my $f = shift;
    $f =~ s/^\s+|\s+$//g; 
    return $f;
}
