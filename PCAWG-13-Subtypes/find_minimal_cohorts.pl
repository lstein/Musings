#!/usr/bin/perl
# 
# Identify and print out donor cohorts of >=15 members
# Input is the pcawg_specimen_histology file

use strict;

chomp (my $fields = <>);
$fields =~ s/^#\s+//;
my @fields = split "\t",$fields;

my %subtypes;
while (<>) {
    chomp;
    my %fields;
    @fields{@fields} = split "\t";
    my $donor  = $fields{icgc_donor_id};
    my $histo  = $fields{histology_tier3};
    my $abbrev = $fields{histology_abbreviation};
    next unless $histo;
    $subtypes{$abbrev}{$histo}{$donor}++;
}

my (%histos,%abbrevs);
for my $abbrev (keys %subtypes) {
    for my $histo (keys %{$subtypes{$abbrev}}) {
	my @donors = keys %{$subtypes{$abbrev}{$histo}};
	$histos{$histo}   = @donors;   # scalar operation - donor count
	$abbrevs{$abbrev} = @donors;   # scalar operation - donor count
    }
}

print join ("\t",'#abbrev','histology_abbreviation','donor_count'),"\n";

for my $abbrev (sort {$abbrevs{$b}<=>$abbrevs{$a}} keys %abbrevs) {
    for my $histo (sort {$subtypes{$abbrev}{$b}<=>$subtypes{$abbrev}{$a}} keys %{$subtypes{$abbrev}}) {
	print join("\t",$abbrev,$histo,$histos{$histo}),"\n";
    }
}


 
exit 0;
