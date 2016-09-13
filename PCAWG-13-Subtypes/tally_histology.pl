#!/usr/bin/perl

# This counts up the histology descriptions using the Tier 3 codes
# from the pcawg_specimen_histology.tsv files

use strict;
chomp (my $field_names = <>);
$field_names =~ s/^#\s+//;
my @field_names = split "\t",$field_names;

my %tally;
while (<>) {
    chomp;
    my %f;
    @f{@field_names} = split "\t";
    next if $f{'donor_wgs_included_excluded'} eq 'Excluded';
    my $organ_system = $f{organ_system};
    my $project_code = $f{project_code};
    my $tier1        = $f{histology_tier1};
    my $tier2        = $f{histology_tier2};
    my $tier3        = $f{histology_tier3};
    my $abbrev       = $f{histology_abbreviation};
    $tier2         ||= '(Missing histological type)';
    $tally{$tier2}{$abbrev}{total}++;
    $tally{$tier2}{$abbrev}{projects}{$project_code}++;
    $tally{$tier2}{$abbrev}{tier1} = $tier1;
    $tally{$tier2}{$abbrev}{tier3} = $tier3;
}

my $total = 0;
for my $organ (sort keys %tally) {
    my $o = $tally{$organ};
    for my $abbrev (sort keys %$o) {
	my $h = $o->{$abbrev};
	my @projects = sort keys %{$h->{projects}};
	print join("\t",$organ,$abbrev,$h->{tier1},$h->{tier3},join(',',@projects),$h->{total}),"\n";
	$total += $h->{total};
    }
}

print "TOTAL = $total\n";
