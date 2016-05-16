#!/usr/bin/perl

use strict;
 
use Getopt::Long;

use constant ICD_CODES         => 'sitetype.icdo3.d20150918.csv';    # http://seer.cancer.gov/icd-o-3/
use constant TCGA_UUID2BARCODE => 'tcga_uuid2barcode.txt';           # From Junjun Zhang, 5 October 2015. Translates TCGA uuids into barcodes
use constant CLINICAL_BASE     => './February2016_Dataset';
use constant RELEASE_MANIFEST  => 'pcawg_sample_sheet.tsv';          # http://pancancer.info/gnos_metadata/latest/reports/pcawg_sample_sheet.tsv
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
$RELEASE_MANIFEST ||= $CLINICAL_BASE .'/'. RELEASE_MANIFEST;

my $codes           = parse_codes("$REFERENCE_BASE/".ICD_CODES);
my $uuid2barcode    = parse_uuids("$REFERENCE_BASE/".TCGA_UUID2BARCODE);  # $uuid2barcode->{type}{$uuid}

# hash indexed by PCAWG donor_unique_id
# note that there can be multiple specimens & samples in each field, separated by commas
my $pcawg            = parse_pcawg($RELEASE_MANIFEST);   # {$donor_id}{$sample_id}{@fields}

# hash indexed by icgc_specimen_id
my $specimen        = generic_parse("$CLINICAL_BASE/specimen.tsv.gz");

# hash indexed by icgc_sample_id
my $sample          = generic_parse("$CLINICAL_BASE/sample.tsv.gz");

# hash indexed by icgc_donor_id
my $donor           = generic_parse("$CLINICAL_BASE/donor.tsv.gz");
my $donor_family    = generic_parse("$CLINICAL_BASE/donor_family.tsv.gz");
my $donor_exposure  = generic_parse("$CLINICAL_BASE/donor_exposure.tsv.gz");
my $donor_therapy   = generic_parse("$CLINICAL_BASE/donor_therapy.tsv.gz");

# to handle TCGA donors/samples/specimens, need to translate from submitter_id to icgc_id
my $tcga_donor      = translate_tcga_id('donor',   $donor);
my $tcga_specimen   = translate_tcga_id('specimen',$specimen);
my $tcga_sample     = translate_tcga_id('sample',  $sample);

print '# ',join("\t",qw(donor_unique_id
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
                   tobacco_smoking_intensity
                   alcohol_history
                   alcohol_history_intensity
                   percentage_cellularity
                   level_of_cellularity)),"\n";

# open STDOUT,"| sort";

my %MISSING;
for my $pcawg_id (keys %$pcawg) {

    # be careful to reset
    my ($donor_id,@specimen_id,@sample_id,$tcga_donor_uuid,
	@tcga_specimen_uuid,@tcga_sample_uuid,@submitter_specimen_id,@submitter_sample_id,
	@specimen_uuids,@sample_uuids) = ();

    # a little hairy here... we are going for only those specimen types marked "tumour"
    # which have been sequenced using a WGS strategy.
    my @sample_ids   = grep {$pcawg->{$pcawg_id}{$_}{dcc_specimen_type} =~ /tumour/i &&
				 $pcawg->{$pcawg_id}{$_}{library_strategy}  =~ /WGS/
    } keys %{$pcawg->{$pcawg_id}};

    # In the PCAWG manifest file, the icgc_donor_id doesn't match what you download
    # from the portal. Instead it is a TCGA UUID, which needs to be mapped onto a TCGA "barcode".
    # The barcode then corresponds to an ICGC submitter_donor_id. Horrible.
    if ($pcawg->{$pcawg_id}{$sample_ids[0]}{dcc_project_code} =~ /US$/) {
	$tcga_donor_uuid = $pcawg->{$pcawg_id}{$sample_ids[0]}{submitter_donor_id}; # NOT the same as the submitter_id in the DCC dump
	@specimen_uuids  =  map {$pcawg->{$pcawg_id}{$_}{'submitter_specimen_id'}} @sample_ids;
	@sample_uuids    =  map {$pcawg->{$pcawg_id}{$_}{'submitter_sample_id'}} @sample_ids;
	
	$donor_id              = $tcga_donor->{$uuid2barcode->{donor}{$tcga_donor_uuid}};
	@submitter_specimen_id = map {$uuid2barcode->{specimen}{$_}} @specimen_uuids;
	@submitter_sample_id   = map {$uuid2barcode->{sample}{$_}}   @sample_uuids;
	@specimen_id           = map {$tcga_specimen->{$_}}          @submitter_specimen_id;
	@sample_id             = map {$tcga_sample->{$_}  }          @submitter_sample_id;
    }

    # this is the ICGC case
    else {
	$donor_id               = $pcawg->{$pcawg_id}{$sample_ids[0]}{icgc_donor_id};
	@submitter_specimen_id  = map {$pcawg->{$pcawg_id}{$_}{'submitter_specimen_id'}} @sample_ids;
	@submitter_sample_id    = map {$pcawg->{$pcawg_id}{$_}{'submitter_sample_id'}  } @sample_ids;
	@specimen_id            = map {$pcawg->{$pcawg_id}{$_}{'icgc_specimen_id'}     } @sample_ids;
	@sample_id              = map {$pcawg->{$pcawg_id}{$_}{'icgc_sample_id'}       } @sample_ids;
    }

    unless ($donor->{$donor_id}) {
	$MISSING{$donor_id}++;
	print "# $pcawg_id\tMISSING FROM DCC\n";
	next;
    }
    
    # now we can FINALLY print out our data!
    for (my $i=0;$i<@specimen_id;$i++) {
	print join ("\t",
		    $pcawg_id,
		    $donor->{$donor_id}{project_code},
		    $donor_id,
		    $donor->{$donor_id}{submitted_donor_id},
		    $tcga_donor_uuid,
		    $specimen_id[$i],
		    $submitter_specimen_id[$i],
		    $specimen_uuids[$i],
		    $sample_id[$i],
		    $submitter_sample_id[$i],
		    $sample_uuids[$i],
		    $donor->{$donor_id}{donor_sex},
		    $donor->{$donor_id}{donor_vital_status},
		    histology_fields($specimen->{$specimen_id[$i]}),
		    $donor->{$donor_id}{donor_diagnosis_icd10},
		    $specimen->{$specimen_id[$i]}{specimen_donor_treatment_type},
		    $donor_therapy->{$donor_id}{first_therapy_type},
		    $donor_therapy->{$donor_id}{first_therapy_response},
		    $specimen->{$specimen_id[$i]}{tumour_stage},
		    $specimen->{$specimen_id[$i]}{tumour_grade},
		    $donor->{$donor_id}{donor_age_at_diagnosis},
		    $donor->{$donor_id}{donor_survival_time},
		    $donor->{$donor_id}{donor_interval_of_last_followup},
		    $donor_exposure->{$donor_id}{tobacco_smoking_history_indicator},
		    $donor_exposure->{$donor_id}{tobacco_smoking_intensity},
		    $donor_exposure->{$donor_id}{alcohol_history},
		    $donor_exposure->{$donor_id}{alcohol_intensity},
		    $sample->{$sample_id[$i]}{percentage_cellularity} || $specimen->{$specimen_id[$i]}{percentage_cellularity},
		    $sample->{$sample_id[$i]}{level_of_cellularity} || $specimen->{$specimen_id[$i]}{level_of_cellularity},
	    ),"\n";
    }
}
close STDOUT;

exit 0;

sub histology_fields {
    my $specimen = shift;
    my $tumour_histological_code = $specimen->{tumour_histological_type};
    my $type                     = $codes->{$tumour_histological_code} || $tumour_histological_code;
    $type         = lcfirst($type);
    my $free_text = $tumour_histological_code !~ /^\d+/;
    return (($free_text ? '' : $tumour_histological_code),$type);
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

sub parse_pcawg {
    my $file = shift;
    my $pipe = $file =~ /\.gz$/ ? "gunzip -c $file |" : $file;
    open my $f,$pipe or die "$file: $!";

    # get fields on first line
    chomp (my $line = <$f>);
    my @field_labels = split "\t",$line;

    # create associative array, indexed by the first field in the line which is some sort of ICGC id.
    my %data;
    while (<$f>) {
	chomp;
	my %f;
	@f{@field_labels} = split "\t";
	my ($donor_unique_id,$icgc_sample_id)     = @f{'donor_unique_id','icgc_sample_id','aliquot_id'};
	# hack alert - we don't handle multiple aliquots well; just record multiple library strategy techniques
	# for use in pattern match in main loop.
	if ($data{$donor_unique_id}{$icgc_sample_id}) { # duplicate sample, must be due to an additional aliquot
	    $data{$donor_unique_id}{$icgc_sample_id}{library_strategy} .= " $f{library_strategy}";  
	} else {
	    $data{$donor_unique_id}{$icgc_sample_id}  = \%f;
	}
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
