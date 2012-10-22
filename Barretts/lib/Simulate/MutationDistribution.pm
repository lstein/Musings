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
    },ref $class || $class;
}

sub mutations   {shift->{mutations}   }
sub frequencies {shift->{frequencies} }

# from http://www.alexeypetrov.narod.ru/Eng/progs.html#r_gener
sub generate_mutations {
    my $self = shift;
    my ($N,$alpha,$x_min,$x_max) = @_;
    
    $N             ||= 100;
    $alpha         ||= -2;
    $x_min         ||= 0.05;
    $x_max         ||= 1.0;

    my $p0 = $x_min ** ($alpha+1);
    my $p1 = $x_max ** ($alpha+1);
    for (my $i=0; $i<$N; $i++) {
	my $r = rand() or next;
	my $E = ($r*($p1-$p0)+$p0)**(1/($alpha+1)); # frequency of this one
	my $label = sprintf("M%03d",$i+1);
	$self->frequencies->{$label}=$E;
    }
}

sub print_distribution {
    my $self = shift;
    my $f     = $self->frequencies;
    for my $mut (sort {$f->{$b}<=>$f->{$a}} keys %$f) {
	printf ("%5s %5.4f\n",$mut,$f->{$mut});
    }
}

sub generate_clone {
    my $self = shift;
    my $count = shift || 1;
    my $f     = $self->frequencies;
    my @keys  = keys %$f;
    my @result;
    for my $c (@keys) {
	push @result,$c if rand() <= $f->{$c};
    }
    return @result;
}

sub mutation_frequency {
    my $self = shift;
    my $mutation = shift or croak 'Usage: \$distribution->mutation_frequency(\$mutation_label)';
    return $self->frequencies->{$mutation};
}


1;
