#!/usr/bin/perl

use strict;
use IO::Compress::Bzip2;
use Cwd 'abs_path';

# We are going to do a test of the following:
# 1. Read in a BAM file, sorted by the read name (using system sort).
# 2. Strip out the sequence data (see dessicate.pl)
# 3. Accumulate into a buffer.
# 4. When the buffer exceeds a certain size, bzip compress it and store to disk.
# 5. Keep track of offset to the first read ID in each block for later binary search
#    and random access retrieval. Index can get placed at end of the file.

use constant TEST_BAM     => './test.bam';
use constant TEST_OUTPUT  => './test.dam';
use constant BLOCKSIZE    => 1_048_576;   # roughly a megabyte

# header format:
#   4 bytes   -- magic number 'DAM1'
#   4 bytes   -- offset to beginning of BAM header data
#   4 bytes   -- offset to beginning of gzip block data
#   4 bytes   -- offset to beginning of read name index
#   N+1 bytes -- full path to original BAM/SAM file, zero terminated string
#   512-(16+N+1) -- reserved for future expansion
use constant HEADER       => 512;
use constant MAGIC        => 'DAM1';

my $in  = shift || TEST_BAM;
my $out = shift || TEST_OUTPUT;

my ($infh,$outfh);

my $abspath  = abs_path($in);
my $limit    = HEADER - (4+4+4+4+1);
my $pathlen  = length($abspath);
die "Absolute path '$abspath' is too long (path length=$pathlen bytes; limit=$limit bytes)"
    unless $pathlen <= $limit;

open $outfh,'>',$out                         or die "$out: $!";
print $outfh pack('a4LLLZ*',MAGIC,HEADER,0,0,$abspath); # magic number, offsets to beginning of BAM header data, gzip data, index
seek($outfh,HEADER,0);                        # start writing at beginning of BAM header area

# first open and write header
my $is_bam = $in =~ /\.bam$/;
if ($is_bam) {
    open my $infh,"samtools view -H $in | " or die "samtools view $in: $!";
    print $outfh $_ while <$infh>;
    close $infh;
} else {
    open my $infh,$in                       or die "$in: $!";
    while (<$infh>) {
	last unless /^\@/;
	print $outfh $_;
    }
    close $infh;
}

my ($infh,$block_data_offset,$offset,$block_buffer,$key,$block_index);
$block_data_offset = $offset = tell($outfh);   # remember where the block data starts

if ($in =~ /\.bam$/) {
    open $infh,"samtools view $in | sort | " 
} else {
    open $infh,"sort $in                    |"  or die "sort $in: $!";
}

while (<$infh>) {
    next if /^@/; # ignore headers
    my @fields = split "\t";
    my $line   = join("\t",@fields[0,1,2,3,4,5,6,7,8,11..$#fields]);

    # the key keeps track of the first ID in the block
    # we constrain IDs to always fall in the same block
    $key           = $fields[0] if !defined $key;

    if ( ($fields[0] ne $key) && (length($block_buffer) + length($line) > BLOCKSIZE)) {
	update_index($key,$offset,\$block_index);
	write_compressed_block($outfh,$block_buffer);
	$offset       = tell($outfh);
	$block_buffer = $line;
	$key          = $fields[0];
    } else {
	$block_buffer .= $line;
    }
}

# last block
update_index($key,$offset,\$block_index);
write_compressed_block($outfh,$block_buffer);

# provide dummy key at the very end to enable length retrieval
update_index('~',tell($outfh),\$block_index);

# $offset now contains the position where the index starts
$offset = tell($outfh);

# now write index
write_compressed_block($outfh,$block_index);

# and update the header
seek($outfh,4,0);
print $outfh pack('LLL',HEADER,$block_data_offset,$offset) or die "write of output file failed: $!";
close $outfh or die "close of output file failed: $!";

exit 0;

sub update_index {
    my ($key,$offset,$index) = @_;
    $$index .= pack('Z*N',$key,$offset);
}

sub write_compressed_block {
    my ($outfh,$data) = @_;
    my $compressed_stream = IO::Compress::Bzip2->new($outfh);
    $compressed_stream->print($data) or die "write compressed stream failed: $!";
    $compressed_stream->close()      or die "compression failed: $!";
}

