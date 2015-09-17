package MAF;
use strict;

use DB_File;
use File::Basename;
use MAF::Shuffle;

# information we need to retrieve:
# 1. All tumour specimen IDs
# 2. All affected gene names
# 3. Tumour => mutation count
# 4. Gene   => non-silent mutation count
# 5. Total number of non-silent mutations
#
# functions to perform:
# 1. compute the "true" list of genes and ratios:
#           gene   mutation_ratio    sample_proportion
#
# 2. compute a random shuffle
# options:
#    project   => $regexp -- regular expression to select project names, for example ^BRCA
#    blacklist => $path   -- path to a blacklist file - first column is sample names to exclude from parse  
#
sub new {
    my $class = shift;
    my ($maf,%options)   = @_;
    my $self = bless \%options,ref $class || $class;
    $self->parse_maf($maf) if $maf;
    return $self;
}

sub project    { shift->{project}   }
sub blacklist  { shift->{blacklist} }

sub sample_mutation_count {shift->{sample_mutation_count}};
sub mutated_gene_2_sample {shift->{mutated_gene_2_sample}};
sub mutated_genes         {shift->{mutated_genes}};
sub mutated_samples       {shift->{mutated_samples}};

# given a gene, return the ratio of mutations in affected vs nonaffected samples
sub gene_mf_ratio {
    my $self = shift;
    my $gene = shift;
    my $samples  = $self->mutated_gene_2_sample->{$gene} or return;

    my @affected_samples        = keys %$samples;
    my $mutations_in_affected   = $self->mutations(\@affected_samples);
    my $mutations_in_unaffected = $self->total_mutations - $mutations_in_affected;

    my $mean_affected      = $mutations_in_affected/@affected_samples;
    my $mean_unaffected    = $mutations_in_unaffected/($self->total_samples - @affected_samples);

    return unless $mean_affected && $mean_unaffected; # to avoid divide-by-zero
    return $mean_affected/$mean_unaffected;
}

sub gene_frequency {
    my $self = shift;
    my $gene = shift;
    my $samples  = $self->mutated_gene_2_sample->{$gene} or return;
    my @affected_samples   = keys %$samples;
    return @affected_samples/@{$self->all_samples};
}

sub gene_mutation_count {
    my $self = shift;
    my $gene = shift;
    my $samples  = $self->mutated_gene_2_sample->{$gene} or return;
    return scalar keys %$samples;
}

sub all_genes {
    my $self = shift;
    my @g    = keys %{$self->mutated_gene_2_sample};
    return \@g;
}

sub all_samples {
    my $self = shift;
    return $self->{all_samples} if exists $self->{all_samples};

    my @s    = keys %{$self->sample_mutation_count};
    return $self->{all_samples} = \@s;
}

sub total_samples {
    my $self = shift;
    return $self->{sample_count} ||= keys %{$self->sample_mutation_count};
}

sub total_mutations {
    my $self = shift;
    return $self->{mutation_count} if exists $self->{mutation_count};
    my $t = 0;
    my $samples = $self->sample_mutation_count;
    for my $s (keys %$samples) {
	$t += $samples->{$s};
    }
    return $self->{mutation_count} ||= $t;
}

sub total_nonsilent_mutations {
    my $self = shift;
    return $self->{nonsilent_mutation_count} if exists $self->{nonsilent_mutation_count};

    my $total;
    my $mg2s = $self->mutated_gene_2_sample;
    for my $g (keys %{$mg2s}) {
	for my $s (keys %{$mg2s->{$g}}) {
	    $total++;
	}
    }
    return $self->{nonsilent_mutation_count} = $total;
}


sub is_silent {
    my $self = shift;
    my $mutation_type = shift;
    return $mutation_type !~ /De_novo_Start|Missense|Nonsense|Nonstop|Splice|Start_Codon/;
}

sub mutations {
    my $self = shift;
    my $samples = shift;

    my $counts = $self->sample_mutation_count;
    my $total   = 0;
    for my $s (@$samples) {
	$total += $counts->{$s};
    }
    return $total;
}

sub shuffle {
    my $self = shift;
    my $desired_mutations = shift;
    return MAF::Shuffle->new($self,$desired_mutations);
}

sub parse_maf {
    my $self = shift;
    my $maf  = shift;

    my $project   = $self->project;
    my $blacklist = $self->blacklist;

    $self->setup_caches($maf,$project) or return;

    my $SampleMutationCount = $self->sample_mutation_count();     # hashref {sample}       => total_mutation_count
    my $MutatedGene2Sample  = $self->mutated_gene_2_sample();     # hashref {gene}{sample} => true if gene mutated in sample
    my $MutatedGenes        = $self->mutated_genes();             # arrayref [gene1,gene1,gene1,gene2,gene2,gene3...] 
    my $MutatedSamples      = $self->mutated_samples();           # arrayref [sample1,sample1,sample1,sample2,sample2....]

    my $anonymous_gene = 'ANON0000';

    my $blacklist      = $self->generate_blacklist($blacklist) if $blacklist;

    my $f;
    if ($maf =~ /\.gz$/) {
	open $f,"gunzip -c $maf |" or die "gzip -c $maf: $!";
    } else {
	open $f,'<',$maf         or die "$maf: $!";
    }

    while (<$f>) {

	chomp;
	next if /^Hugo_Symbol/;

	my @fields = split "\t";

	my ($gene,$variant_type,$sample,$project) = @fields[0,6,13,-2];
	$gene ||= $anonymous_gene++;  # in case there is no Hugo symbol

	next if $project && $fields[-2] !~ /$project/;
	next if $blacklist->{$sample};

	# count all mutations (cached)
	$SampleMutationCount->{$sample}++;   
	next if $self->is_silent($variant_type);

	# if we get here, then we have a non-silent SNV (a "mutation")

        # Record an occurrence of a mutated gene in a sample.
	$MutatedGene2Sample->{$gene}{$sample}++;  

	# deal with the gene
	push @$MutatedGenes,$gene;        # long list of gene mutation occurrences

	# deal with the sample
	push @$MutatedSamples,$sample;    # long list of mutations in samples
    }

    $self->update_touchfile($maf,$project);
    return;
}

sub setup_caches {
    my $self = shift;
    my $maf  = shift;

    my $cache_directory = $self->cache_directory($maf);
    
    my (%SampleMutationCount,$MutatedGene2Sample,@MutatedGenes,@MutatedSamples);
    tie %SampleMutationCount,'DB_File',"$cache_directory/MutationCount.db",O_RDWR|O_CREAT,0666,$DB_HASH
	or die "MutationCount.db: $!";
    tie @MutatedGenes,'DB_File',"$cache_directory/MutatedGenes.list",O_RDWR|O_CREAT,0666,$DB_RECNO
	or die "MutatedGenes.list: $!";
    tie @MutatedSamples,'DB_File',"$cache_directory/MutatedSamples.list",O_RDWR|O_CREAT,0666,$DB_RECNO
	or die "MutatedSamples.list: $!";

    # ad hoc caching of %MutatedGene2Sample...
    $MutatedGene2Sample = $self->read_gene2sample_cache($maf);

    $self->{sample_mutation_count} = \%SampleMutationCount;
    $self->{mutated_gene_2_sample} = $MutatedGene2Sample;
    $self->{mutated_genes}         = \@MutatedGenes;
    $self->{mutated_samples}       = \@MutatedSamples;

    $self->check_touchfile($cache_directory,$maf) and return;

    %SampleMutationCount  = ();
    %$MutatedGene2Sample  = ();
    @MutatedGenes         = ();
    @MutatedSamples       = ();

    1;
}

# blacklist of samples
sub generate_blacklist {
    my $self = shift;
    my $path = shift;
    my %blacklist;
    open my $f,'<',$path or die "$path: $!";
    while (<$f>) {
	chomp;
	next if /^#/;
	my ($sample) = /^(\S+)/;
	$blacklist{$sample}++;
    }
    close $f;
    return \%blacklist;
}

sub cache_directory {
    my $self = shift;
    my $maf_file   = shift;
    my $project    = $self->project;
    my $blacklist  = $self->blacklist;
    $blacklist     =~ s![^a-zA-Z0-9_-]!_!g;  # get rid of naughty characters

    my $basename        = basename($maf_file,'.gz');
    $basename          .= '-'.$project   if defined $project;
    $basename          .= '-'.$blacklist if defined $blacklist;
    my $dirname         = dirname($maf_file);
    my $cache_directory = "$dirname/$basename.cache";
    -d $cache_directory or mkdir $cache_directory or die "Couldn't make cache directory $cache_directory: $!";
    return $cache_directory;
}

sub check_touchfile {
    my $self      = shift;
    my ($cache_directory,$maf_file) = @_;
    my $touchfile = $self->touchfile($cache_directory);
    return 1 if -e $touchfile && -M $touchfile < -M $maf_file;  # cache up to date
}

sub update_touchfile {
    my $self = shift;
    my $maf = shift;

    $self->write_gene2sample_cache($maf);

    my $touchfile = $self->touchfile($self->cache_directory($maf));
    open my $f,'>',$touchfile or die "Can't touch $touchfile: $!";
    close $f;
}

sub touchfile {
    my $self = shift;
    my $dir  = shift;
    return "$dir/timestamp";
}

sub write_gene2sample_cache {
    my $self = shift;
    my $maf  = shift;

    my $gene2sample = $self->mutated_gene_2_sample;
    my $filename    = $self->gene2sample_cachefile($maf);
    open my $f,'>',$filename or die "$filename: $!";
    for my $gene (keys %$gene2sample) {
	for my $sample (keys %{$gene2sample->{$gene}}) {
	    print $f $gene,"\t",$sample,"\n";
	}
    }
    close $f;
}

sub read_gene2sample_cache {
    my $self = shift;
    my $maf  = shift;
    my $filename = $self->gene2sample_cachefile($maf);
    
    my %hash;
    return \%hash unless -e $filename;

    open my $f,'<',$filename or die "$filename: $!";
    while (<$f>) {
	chomp;
	my ($gene,$sample) = split "\t";
	$hash{$gene}{$sample}++;
    }
    return \%hash;
}

sub gene2sample_cachefile {
    my $self = shift;
    my $maf   = shift;
    my $cachedir = $self->cache_directory($maf);
    my $cachefile= "$cachedir/MutatedGene2Sample.list";
}

1;
