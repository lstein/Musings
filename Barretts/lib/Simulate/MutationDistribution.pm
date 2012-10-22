package Simulate::MutationDistribution;

use strict;
use warnings;
use Carp 'croak';

use constant euler => 2.71828;

sub new {
    my $class = shift;
    return bless {
	mutations       => [],
	frequencies     => {},
	spectrum        => [],
    },ref $class || $class;
}

sub mutations   {shift->{mutations}   }
sub frequencies {shift->{frequencies} }
sub spectrum    {shift->{spectrum}    }

# from http://www.alexeypetrov.narod.ru/Eng/progs.html#r_gener
sub generate_power_distribution {
    my $self = shift;
    my ($N,$alpha,$x_min,$x_max) = @_;
    
    $N             ||= 300000;
    $alpha         ||= -2;
    $x_min         ||= 0.05;
    $x_max         ||= 0.8;

    my $p0 = $x_min ** ($alpha+1);
    my $p1 = $x_max ** ($alpha+1);
    my $s  = $self->spectrum;
    for (my $i=0; $i<$N; $i++) {
	my $r = rand() or next;
	my $E = ($r*($p1-$p0)+$p0)**(1/($alpha+1));
	push @$s,$E;
    }
}

sub generate_mutations {
    my $self  = shift;
    my ($count,$dist_size) = @_;
    $count     ||= 100;
    $dist_size ||= 100_000;
    my $spectrum  = $self->spectrum;
    my $mutations = $self->mutations;
    my $freq      = $self->frequencies;
    for (1..$count) {
	my $label = sprintf("M%03d",$_);
	my $freq  = $spectrum->[rand @$spectrum];
	warn $freq,"\n";
	my $c     = int($count * $freq);
	my @dist  = ($label) x $c;
	push @$mutations,@dist;
    }

    for my $m (@$mutations) {
	$freq->{$m}++;
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
	printf ("%5s %5.4f\n",$mut,$f->{$mut}/$total);
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
