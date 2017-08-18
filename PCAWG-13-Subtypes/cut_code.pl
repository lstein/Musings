my $to_open = "gunzip -c $PCAWG_SPECIMENS|";

open my $f,$to_open or die $PCAWG_SPECIMENS,": $!";
chomp(my $header = <$f>);
my @fields = split "\t",$header;

while (<$f>) {
    chomp;
    my @t            = split "\t";

    for (0..@fields-1) {
	$t[$_] = 'N/A' unless length($t[$_]);
	$t[$_] = 'N/A' if $t[$_] eq 'unknown';
    }

    @fields{@fields} = @t;
    $fields{percentage_cellularity} =~ s/%//g;

    my ($project,$donor,$specimen) = @fields{'project_code','submitted_donor_id','submitted_specimen_id'};
    my $specimen_uuid = $tcga_uuids->{$specimen} || $specimen;
    my $donor_uuid    = $tcga_donors->{$donor}   || $donor;
    $dcc_donors{$project}{$donor_uuid}++;
    $total++;
    unless ($samples->{$project,$donor_uuid,$specimen_uuid}) {
	$not_found{$project}{$specimen_uuid}++;
	next;
    }
    
    $found{$project}++;
    my $tumour_histological_code = $fields{tumour_histological_type};
    my $type                     = $codes->{$tumour_histological_code} || $tumour_histological_code;
    $type =~ lcfirst($type);
    my $free_text = $tumour_histological_code !~ /^\d+/;
    print join ("\t",
		$project,$donor_uuid,$specimen_uuid,
		($free_text ? '' : $tumour_histological_code),
		$type,
		@fields{'tumour_grade','tumour_stage','percentage_cellularity','level_of_cellularity'}),"\n";
}

