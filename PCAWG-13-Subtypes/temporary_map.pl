#!/usr/bin/perl
# 12 March 2016
# produce temporary mapping file for Paz and Esther

use strict;
open my $mapping,"<consolidation_map.tsv" or die $!;
my @fields = qw(organ_system icd-0-3 description organ histo code germ_layer);
my (%fields,%map,%organs);
while (<$mapping>) {
    chomp;
    next if /^#/;
    my @values       = split "\t";
    @fields{@fields} = @values;
    my ($icd)        = $fields{'icd-0-3'} =~ /^(\d+\/\d)/;
    my $organ_system = substr($fields{'organ_system'},0,20);
    my $key          = join ';',$organ_system,$icd;
    @{$map{$key}}{'histo','organ','code','germ_layer'} = @fields{'histo','organ','code','germ_layer'};
    $organs{$fields{'organ_system'}} ||= $fields{organ};
}
close $mapping;

open my $f,"<February2016_Dataset/histological_subtypes_and_clinical_data_harmonized_February2016_v3.tsv" or die $!;
chomp (my $fields = <$f>);
$fields   =~ s/# //;
@fields   = split /\s+/,$fields;

# insert new field value into proper location
my @new_fields;
for (my $i=0;$i<@fields;$i++) {
    my $f = $fields[$i];
    if ($f eq 'tumour_histological_type') {
	push @new_fields,$f,'tumour_type_abbrev','tumour_germ_layer';
    } else {
	push @new_fields,$f;
    }
}

print "# ",join("\t",@new_fields),"\n";
while (<$f>) {
    chomp;
    @fields{@fields}      = split "\t";
    my $organ_system      = substr($fields{'organ_system'},0,20);
    my $key                = join ';',$organ_system,$fields{'tumour_histological_code'};

    $fields{organ_system}             = $map{$key}{organ} || $organs{$fields{'organ_system'}} || $fields{'organ_system'};
    $fields{tumour_histological_type} = $map{$key}{histo};
    $fields{tumour_germ_layer}        = $map{$key}{germ_layer};
    $fields{tumour_type_abbrev}       = $map{$key}{code};
    $fields{tumour_histological_type} =~ s/"//g;
    print join("\t",@fields{@new_fields}),"\n";
}
