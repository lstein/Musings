package SimpleGenome;

use strict;

# options:
#   -genes         =>  # of genes in the genome (20,000)
#   -ns_rate       =>  rate at which a mutation falls into a non-synonymous coding position (0.03)
#   -mutation_mean =>  mean number of mutations (total) to generate - will be normally distributed around this (5,000)
#   -mutation_sdev =>  standard deviation of mutations to generate (500)
#   -drivers       =>  number of driver genes (6)
#   -driver_weight =>  relative probability of a mutation in a driver gene (5000) # roughly 10%
#   -nondriver_weight => relative probability of a mutation in a non-driver gene (50)
#                      all non-driver genes will have weights between 50 and 1, distributed
#                      evenly
sub new {
    my $self = shift;
    my %options = @_;
    $options{-genes}            ||= 20_000;
    $options{-ns_rate}          ||= 0.03;
    $options{-mutation_mean}    ||= 5_000;
    $options{-mutation_sdev}    ||= 2_000;
    $options{-drivers}          ||= 6;
    $options{-driver_weight}    ||= 15000;
    $options{-nondriver_weight} ||= 200;
    return bless {
	options => \%options
    },ref $self || $self;
}

sub option {
    my $self = shift;
    my $option = shift;
    $option = "-$option" unless $option =~ /^-/;
    return $self->{options}{$option};
}

sub mutation_count {
    my $self = shift;
    return $self->{mutation_count} ||= int $self->rand_normal($self->option('mutation_mean'),$self->option('mutation_sdev'));
}

sub ns_mutation_count {
    my $self = shift;
    return $self->{ns_mutation_count} ||= $self->option('ns_rate') * $self->mutation_count;
}

sub mutated_genes {
    my $self = shift;

    my @mutated_genes;

    my $gene_count = $self->ns_mutation_count;
    my $distribution = $self->gene_distribution;
    for (1..$gene_count) {
	my $gene = $self->_weighted_rand($distribution);
	push @mutated_genes,$gene;
    }
    return @mutated_genes;
}

sub gene_weights {
    my $self = shift;
    return $self->{gene_weights} ||= $self->_gene_weights;
}

sub gene_distribution {
    my $self = shift;
    return $self->{gene_distribution} ||= $self->_weight_to_dist($self->gene_weights);
}

sub _gene_weights {
    my $self = shift;
    my %weights;
    my $drivers     = $self->option('drivers');

    for (1..$drivers) {
	$weights{$_} = $self->option('driver_weight');
    }

    my $non_drivers = $self->option('genes') - $drivers;
    my $step        = $self->option('nondriver_weight')/$non_drivers;
    my $weight      = $self->option('nondriver_weight');

    for (1..$non_drivers) {
	my $w = $weight - ($_-1) * $step;
	$w    = 0 if $w < 0;
	my $g = $drivers + $_;
	$weights{$g} = $w;
    }
    
    return \%weights;
}

sub rand_normal {
    my $self = shift;
    my ($mean,$sdev) = @_;
    return $self->_gaussian_rand * $sdev + $mean;
}

#from: http://doc.sumy.ua/prog/pb/cookbook/ch02_11.htm
sub _gaussian_rand {
    my $self = shift;
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
        $u2 = 2 * rand() - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;
    # return both if wanted, else just one
    return wantarray ? ($g1, $g2) : $g1;
}

# weight_to_dist: takes a hash mapping key to weight and returns
# a hash mapping key to probability
sub _weight_to_dist {
    my $self = shift;
    my $weights = shift;

    my %dist    = ();
    my $total   = 0;
    my ($key, $weight);
    local $_;

    foreach (values %$weights) {
        $total += $_;
    }

    while ( ($key, $weight) = each %$weights ) {
        $dist{$key} = $weight/$total;
    }

    return \%dist;
}

# weighted_rand: takes a hash mapping key to probability, and
# returns the corresponding element
sub _weighted_rand {
    my $self = shift;
    my $dist = shift;

    my ($key, $weight);

    while (1) {                     # to avoid floating point inaccuracies
        my $rand = rand;
        while ( ($key, $weight) = each %$dist ) {
            return $key if ($rand -= $weight) < 0;
        }
    }
}


1;
