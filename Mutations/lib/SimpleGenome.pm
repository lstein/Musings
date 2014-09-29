package SimpleGenome;

use strict;

# options:
#   -genes         =>  # of genes in the genome (20,000)
#   -ns_rate       =>  rate at which a mutation falls into a non-synonymous coding position (0.03)
#   -mutation_mean =>  mean number of mutations (total) to generate - will be normally distributed around this (5,000)
#   -mutation_sdev =>  standard deviation of mutations to generate (500)
#   -drivers       =>  number of driver genes (6)
#   -driver_weight =>  relative probability of a mutation in a driver gene (100)
#   -nondriver_weight => relative probability of a mutation in a non-driver gene (50)
#                      all non-driver genes will have weights between 50 and 1, distributed
#                      evenly
sub new {
    my $self = shift;
    my %options = @_;
    $options{-genes}            ||= 20_000;
    $options{-ns_rate}          ||= 0.03;
    $options{-mutation_mean}    ||= 5_000;
    $options{-mutation_sdev}    ||= 500;
    $options{-drivers}          ||= 6;
    $options{-driver_weight}    ||= 100;
    $options{-nondriver_weight} ||= 50;
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
    return int $self->rand_normal($self->option('mutation_mean'),$self->option('mutation_sdev'));
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
    my %weights = @_;
    my %dist    = ();
    my $total   = 0;
    my ($key, $weight);
    local $_;

    foreach (values %weights) {
        $total += $_;
    }

    while ( ($key, $weight) = each %weights ) {
        $dist{$key} = $weight/$total;
    }

    return %dist;
}

# weighted_rand: takes a hash mapping key to probability, and
# returns the corresponding element
sub _weighted_rand {
    my $self = shift;

    my %dist = @_;
    my ($key, $weight);

    while (1) {                     # to avoid floating point inaccuracies
        my $rand = rand;
        while ( ($key, $weight) = each %dist ) {
            return $key if ($rand -= $weight) < 0;
        }
    }
}


1;
