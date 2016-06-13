package Bio::DB::DamFile;

our $VERSION = '1.00';

=head1 NAME

Bio::DB::DamFile -- Create and manage dessicated BAM sequence read files

=head1 SYNOPSIS

# Create a new DAM file from a BAM file.  "reads.bam" is the existing BAM
# file.  "dessicated.dam" is the new dessicated file.  There is
# typically an 8x reduction in size.

$dam = Bio::DB::DamFile->new;
$dam->dessicate('reads.bam','dessicated.dam');

# Open an existing DAM file:
$dam = Bio::DB::DamFile->new('dessicated.dam');

# Restore a BAM file from a DAM file. The source of reads can be a
# BAM, TAM or FASTQ file. The mapping information from the DAM file is
# retained.
# "reads.bam" is a source of read and quality information; can be
#             BAM, TAM or FASTQ
# "hydrated.bam" is the reconstituted BAM file

$dam->rehydrate('reads.bam','hydrated.bam')

# Fetch SAM lines one at a time from the DAM file.
# Reads will come out in alphabetic order by read_id.

while ($sam_line = $dam->next_read) {
    print $sam_line,"\n";
}

# More sophisticated: use an iterator to seek into
# the file at the location of a particular read.
# Reads will come out in alphabetic order by read_id,
# starting with the provided read id.
$iterator = $dam->read_iterator('NA06984-SRR006041.1000244');
while ($sam_line = $iterator->next_read) {
    print $sam_line,"\n";
}

# Return all SAM lines that match a particular id
$sam_lines = $dam->fetch_read('NA06984-SRR006041.1000244');
print join ("\n",@$sam_lines),"\n";

# Get the SAM header information
$header    = $dam->sam_header;

# Get the path to the original BAM file that was used to create the
# DAM file
$path      = $dam->source_path;

=head1 DESCRIPTION

This module was created to solve the issue of maintaining multiple
aligned BAM files from the same set of reads. This happens when a BAM
file is remapped onto different genome builds or using different
alignment software/settings. Rather than have multiple copies of the
same read and quality score information, one wishes to maintain a
single BAM (or FASTQ) file with the read information, and store the
alternative alignments in separate data files.

The DAM ("dessicated BAM") format is very simple, and consists of the
standard SAM header followed by a series of bzip2-compressed chunks of
SAM (text format) alignment lines from which the read and quality
score fields have been removed. This is followed by an index

=head1 METHODS

=cut

use strict;

use Bio::DB::DamFile::Common;
use Bio::DB::DamFile::Iterator;

use IO::Uncompress::Bunzip2 qw(bunzip2);
use List::BinarySearch      qw(binsearch_pos binsearch);
use Carp                    qw(croak);
use Tie::Cache;             # SHOULD USE Tie::Cache::LRU FOR SPEED

sub new {
    my $class    = shift;
    my $damfile  = shift;
    my $options  = shift;
    return bless {
	damfile       => $damfile,
	header_data   => undef,
	damfh         => undef,
	options       => $options || {},
    },ref $class || $class;
}

sub damfile     { shift->{damfile} }
sub block_cache_size {
    my $self = shift;
    return $self->{options}{cache_size} ||= DEFAULT_BLOCK_CACHE_SIZE;
}
sub header_magic  {
    my $self = shift;
    $self->{header_data} ||= $self->_get_dam_header;
    $self->{header_data}{magic};
}

sub header_offset  {
    my $self = shift;
    $self->{header_data} ||= $self->_get_dam_header;
    $self->{header_data}{header_offset};
}
sub block_offset {
    my $self = shift;
    $self->{header_data} ||= $self->_get_dam_header;
    $self->{header_data}{block_offset};
}
sub index_offset {
    my $self = shift;
    $self->{header_data} ||= $self->_get_dam_header;
    $self->{header_data}{index_offset};
}
sub source_path {
    my $self = shift;
    $self->{header_data} ||= $self->_get_dam_header;
    $self->{header_data}{original_path};
}

sub fetch_read {
    my $self    = shift;
    my $read_id = shift or die "Usage \$readline = Bio::DB::DamFile->fetch_read(\$read_id)";

    my ($block_index) = $self->_lookup_block($read_id)    or croak "Read $read_id not found in DB.";
    my $lines         = $self->_fetch_block($block_index) or croak "Block fetch error while retrieving block at $block_index: $!";

    my $key   = "$read_id\t"; # terminate match at tab

    my $len   = length($key);
    my $i     = binsearch {$a cmp substr($b,0,$len)} $key,@$lines;

    croak "Read $read_id not found in DB." unless defined $i;
    
    # there may be more than one matching read line, but they will be adjacent!
    my @matches;
    while (substr($lines->[$i],0,$len) eq $key) {
	push @matches,$lines->[$i++];
    }
    
    return \@matches;
}

sub dessicate {
    my $self   = shift;
    my ($infile,$damfile) = @_;
    $damfile            ||= eval {$self->damfile};
    $infile && $damfile   or die "usage: \$bd->dessicate(\$sam_or_bamfile_in,\$damfile_out)";

    eval 'require Bio::DB::DamFile::Creator' 
	unless Bio::DB::DamFile::Creator->can('new');
    Bio::DB::DamFile::Creator->new($damfile)->dessicate($infile);
    $self->{damfile} = $damfile;
}

sub rehydrate {
    my $self   = shift;
    my ($infile,$outfile) = @_;

    $infile && $outfile or croak "Usage: Bio::DB::DamFile->rehydrate(\$bam_sam_or_fastq_file_in,\$bamfile_out)";

    open my $outfh,"| samtools view -b -S - > $outfile" or die "Can't open samtools pipe to write $outfile";

    # write out the SAM header
    my $fh = $self->_open_damfile;
    my $offset = $self->header_offset;
    my $len    = $self->block_offset - $offset;
    seek($fh,$self->header_offset,0);
    my $buffer;
    read($fh,$buffer,$len) or die "Couldn't read $len header bytes from DAM file at offset $offset";
    print $outfh $buffer;

    # write out the contents
    # infile can be any of:
    # (1) a bam file (.bam)
    # (2) a sam file (.sam or .tam)
    # (3) a fastq file (.fastq)

    if ($infile =~ /\.bam$/) {
	$self->_rehydrate_bam($infile,$outfh);
    } elsif ($infile =~ /\.[st]am$/) {
	$self->_rehydrate_sam($infile,$outfh);
    } elsif ($infile =~ /\.fastq(?:\.gz|\.bz2)?$/) {
	$self->_rehydrate_fastq($infile,$outfh);
    } else {
	croak "$infile has an unknown extension (must be one of .bam, .sam, .tam or .fastq)";
    }

    close $outfh or die "error closing $outfile: $!";
}

sub read_iterator {
    my $self = shift;
    return Bio::DB::DamFile::Iterator->new($self,@_);
}

sub next_read {
    my $self  = shift;
    $self->{iterator} ||= $self->read_iterator(@_);
    my $read = $self->{iterator}->next_read();
    undef $self->{iterator} if !defined $read;
    return $read;
}

sub _rehydrate_bam {
    my $self = shift;
    my ($infile,$outfh) = @_;
    open my $infh,"samtools view $infile | sort -k1,1 |" or die "Can't open samtools to read from $infile: $!";
    warn "Sorting input BAM by read name. This may take a while...\n";
    $self->_rehydrate_stream($infh,$outfh);
}

sub _rehydrate_sam {
    my $self = shift;
    my ($infile,$outfh) = @_;
    open my $infh,"grep -v '\@' $infile | sort -k1,1 |" or die "Can't open $infile: $!";
    warn "Sorting input SAM by read name. This may take a while...\n";
    $self->_rehydrate_stream($infh,$outfh);
}

sub _rehydrate_fastq {
    my $self = shift;
    my ($infile,$outfh) = @_;

    # need to create a stream of sorted SAM-like data for passing to _rehydrate_stream()
    my $pid = open(my $infh,"-|") // die "Can't fork!";

    if ($pid) { # in parent process
	$self->_rehydrate_stream($infh,$outfh);
	return;
    } 

    else {  # in child process
	my $fastq_fh;

	# open appropriate unzipper
	if ($infile =~ /\.gz$/) {
	    open $fastq_fh,"gunzip -c $infile |"  or die "gunzip   -c $infile: $!";
	} elsif ($infile =~ /\.bz2$/) {
	    open $fastq_fh,"bunzip2 -c $infile |" or die "bunzip2 -c $infile: $!";
	} else {
	    open $fastq_fh,'<',$infile            or die "failed opening $infile for reading: $!";
	}
	open my $sort_fh,"| sort -k1,1"           or die "failed opening output pipe to sort: $!";

	local $/ = '@';
	while (<$fastq_fh>) {
	    chomp;
	    next unless $_;
	    my ($read_id,$dna,undef,$quality) = split "\n";
	    #             field      0        1     2     3     4     5     6     7     8     9    10
	    print $sort_fh join("\t",$read_id,undef,undef,undef,undef,undef,undef,undef,undef,$dna,$quality),"\n";
	}
	close $sort_fh                            or die "An error occurred while closing the sort pipe filehandle: $!";
	exit 0;
    }
}

sub _rehydrate_stream {
    my $self = shift;
    my ($infh,$outfh) = @_;

    my $iterator = $self->read_iterator();

    my @sam_fields = ('');
    my $sam_done;

    while (my $dam_line = $iterator->next_read) {
	my @dam_fields = split "\t",$dam_line;

	while (!$sam_done && ($sam_fields[0] lt $dam_fields[0])) { # read from sam file until we match
	    chomp (my $sam_line = <$infh>);
	    $sam_done++ unless $sam_line;
	    @sam_fields = split "\t",$sam_line;
	    last if $sam_fields[0] ge $dam_fields[0];
	}

	if ($sam_done) {
	    # sequence missing
	    print $outfh join("\t",@dam_fields[0..8],
			           '*','*',
			           @dam_fields[11..$#dam_fields]),"\n";
	} 

	elsif ($dam_fields[0] eq $sam_fields[0]) { #match
	    print $outfh join("\t",@dam_fields[0..8],
			           @sam_fields[9,10],
			           @dam_fields[11..$#dam_fields]),"\n";
	}
    }
}

sub _open_damfile {
    my $self = shift;
    return $self->{damfh} 
       if defined $self->{damfh} && defined fileno($self->{damfh});

    open my $fh,'<',$self->damfile or die $self->damfile,": $!";
    $self->{damfh} = $fh;
    
    return $self->{damfh};
}

sub _get_dam_header {
    my $self = shift;
    my $fh = $self->_open_damfile;
    my $buffer;
    seek($fh,0,0);
    read($fh,$buffer,HEADER) or die "Couldn't read from ",$self->damfile,": $!";
    my @data = unpack(HEADER_STRUCT,$buffer);

    my %fields;
    @fields{'magic','header_offset','block_offset','index_offset','original_path'} = @data;

    $fields{magic} eq MAGIC or croak $self->damfile," doesn't have the right magic number";
    return \%fields;
}

sub _lookup_block {
    my $self = shift;
    my $key  = shift;  # a read id

    my $index = $self->_get_read_index;

    # find the first block that might contain the key
    my $i     = binsearch_pos {$a cmp $b->[0]} $key,@$index;
    return if $i < 0 or $i > $#$index;

    $i-- unless $index->[$i][0] eq $key;  # distinguish between an exact match and an insert position
    return $i;
}

sub _fetch_block {
    my $self  = shift;
    my $i     = shift;

    my $cache = $self->_block_cache;
    return $cache->{$i} if defined $cache->{$i};

    my $index = $self->_get_read_index;
    my $offset = $index->[$i][1];
    my $length = $index->[$i+1][1]-$offset;
    return unless $length > 0;

    my $fh     = $self->_open_damfile;

    my $block;
    seek($fh,$offset,0)      or die "seek failed: $!";
    read($fh,$block,$length) or die "read failed: $!";

    my $uncompressed;
    bunzip2(\$block,\$uncompressed);
    my @lines           = split "\n",$uncompressed;
    return $cache->{$i} = \@lines;
}

sub _get_read_index {
    my $self = shift;
    return $self->{read_index} if $self->{read_index};

    my $fh   = $self->_open_damfile;
    seek($fh,$self->index_offset,0);

    my $data = '';
    do {1} while read($fh, $data, 8192, length $data);

    my $index;
    bunzip2(\$data,\$index);
    my @flat = unpack('(Z*Q)*',$index);

    # turn into list of lists
    my @index;
    while (my ($key,$offset) = splice(@flat,0,2)) {
	push @index,[$key,$offset];
    }
    return $self->{read_index} = \@index;
}

sub _block_cache {
    my $self = shift;

    return $self->{block_cache} if defined $self->{block_cache};

    my %c;
    tie %c,'Tie::Cache',{MaxBytes => $self->block_cache_size};
    return $self->{block_cache} = \%c;
}

=head1 SEE ALSO

L<Bio::Perl>, L<Bio::DB::Bam>

=head1 AUTHOR

Lincoln Stein E<lt>lincoln.stein@oicr.on.caE<gt>.
E<lt>lincoln.stein@bmail.comE<gt>

Copyright (c) 2016 Ontario Institute for Cancer Research.

This package and its accompanying libraries are free software; you can
redistribute it and/or modify it under the terms of the Artistic
License 2.0, the Apache 2.0 License, or the GNU General Public License
(version 1 or higher).  Refer to LICENSE for the full license text.

=cut


1;
