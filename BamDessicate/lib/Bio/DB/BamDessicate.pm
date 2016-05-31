package Bio::DB::BamDessicate;

use strict;

use IO::Compress::Bzip2     qw(bzip2);
use IO::Uncompress::Bunzip2 qw(bunzip2);
use List::BinarySearch      qw(binsearch_pos binsearch);
use Cwd                     qw(abs_path);
use Tie::Cache;

use constant HEADER       => 512;
use constant MAGIC        => 'DAM1';
use constant BLOCKSIZE    => 1_048_576;   # A megabyte

sub new {
}

sub dessicate {
    my $self   = shift;
    my ($infile,$outfile) = @_;
    $infile && $outfile   or die "usage: \$bd->dessicate(\$sam_or_bamfile_in,\$damfile_out)";
    my $outfh = $self->create_damfile($outfile);
    $self->write_dam_header($infh,$outfh);

    # treat bam and sam files differently
    my $is_bam = $in =~ /\.bam$/;

    # Write SAM header
    my $infh;
    if ($is_bam) {
	$infh = $self->open_bamfile($infile);
	print $outfh $_ while <$infh>;
    } else {
	$infh = $self->open_samfile($infile);
	while (<$infh>) {
	    last unless /^\@/;
	    print $outfh $_;
	}
    }
    close $infh;

    

}

sub hydrate {
    my $self = shift;
    my ($readfile,$damfile) = @_;
    $readfile && $outfile or die "usage: \$bd->hydrate(\$sam_bam_or_fastqfile_in,\$damfile_in,\$bamfile_out)";
}



1;
