#!/usr/bin/perl

use strict;

# read output of gene_specific_differences.pl and prepare a file
# in correct format for R boxplot drawing

# frequency founded to nearest 0.01
my %Bins;

while (<>) {
    next if /^Gene/;
    chomp;
    my @h = split /\s+/;
    my $freq  = $h[1];
    my $ratio = $h[-1];
    my $bin = int($freq * 100 + 0.5)/100;
    push @{$Bins{$bin}},$ratio;
}

print "Frequency\tPosNegRatios\n";
for my $bin (sort {$a<=>$b} keys %Bins) {
    print $bin,"\t",join(',',sort {$a<=>$b} @{$Bins{$bin}}),"\n";
}

__END__

R code to read this:

Save as "boxplot.out"

BoxPlot = read.table('boxplot.out',header=TRUE,sep="\t")
BPList=apply(BoxPlot,1,function(x)as.numeric(strsplit(x[2],',')[[1]]))
names(BPList)=BoxPlot[,1]
boxplot(BPList)
png('gene_frequency_ascertainment_bias.png',width=1024,height=800)
boxplot(BPList)
dev.off()
