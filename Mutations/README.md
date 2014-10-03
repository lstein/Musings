Very basic simulation of random mutations in a genome. For use
in understanding ascertainment bias when searching for mutations
that increase mutation rate.

Typical pipeline:

bin/generate_random_genomes.pl   1000 1.01              > 1000_random_genomes.txt
bin/gene_specific_differences.pl 100_random_genomes.txt > gene_differences.txt
bin/make_ready_for_boxplot.pl    gene_differences.txt   > boxplot.txt

Now go to R and run:

BoxPlot = read.table('boxplot.txt',header=TRUE,sep="\t")
BPList=apply(BoxPlot,1,function(x)as.numeric(strsplit(x[2],',')[[1]]))
names(BPList)=BoxPlot[,1]
boxplot(BPList)
png('gene_frequency_ascertainment_bias.png',width=1024,height=800)
boxplot(BPList)
dev.off()

