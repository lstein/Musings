#!/usr/bin/perl
use strict;

# Ad-hoc script to attach histological diagnoses to the tumour histology
# based on the project codes.
# Operates on the file "specimen_histology_*.tsv", and adds a comment
# to tumour_histological_comment to indicate interpolation
my %patch;
while (<DATA>) {
    chomp;
    my ($project,@fields) = split "\t";
    $patch{$project} = \@fields;
}

my (@field_names,%fields);
while (<>) {
    chomp;

    if (/^#/) {
	s/^#\s+//;
	@field_names = split "\t";
	$_ = "# $_";
	next;
    }

    @fields{@field_names} = split "\t";
    next if $fields{histology_abbreviation};

    if (my $patch = $patch{$fields{project_code}}) {
	
	@fields{qw(organ_system 
               histology_abbreviation
               histology_tier1	
               histology_tier2	
               histology_tier3	
               histology_tier4	
               tumour_histological_code)} = @$patch;
	$fields{tumour_histological_comment} .= 'WARNING: Tumour histology inferred from project name. Not known to be confirmed by path review.';
    } else {
	$fields{donor_wgs_included_excluded} = 'Excluded';
    }

    $_ = join("\t",@fields{@field_names}),"\n";
}

continue {
    print $_,"\n";
}

__DATA__
BRCA-UK	BREAST	Breast-AdenoCA	ECTODERM	Breast	Adenocarcinoma	Infiltrating duct carcinoma	'8500/3	Infiltrating duct carcinoma, NOS
BRCA-EU	BREAST	Breast-AdenoCA	ECTODERM	Breast	Adenocarcinoma	Infiltrating duct carcinoma	'8500/3	Infiltrating duct carcinoma, NOS
BRCA-US	BREAST	Breast-AdenoCA	ECTODERM	Breast	Adenocarcinoma	Infiltrating duct carcinoma	'8500/3	Infiltrating duct carcinoma, NOS
SARC-US	BONES & JOINTS	Bone-Leiomyo	MESODERM	Bone/SoftTissue	Sarcoma, soft tissue	Leiomyosarcoma	'8890/3	Leiomyosarcoma, NOS
PACA-CA	PANCREAS	Panc-AdenoCA	ENDODERM	Pancreas	Adenocarcinoma	Adenocarcinoma	'8140/3	Adenocarcinoma, NOS
PAEN-IT	PANCREAS	Panc-Endocrine	ENDODERM	Pancreas	Neuroendocrine tumor	Neoroendocrine carcinoma	'8246/3	Neuroendocrine carcinoma
