#!/usr/bin/perl

use strict;
chomp (my $f = <>);
$f =~ s/^#//;
my @fields = split "\t",$f;
my %f;

print "# THESE SPECIMENS HAVE NO HISTOPATHOLOGICAL DESCRIPTION\n";
print "# Project     Donor    Specimen\n";

open my $sort,"|sort";
while (<>) {
    chomp;
    @f{@fields} = split "\t";
    my ($project_code,$submitted_donor_id,$submitted_specimen_id,$tumour_type) = 
	@f{'project_code','submitted_donor_id','submitted_specimen_id','tumour_histological_type'};
    next if $tumour_type;
    next if /MISSING FROM DCC/;
    printf $sort "%-8s %-20s %-20s\n",$project_code,$submitted_donor_id,$submitted_specimen_id;
}
close $sort;
exit 0;
