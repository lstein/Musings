#!/usr/bin/perl

# this ad-hoc script fills in specimens that are missing their histology
# using information from other specimens from same donor.

# we expect the merged subtypes file on STDIN
chomp(my $topline = <>);
$topline =~ s/^#\s+//;
my @field_names = split "\t",$topline;

my %DATA;

while (<>) {
    chomp;
    next if /^#/;
    my %fields;
    @fields{@field_names} = split "\t";
    $donor                = $fields{icgc_donor_id};
    $specimen             = $fields{icgc_specimen_id};
    $DATA{$donor}{$specimen} = \%fields;
}

# now find all specimens that are missing histology
my $MISSING_1,$MISSING_2;
for my $donor (keys %DATA) {
    my ($type,$code);


    for my $specimen (keys %{$DATA{$donor}}) {
	$MISSING_1++ unless $DATA{$donor}{$specimen}{tumour_histological_type};
	$type ||= $DATA{$donor}{$specimen}{tumour_histological_type};
	$code ||= $DATA{$donor}{$specimen}{tumour_histological_code};
    }

    for my $specimen (keys %{$DATA{$donor}}){ 
	$DATA{$donor}{$specimen}{tumour_histological_type} ||= $type;
	$DATA{$donor}{$specimen}{tumour_histological_code} ||= $code
    }
}

for my $donor (keys %DATA) {
    for my $specimen (keys %{$DATA{$donor}}) {
	$MISSING_2++ unless $DATA{$donor}{$specimen}{tumour_histological_type};
    }
}

warn "$MISSING_2/$MISSING_1 specimens missing histo code.";

print '# ',join("\t",@field_names),"\n";
for my $donor (sort keys %DATA) {
    for my $specimen (sort keys %{$DATA{$donor}}) {
	print join("\t",@{$DATA{$donor}{$specimen}}{@field_names}),"\n";
    }
}

exit 0;

