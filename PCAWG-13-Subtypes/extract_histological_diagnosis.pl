#!/usr/bin/perl

use strict;
 
use Getopt::Long;

use constant ICD_CODES         => 'sitetype.icdo3.d20150918.csv';    # http://seer.cancer.gov/icd-o-3/
use constant TCGA_UUID2BARCODE => 'tcga_uuid2barcode.txt';           # From Junjun Zhang, 5 October 2015. Translates TCGA uuids into barcodes
use constant RELEASE_MANIFEST  => './release_aug2015.v1.tsv';        # https://wiki.oicr.on.ca/display/PANCANCER/Available+PCAWG+Data#AvailablePCAWGData-August2015Dataset
use constant CLINICAL_BASE     => './October2015_Dataset';
use constant REFERENCE_BASE    => '.';

my ($REFERENCE_BASE,$CLINICAL_BASE,$RELEASE_MANIFEST);

GetOptions('reference=s' => \$REFERENCE_BASE,
           'clinical=s'  => \$CLINICAL_BASE,
	   'manifest=s'  => \$RELEASE_MANIFEST) or die <<END;
Usage: $0 [options]
  --reference_base  Path to where the reference files (sitetype and tcga uuids) can be found
  --clinical        Path to directory containing unpacked donor files downloaded from DCC portal
                     (must contain sample.tsv.gz, specimen.tsv.gz, donor.tsv.gz, etc)
  --manifest        Path to manifest.tsv downloaded from PanCancer WIKI
END
    ;

$REFERENCE_BASE   ||= REFERENCE_BASE;
$CLINICAL_BASE    ||= CLINICAL_BASE;
$RELEASE_MANIFEST ||= RELEASE_MANIFEST;

my $codes           = parse_codes("$REFERENCE_BASE/".ICD_CODES);
my $uuid2barcode    = parse_uuids("$REFERENCE_BASE/".TCGA_UUID2BARCODE);  # $uuid2barcode->{type}{$uuid}

# hash indexed by PCAWG donor_unique_id
# note that there can be multiple specimens & samples in each field, separated by commas
my $pcawg           = generic_parse($RELEASE_MANIFEST);

# hash indexed by icgc_specimen_id
my $specimens       = generic_parse("$CLINICAL_BASE/specimen.tsv.gz");

# hash indexed by icgc_ssample_id
my $samples         = generic_parse("$CLINICAL_BASE/sample.tsv.gz");

# hash indexed by icgc_donor_id
my $donor           = generic_parse("$CLINICAL_BASE/donor.tsv.gz");
my $donor_family    = generic_parse("$CLINICAL_BASE/donor_family.tsv.gz");
my $donor_exposure  = generic_parse("$CLINICAL_BASE/donor_exposure.tsv.gz");
my $donor_therapy   = generic_parse("$CLINICAL_BASE/donor_therapy.tsv.gz");

# to handle TCGA donors/samples/specimens, need to translate from submitter_id to icgc_id
my $tcga_donor      = translate_tcga_id('donor',   $donor);
my $tcga_specimen   = translate_tcga_id('specimen',$specimens);
my $tcga_sample     = translate_tcga_id('sample',  $samples);

print join("\t",qw(donor_unique_id
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
                   tobacco_soking_intensity
                   alcohol_history
                   alcohol_history_intensity
                   tumour_percentage_cellularity
                   tumour_level_of_cellularity)),"\n";
# open STDOUT,"| sort";

for my $pcawg_id (keys %$pcawg) {

    my ($donor_id,@specimen_id,@sample_id,$tcga_donor_uuid,@tcga_specimen_uuid,@tcga_sample_uuid);

    # In the PCAWG manifest file, the icgc_donor_id doesn't match what you download
    # from the portal. Instead it is a TCGA UUID, which needs to be mapped onto a TCGA "barcode".
    # The barcode then corresponds to an ICGC submitter_donor_id. Horrible.
    if ($pcawg->{$pcawg_id}{dcc_project_code} =~ /US$/) {
	my $donor_uuid      = $pcawg->{$pcawg_id}{submitter_donor_id}; # NOT the same as the submitter_id in the DCC dump
	my @specimen_uuids  = split ',',$pcawg->{$pcawg_id}{tumor_wgs_submitter_specimen_id};
	my @sample_uuids    = split ',',$pcawg->{$pcawg_id}{tumor_wgs_submitter_sample_id};

	$donor_id           = $tcga_donor->{$uuid2barcode->{donor}{$donor_uuid}};
	@specimen_id        = map {$tcga_specimen->{$uuid2barcode->{specimen}{$_}}} @specimen_uuids;
	@sample_id          = map {$tcga_sample->{$uuid2barcode->{sample}{$_}}    } @sample_uuids;
    }

    # this is the ICGC case
    else {
	$donor_id     = $pcawg->{$pcawg_id}{icgc_donor_id};
	@specimen_id  = split ',',$pcawg->{$pcawg_id}{tumor_wgs_icgc_specimen_id};
	@sample_id    = split ',',$pcawg->{$pcawg_id}{tumor_wgs_icgc_sample_id};
    }

    unless ($donor->{$donor_id}) {
	$MISSING{$donor_id}++;
	next;
    }

    # now we can FINALLY print out our data!
    print join ("\t",
		$donor_id,
		
	),"\n;

}

# for my $p (sort keys %found) {
#     print STDERR join("\t",$p,$found{$p}),"\n";
# }
# print STDERR "TOTAL = $total\n";
# print STDERR "\n";
# print STDERR "In DCC but not listed in PCAWG manifest:\n";
# for my $project (sort keys %not_found) {
#     for my $donor (sort keys %{$not_found{$project}}) {
# 	print STDERR $project,"\t",$donor,"\n";
#     }
# }
# print STDERR "\n";
# print STDERR "In PCAWG manifest but donor not found in DCC:\n";
# for my $project (sort keys %$pcawg_donors) {
#     for my $donor (sort keys %{$pcawg_donors->{$project}}) {
# 	next if $dcc_donors{$project}{$donor};
# 	print STDERR join ("\t",$project,$donor),"\n";
#     }
# }


exit 0;

sub parse_codes {
    my $file = shift;

    my %codes;
    open my $f,$file or die "$file: $!";
    while (<$f>) {
	chomp;
	my ($name, $code,$desc) = (split("\t",$_))[3,4,5];
	$codes{$code} = $desc;
    }
    return \%codes;
}

sub generic_parse {
    my $file = shift;
    my $pipe = $file =~ /\.gz$/ ? "gunzip -c $file |" : $file;
    open my $f,$pipe or die "$file: $!";

    # get fields on first line
    chomp (my $line = <$f>);
    my @field_labels = split "\t",$line;

    # create associative array, indexed by the first field in the line
    # which is some sort of ICGC id.
    my %data;
    while (<$f>) {
	chomp;
	my @fields = split "\t";
	@{$data{$fields[0]}}{@field_labels} = @fields;
    }
    close $file;
    return \%data;
}

sub parse_uuids {
    my $file = shift;
    my %uuids;
    open my $f,$file or die "$file: $!";
    while (<$f>) {
	chomp;
	my ($project,$barcode_type,$uuid,$barcode) = split "\t";
	$uuids{$barcode_type}{$uuid} = $barcode;
    }
    return \%uuids;
}

sub translate_tcga_id {
    my ($prefix,$hash) = @_;
    my $field = "submitted_${prefix}_id";
    my %table;
    for my $dcc_id (keys %$hash) {
	my $submitter_id = $hash->{$dcc_id}{$field};
	$table{$submitter_id} = $dcc_id;
    }
    return \%table;
}
