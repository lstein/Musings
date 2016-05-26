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
}

sub hydrate {
    my $self = shift;
    my ($readfile,$damfile) = @_;
    $readfile && $outfile or die "usage: \$bd->hydrate(\$sam_bam_or_fastqfile_in,\$damfile_in,\$bamfile_out)";
}

1;
