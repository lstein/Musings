package Simulate::MutationDistribution;

use strict;
use warnings;
use Carp 'croak';

sub new {
    my $class = shift;
    return bless {
	mutations       => [],
	frequencies     => {},
    },ref $class || $class;
}

sub mutations   {shift->{mutations}   }
sub frequencies {shift->{frequencies} }

sub generate {
    my $self = shift;
    my ($mutation_count,$iterations,$expansion) = @_;
    $iterations ||= 100_000;
    $expansion  ||= 5;
    my $mutations = $self->mutations;

    # initial set
    @$mutations = (1..$mutation_count);

    # random duplications
    for (1..$iterations) {
	my $count = @$mutations;
	my $lucky = $mutations->[rand $count];
	for (1..$expansion) {
	    push @$mutations,$lucky;
	}
    }

    my $frequencies = $self->frequencies;
    foreach (@$mutations) {
	$frequencies->{$_}++;
    }
}

sub print_distribution {
    my $self = shift;
    my $f     = $self->frequencies;
    my $total = 0;

    foreach (values %$f) {
	$total += $_;
    }
    for my $mut (sort {$f->{$b}<=>$f->{$a}} keys %$f) {
	printf ("%5d %5.4f\n",$mut,$f->{$mut}/$total);
    }
}

sub pick_mutations {
    my $self = shift;
    my $count = shift || 1;
    my $m     = $self->mutations;
    my @result;
    for (1..$count) {
	push @result,$m->[rand @$m];
    }
    return @result;
}

sub mutation_frequency {
    my $self = shift;
    my $mutation = shift or croak 'Usage: \$distribution->mutation_frequency(\$mutation_label)';
    return $self->frequencies->{$mutation};
}


1;
