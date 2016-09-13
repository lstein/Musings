#!/usr/bin/perl

# this ad-hoc script has three tasks:
#  1. Add the icd-0-3 organ system code column to each of the donors.
#  2. Harmonize the text descriptions of the histological subtypes.
#  3. Add missing icd-0-3 histological subtype codes.

use constant ORGAN_MAPPINGS => 'organ_mappings.txt';
use constant HISTO_MAPPINGS => 'histo_mappings.txt';

my @new_field_names = get_field_names();
my $organs          = parse_organs(ORGAN_MAPPINGS);  # {$project} = $organ
my $histo           = parse_histo (HISTO_MAPPINGS);  # {$project}{$pattern}{'code'|'description'|'comment'}

# we expect the merged subtypes file on STDIN
chomp(my $topline = <>);
$topline =~ s/^#\s+//;
my @field_names = split "\t",$topline;

print '# ',join("\t",@new_field_names),"\n";
while (<>) {
    chomp;
    next if /^#/;
    my %fields;
    @fields{@field_names} = split "\t";
    my $project           = $fields{project_code};
    my $histo_desc        = $fields{tumour_histological_type};

    # add the organ system
    $fields{organ_system} = $organs->{$project};

    # potentially munge the histological code and description
    if (my $patterns = $histo->{$project}) {
	my @patterns = keys %$patterns;
	for my $p (sort {length($b)<=>length($a)} @patterns) { # match longer patterns first
	    my $regex = quotemeta($p);
	    if ($regex eq '' || $histo_desc =~ /$regex/i) {
		replace(\%fields,@{$patterns->{$p}}{'code','description','comment'});
		last;
	    }
	}
    }

    # Some basic cleanup of the histological type
    $fields{tumour_histological_type} =~ s/"//g;
    $fields{tumour_histological_type} =~ s/^\s+//;
    $fields{tumour_histological_type} =~ s/\s+$//;
    $fields{tumour_histological_type} =~ s/\bnos\b/NOS/;
    $fields{tumour_histological_type} = ucfirst($fields{tumour_histological_type});
    undef $fields{tumour_histological_type} if $fields{tumour_histological_type} =~ /not available/i;

    $_ = join "\t",@fields{@new_field_names};
} continue {
    print $_,"\n";
}

exit 0;

sub replace {
    my $fields = shift;
    my ($code,$description,$comment) = @_;
    my $old_description = $fields->{tumour_histological_type} || $fields->{tumour_histological_code};
    $fields->{tumour_histological_type}     = $description;
    $fields->{tumour_histological_code}     = $code;
    $fields->{tumour_histological_comment}  = $comment;
    $fields->{tumour_original_histology}    = $old_description;
}

sub parse_organs {
    my $file = shift;
    my %results;
    open my $f,'<',$file or die "$file: $!";
    while (<$f>) {
	chomp;
	next if /^#/;
	my ($project,$organ) = split "\t";
	$results{$project}=$organ;
    }
    close $f;
    return \%results;
}

sub parse_histo {
    my $file = shift;
    my %results;
    open my $f,'<',$file or die "$file: $!";
    while (<$f>) {
	chomp;
	next if /^#/;
	my ($project,$pattern,$code,$description,$comment) = split "\t";
	$results{$project}{$pattern}{description} = $description;
	$results{$project}{$pattern}{code}        = $code;
	$results{$project}{$pattern}{comment}     = $comment;
    }
    close $f;
    return \%results;
}

sub get_field_names {
    return qw(
donor_unique_id
project_code
icgc_donor_id
submitted_donor_id
tcga_donor_uuid
icgc_specimen_id
submitted_specimen_id
tcga_specimen_uuid
icgc_sample_id
submitted_sample_id
tcga_sample_uuid
donor_sex
donor_vital_status
organ_system
tumour_histological_code
tumour_histological_type
donor_diagnosis_icd10
specimen_donor_treatment_type
first_therapy_type
first_therapy_response
tumour_stage
tumour_grade
donor_age_at_diagnosis
donor_survival_time
donor_interval_of_last_followup
tobacco_smoking_history_indicator
tobacco_smoking_intensity
alcohol_history
alcohol_history_intensity
percentage_cellularity
level_of_cellularity
tcga_expert_re-review
tumour_histological_comment
tumour_original_histology
donor_wgs_white_black_gray
specimen_library_strategy
);
}
