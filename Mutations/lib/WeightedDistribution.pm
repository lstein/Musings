package WeightedDistribution;

=head1 NAME

WeightedDistribution -- Generate a distribution of events according to a frequency distribution

=head1 SYNOPSIS

 my $dist = WeightedDistribution->new([0.9, 0.8, 0.7, 0.5, 0.2, 0.2, 0.2, 0.1, 0.1, 0.1, 0.1, 0.05, 0.05, 0.05, 0.05]);
 my %items;
 for (1..1000) {
    my @items = $dist->draw(10);
    $items{$_}++ foreach @items;
 }

# frequency that comes out should match what went in
 print "Item\tFrequency\n";
 for my $i (sort {$items{$b}<=>$items{$a}} keys %items) {
    print $i,"\t",$i/1000,"\n";
 }

=cut

sub new {
    my $self = shift;
    my $frequencies = shift;
    return bless {f => $frequencies},ref $self||$self;
}

sub ftable {shift->{f}};

sub total {
    my $self = shift;
    return $self->{_total} if exists $self->{_total};
    my $f    = $self->ftable;
    my $t    = 0;
    foreach (@$f) {
	$t += $_;
    }
    return $self->{_total} = $t;
}

sub draw {
    my $self  = shift;
    my $count = shift;

    my $total = $self->total;
    my $f     = $self->ftable;

    my @list;
    for (my $i=0; $i<@$f; $i++) {
	my $probability = $f->[$i]/$total;
#	warn "$i: $probability\n";
	if (rand($i) < $probability) {
	    if (@list >= $count) {
		$list[rand @list] = $i;
	    } else {
		push @list,$i;
	    }
	}
	$total -= $f->[$i];
    }

    return @list;
}



1;
