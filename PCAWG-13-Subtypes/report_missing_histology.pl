#!/usr/bin/perl

use strict;
chomp (my $field_names = <>);
$field_names =~ s/^\#\s*//;
my @field_names = split "\t",$field_names;

while (<>) {
    my %fields;
    chomp;
    @fields{@field_names} = split "\t";
    next if $fields{'histology_tier3'};
    next if $fields{'donor_wgs_included_excluded'} eq 'Excluded';
    print join("\t",@fields{qw(project_code icgc_donor_id icgc_specimen_id)}),"\n";
}
