package MAF::Shuffle;
use strict;

# CONSIDER CHANGING SHUFFLING STRATEGY:
# On a gene-by-gene basis, select mutated samples until we equal or exceed the
# number of ns- mutations we saw in the original...

# If a hashref, $gene_mutation_counts is a hashref of desired counts for each gene.
# If a scalar, $gene_mutation_counts is the total number of mutations desired. 
sub new {
    my $class = shift;
    my ($maf,$gene_mutation_counts) = @_;
    my $self  = bless {},ref $class || $class;
    $self->initialize($maf,$gene_mutation_counts);
    return $self;
}

sub initialize {
    my $self = shift;
    my ($maf,$mutation_counts) = @_;

    my $genes   = $maf->mutated_genes;
    my $samples = $maf->mutated_samples;
    my $gene_count   = @$genes;
    my $sample_count = @$samples;

    my (%mutated_gene_2_sample,%mutated_samples);
    if (ref $mutation_counts && ref $mutation_counts eq 'HASH') {

	my %mutation_counts = %$mutation_counts;
	while (%mutation_counts) {
	    my $gene   = $genes->[rand $gene_count];
	    my $sample = $samples->[rand $sample_count];

	    # This forces the counts to match desired.
	    # It is inefficient, but we keep going until all requested genes
	    # hit the desired number of mutations.
	    if (exists $mutation_counts->{$gene} && 
	        $mutation_counts->{$gene} <= keys %{$mutated_gene_2_sample{$gene}} ) {
		delete $mutation_counts{$gene};
		next;
	    }

	    $mutated_gene_2_sample{$gene}{$sample}++;
	    $mutated_samples{$sample}++;
	    
	}
    } 
    else {

	for (1..$mutation_counts) {
	    my $gene   = $genes->[rand $gene_count];
	    my $sample = $samples->[rand $sample_count];
	    $mutated_gene_2_sample{$gene}{$sample}++;
	    $mutated_samples{$sample}++;
	}

    }

    $self->{mutated_gene_2_sample} = \%mutated_gene_2_sample;
    $self->{mutated_samples}       = \%mutated_samples;
    $self->{maf}                   = $maf;
    return;
}

sub mutated_gene_2_sample { shift->{mutated_gene_2_sample} }
sub mutated_samples       { shift->{mutated_samples}       }
sub sample_count {
    my $self = shift;
    return $self->{sample_count} if exists $self->{sample_count};
    return $self->{sample_count} = @{$self->maf->all_samples};
}
sub maf                   { shift->{maf} }

sub gene_mf_ratio {
    my $self = shift;
    my $gene = shift;
    my $samples  = $self->mutated_gene_2_sample->{$gene} or return;
    my $maf      = $self->maf;

    my @affected_samples        = keys %$samples;
    my $mutations_in_affected   = $maf->mutations(\@affected_samples);
    my $mutations_in_unaffected = $maf->total_mutations - $mutations_in_affected;

    my $mean_affected      = $mutations_in_affected/@affected_samples;
    my $mean_unaffected    = $mutations_in_unaffected/($maf->total_samples - @affected_samples);

    return unless $mean_affected && $mean_unaffected; # to avoid divide-by-zero
    return $mean_affected/$mean_unaffected;
}

sub gene_frequency {
    my $self = shift;
    my $gene = shift;
    my $samples  = $self->mutated_gene_2_sample->{$gene} or return;
    my @affected_samples   = keys %$samples;
    return @affected_samples/$self->sample_count;
}

1;
