#!/usr/bin/perl

use strict;

@ARGV == 2 or die "Usage patch_sex.pl <clinical_data_file.tsv> <sex_patch_file.tsv>";
my ($clinical,$patches) = @ARGV;

my %new_sex;
open my $p,"<$patches" or die "$patches: $!";
while (<$p>) {
    chomp;
    my ($donor_unique_id,$dcc_donor_id,$original_sex,$new_sex) = split "\t";
    next unless $donor_unique_id =~ /::/;
    $new_sex{$donor_unique_id} = $new_sex;
}
close $p;

open my $in, "<$clinical"     or die "$clinical: $!";
chomp(my $first_line = <$in>);
print $first_line,"\n";

$first_line =~ s/^#\s+//;
my @fields = split "\t",$first_line;

while (<$in>) {
    my %fields;
    chomp;
    @fields{@fields} = split "\t";
    my $id  = $fields{donor_unique_id};
    my $sex = $new_sex{$id};
    if ($sex) {
	$fields{donor_sex} = $sex;
    }
    print join("\t",@fields{@fields}),"\n";
}
