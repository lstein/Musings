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
    my $donor = $fields{icgc_donor_id};
    my $histo = $fields{histology_abbreviation};
    next unless $histo;
    $subtypes{$histo}{$donor}++;
}

my %sorted;
for my $histo (keys %subtypes) {
    my @donors = keys %{$subtypes{$histo}};
    $sorted{$histo} = @donors;   # scalar operation - donor count
}

print join ("\t",'#histology_abbreviation','donor_count'),"\n";
for my $histo (sort {$sorted{$b}<=>$sorted{$a}} keys %sorted) {
    print join("\t",$histo,$sorted{$histo}),"\n";
}

 
exit 0;
