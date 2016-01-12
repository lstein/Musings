#!/usr/bin/perl

use strict;

use Getopt::Long;

use constant ICD_CODES => 'sitetype.icdo3.d20150918.csv';    # http://seer.cancer.gov/icd-o-3/
use constant TCGA_UUID2BARCODE=> 'tcga_uuid2barcode.txt';    # From Junjun Zhang, 5 October 2015. Translates TCGA uuids into barcodes
use constant RELEASE_MANIFEST => './release_aug2015.v1.tsv'; # https://wiki.oicr.on.ca/display/PANCANCER/Available+PCAWG+Data#AvailablePCAWGData-August2015Dataset
use constant PCAWG_SPECIMENS => './August2015_Dataset/specimen.tsv';

my ($PCAWG_SPECIMENS,$RELEASE_MANIFEST);

GetOptions('specimens=s' => \$PCAWG_SPECIMENS,
	   'manifest=s'  => \$RELEASE_MANIFEST) or die <<END;
Usage: $0 [options]

  --specimens     Path to specimen.tsv downloaded from DCC portal
  --manifest      Path to manifest.tsv downloaded from PanCancer WIKI
END

$PCAWG_SPECIMENS  ||= PCAWG_SPECIMENS;
$RELEASE_MANIFEST ||= RELEASE_MANIFEST;

my $codes                     = parse_codes(ICD_CODES);
my ($samples,$pcawg_donors)   = parse_specimens($RELEASE_MANIFEST);  # $samples->{project,donor,specimen} = TRUE
my ($tcga_uuids,$tcga_donors) = parse_uuids(TCGA_UUID2BARCODE);  # $tcga_uuids->{$barcode}=$specimen_uuid

my $to_open = $PCAWG_SPECIMENS =~ /\.gz/ ? "gunzip -c $PCAWG_SPECIMENS|" : $PCAWG_SPECIMENS;

open my $f,$to_open or die $PCAWG_SPECIMENS,": $!";
chomp(my $header = <$f>);
my @fields = split "\t",$header;
my (%fields,%found,%not_found,%dcc_donors,$total);

print join("\t",qw(project_code submitted_donor_id submitted_specimen_id
                   tumour_histological_code tumour_histological_type tumour_grade tumour_stage 
                   percentage_cellularity level_of_cellularity)),"\n";
open STDOUT,"| sort";

while (<$f>) {
    chomp;
    my @t            = split "\t";

    for (0..@fields-1) {
	$t[$_] = 'N/A' unless length($t[$_]);
	$t[$_] = 'N/A' if $t[$_] eq 'unknown';
    }

    @fields{@fields} = @t;
    $fields{percentage_cellularity} =~ s/%//g;

    my ($project,$donor,$specimen) = @fields{'project_code','submitted_donor_id','submitted_specimen_id'};
    my $specimen_uuid = $tcga_uuids->{$specimen} || $specimen;
    my $donor_uuid    = $tcga_donors->{$donor}   || $donor;
    $dcc_donors{$project}{$donor_uuid}++;
    $total++;
    unless ($samples->{$project,$donor_uuid,$specimen_uuid}) {
	$not_found{$project}{$specimen_uuid}++;
	next;
    }
    
    $found{$project}++;
    my $tumour_histological_code = $fields{tumour_histological_type};
    my $type                     = $codes->{$tumour_histological_code} || $tumour_histological_code;
    $type =~ lcfirst($type);
    my $free_text = $tumour_histological_code !~ /^\d+/;
    print join ("\t",
		$project,$donor_uuid,$specimen_uuid,
		($free_text ? '' : $tumour_histological_code),
		$type,
		@fields{'tumour_grade','tumour_stage','percentage_cellularity','level_of_cellularity'}),"\n";
}

for my $p (sort keys %found) {
    print STDERR join("\t",$p,$found{$p}),"\n";
}
print STDERR "TOTAL = $total\n";
print STDERR "\n";
print STDERR "In DCC but not listed in PCAWG manifest:\n";
for my $project (sort keys %not_found) {
    for my $donor (sort keys %{$not_found{$project}}) {
	print STDERR $project,"\t",$donor,"\n";
    }
}
print STDERR "\n";
print STDERR "In PCAWG manifest but donor not found in DCC:\n";
for my $project (sort keys %$pcawg_donors) {
    for my $donor (sort keys %{$pcawg_donors->{$project}}) {
	next if $dcc_donors{$project}{$donor};
	print STDERR join ("\t",$project,$donor),"\n";
    }
}


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

sub parse_specimens {
    my $file = shift;
    my %specimens; # [0,1,11]
    my %donors;
    my (@field_labels,%fields);
    open my $f,$file or die "$file: $!";
    while (<$f>) {
	chomp;
	my @fields = split "\t";
	if (/dcc_project_code/) { # first line, get fields
	    @field_labels = @fields;
	    next;
	}
	@fields{@field_labels} = @fields;
	my ($project,$donor,$specimen) = @fields{'dcc_project_code','submitter_donor_id','tumor_wgs_submitter_specimen_id'};
	$specimens{$project,$donor,$specimen}++;
	$donors{$project}{$donor}++;
    }
    return (\%specimens,\%donors);
}

sub parse_uuids {
    my $file = shift;
    my (%uuids,%donors);
    open my $f,$file or die "$file: $!";
    while (<$f>) {
	chomp;
	my ($project,$barcode_type,$uuid,$barcode) = split "\t";
	$uuids{$barcode}  = $uuid if $barcode_type eq 'specimen';
	$donors{$barcode} = $uuid if $barcode_type eq 'donor';
    }
    return (\%uuids,\%donors);
}
