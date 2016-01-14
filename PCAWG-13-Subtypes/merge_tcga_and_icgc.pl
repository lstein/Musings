#!/usr/bin/perl

# this script merges the TCGA histological subtypes file produced by
# Katie Hoadley
# (e.g. histological_subtypes_release_aug2015.KH.TCGA.txt)
# with the donor/subtypes file produced by Lincoln Stein
# (e.g. histological_subtypes_and_clinical_release_oct2015.tsv)

use strict;
use Getopt::Long;
my ($TCGA_FILE,$ICGC_FILE);

GetOptions('tcga=s'  => \$TCGA_FILE,
           'icgc=s'  => \$ICGC_FILE) or die <<END;
Usage: $0 [options]
  --icgc         Path to the ICGC clinical/histology file
  --tcga         Path to the TCGA histology file
END

    ;

-r $TCGA_FILE && -r $ICGC_FILE or die "Please provide valid paths to both the ICGC and TCGA files. Use -h for usage";

my $tcga_uuids = parse_tcga($TCGA_FILE);
do_merge($ICGC_FILE,$tcga_uuids);

exit 0;

sub parse_tcga {
    my $file = shift;

    $file = "gunzip -c $file | " if $file =~ /\.gz/;
    open my $f,$file or die "$file: $!";

    local $/ = "\r\n";

    chomp (my $header = <$f>);
    my @field_names = split "\t",$header;

    my %specimen_uuids;

    while (<$f>) {
	chomp;
	my %fields;
	@fields{@field_names} = map { /NA|NULL/ ? undef : $_ } split "\t";
	my $id = $fields{submitted_specimen_id} or die "Specimen ID is missing at line $.";
	$specimen_uuids{$id} = \%fields;
    }
    close $f;
    return \%specimen_uuids;
}

sub do_merge {
    my ($file,$tcga_uuids) = @_;
    $file = "gunzip -c $file | " if $file =~ /\.gz/;
    open my $f,$file or die "$file: $!";

    # get header
    chomp (my $header = <$f>);
    $header =~ s/^#\s+//;
    my @field_names = split "\t",$header;
    
    print "# $header\ttcga_expert_re-review\n";
    while (<$f>) {
	chomp;
	next if /^#/;

	# do we have a match?
	my %fields;
	@fields{@field_names} = split "\t";
	my $tcga_id   = $fields{tcga_specimen_uuid} or next;
	my $tcga_data = $tcga_uuids->{$tcga_id}     or next;
	
	# good, we have a match; fill in the missing fields
	my $shipped_histo = $tcga_data->{'Shipped Histology'};
	my $subtype       = $tcga_data->{'diagnosis_subtype/Other classification'};
	my $rereview      = $tcga_data->{'"EPC - Expert Pathology Committee, re-review of TCGA samples"'};
	my $top_cellularity  = $tcga_data->{'TOP-percentTumorNuclei'};
	my $bot_cellularity  = $tcga_data->{'BOT-percentTumorNuclei'};
	my $level_cellularity= $bot_cellularity ? "$bot_cellularity-$top_cellularity" : $top_cellularity;

	$fields{tumour_histological_type} = $subtype ? "$shipped_histo, $subtype" : $shipped_histo;
	$fields{percentage_cellularity}  = $top_cellularity;
	$fields{level_of_cellularity}    = $level_cellularity;
	
	$_ = join "\t",@fields{@field_names},$rereview;

    } continue {
	print "$_\n";
    }

    close $f;
}
