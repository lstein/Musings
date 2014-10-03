#!/usr/bin/perl

# This reads the file produced by generate_1000_genomes.pl and
# tallies up the mutation rate in genomes with and without mutations
# in each gene
use strict;
use Statistics::Descriptive;

my %Genes; # { gene_name => {genome_id1=>$cnt,genome_id2=>$cnt...}
           #   gene_name... => {
           # }
my %Genomes; # { genome_id => $mutation_cnt }

while (<>) {
    chomp;
    my ($genome_id,$total_mutations,$genes) = /^(\d+): cnt=(-?\d+), (.*)/;
    $total_mutations = 0 if $total_mutations < 0;
    my @genes = split /\s+/,$genes;
    $Genes{$_}{$genome_id}++ foreach @genes;
    $Genomes{$genome_id} = $total_mutations;
}

my $total_genomes = scalar keys %Genomes;

# now separately calculate positive and negative genomes
my $stat_pos = Statistics::Descriptive::Full->new();
my $stat_neg = Statistics::Descriptive::Full->new();
print join ("\t",
	    'Gene',
	    'MutFreq',
	    'PosMean',
	    'PosSD',
	    'PosCount',
	    'NegMean',
	    'NegSD',
	    'NegCount',
	    'PosNegRatio'),"\n";
	    
for my $gene (keys %Genes) {
    my %positive_genomes = map {$_=>1} keys %{$Genes{$gene}};
    my @negative_genomes = grep {!$positive_genomes{$_}} keys %Genomes;

    my @positive_counts  = map {$Genomes{$_}} keys %positive_genomes;
    my @negative_counts  = map {$Genomes{$_}} @negative_genomes;

    my $gene_frequency   = @positive_counts/$total_genomes;

    $stat_pos->clear;
    $stat_pos->add_data(@positive_counts);

    $stat_neg->clear;
    $stat_neg->add_data(@negative_counts);

    print join ("\t",
		$gene,
		$gene_frequency,
		$stat_pos->mean,$stat_pos->standard_deviation,$stat_pos->count,
		$stat_neg->mean,$stat_neg->standard_deviation,$stat_neg->count,
		$stat_pos->mean/$stat_neg->mean),"\n";
    
}
                             
