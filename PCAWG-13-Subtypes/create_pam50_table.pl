#!/usr/bin/perl

use strict;
use constant HISTO => 'pcawg_specimen_histology_May2016_v2.tsv';
use constant PAM50 => 'ICGC.BRCA.TCGA.PAM50.txt';

# slurp in the PAM50s:
my %pam50; # indexed by submitted_specimen_id
open my $f,'<',PAM50 or die $!;
while (<$f>) {
    chomp;
    my ($id,$pam) = split /\s+/;
    $pam50{$id}   = $pam;
}
close $f;

my @output_fields = qw(icgc_specimen_id
                           project_code 
                           submitted_specimen_id
                           submitted_sample_id
                           tcga_specimen_uuid
                           icgc_sample_id
                           tcga_sample_uuid
                           donor_unique_id
                           icgc_donor_id
                           submitted_donor_id
                           tcga_donor_uuid);

open $f,'<',HISTO or die $!;
chomp (my $header = <$f>);
$header           =~ s/^#\s*//;
my @field_names   = split "\t",$header;

print '# ',join ("\t",@output_fields,'pam50'),"\n";

while (<$f>) {
    my %fields;
    chomp;
    @fields{@field_names} = split "\t";
    my $id                = $fields{submitted_specimen_id};
    my $pam50             = $pam50{$id} or next;
    print join ("\t",@fields{@output_fields},$pam50),"\n";
}
close $f;
exit 0;

