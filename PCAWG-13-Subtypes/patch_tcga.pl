#!/usr/bin/perl

# patch 'missing_histology_March2016.TCGA.KH.txt' into 'histological_subtypes_release_aug2015.KH.TCGA.txt'
# so that I can run the same merge script

use strict;
use constant BARCODES   => './tcga_uuid2barcode.txt';  # for translation purposes
use constant TCGA_MAIN  => './August2015_Dataset/histological_subtypes_release_aug2015.KH.TCGA.txt';
use constant TCGA_PATCH => './March2016_Dataset/missing_histology_March2016.TCGA.KH.txt';

my $patchfile = shift || TCGA_PATCH;

my $barcode2uuid  = parse_barcodes(BARCODES);

open my $f,'<',TCGA_MAIN or die $!;
chomp(my $line = <$f>);
my @output_fields = split "\t",$line;
close $f;

open $f,'<',$patchfile or die $!;
chomp($line = <$f>);
my @input_fields = split "\t",$line;

print join("\t",@output_fields),"\n";

my (%i,%o);
while (<$f>) {
    chomp;
    @i{@input_fields}         = split "\t";
    $o{project_code}          = $i{Project};
    $o{submitted_donor_id}    = $barcode2uuid->{$i{Donor}}    or die "$i{Donor}: missing uuid";
    $o{submitted_specimen_id} = $barcode2uuid->{$i{Specimen}} or die "$i{Specimen}: missing uuid";
    $o{Barcode}               = $i{Specimen};
    $o{patient}               = $i{Donor};
    ($o{Disease})             = $i{Project} =~ /^(\w+)/;
    $o{'Sample Type'}         = $i{'Sample Type'};
    $o{'Shipped Histology'}   = $i{'Shipped Histology'};
    $o{'diagnosis_subtype/Other classification'} = $i{'diagnosis_subtype/Other classification'};
    print join("\t",@o{@output_fields}),"\n";
}

exit 0;

sub parse_barcodes {
    my $file = shift;
    my %barcode2uuid;
    open my $f,'<',$file or die "$file: $!";
    while (<$f>) {
	chomp;
	my ($project,$type,$uuid,$barcode) = split "\t";
	$barcode2uuid{$barcode} = $uuid;
    }
    close $f;
    return \%barcode2uuid;
}



