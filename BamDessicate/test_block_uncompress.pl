#!/usr/bin/perl

use strict;

use IO::Uncompress::Bunzip2 qw(bunzip2);
use List::BinarySearch      qw(binsearch_pos binsearch);
use Storable                qw(fd_retrieve);

use constant TEST_DAM => './test.dam';
use constant HEADER   => 512;

my $in  = shift || TEST_DAM;
#my $key = shift || 'NA06984-SRR006041.831209';
my $key  = shift || 'NA06984-SRR006041.1552758';

my ($header,$bam_offset,$block_offset,$index_offset);

open my $infh,'<',$in      or die "$in: $!";
read($infh,$header,HEADER) or die "read: $!";
my ($magic,$bam_offset,$block_offset,$index_offset) = unpack('a4LLL',$header);
$magic eq 'DAM1' or die "Provided file has wrong magic number. Not a dam file?";

# get the index
seek($infh,$index_offset,0) or die "Can't seek: $!";
my $index = fd_retrieve($infh) or die "Can't retrieve index from $in: $!";

# find the first block that might contain the key
my $i     = binsearch_pos {$a cmp $b->[0]} $key,@$index;

die "$key not found" if $i < 0 or $i > $#$index;

$i-- unless $index->[$i][0] eq $key;  # distinguish between an exact match and an insert position
my $offset = $index->[$i][1];
my $length = $index->[$i+1][1]-$offset;

my ($compressed,$uncompressed);
seek($infh,$offset,0);
read($infh,$compressed,$length);

bunzip2(\$compressed,\$uncompressed);
my @lines = split "\n",$uncompressed;

my $len   = length($key);
$i        = binsearch {$a cmp substr($b,0,$len)} $key,@lines;

die "$key not found" unless defined $i;
print $lines[$i],"\n";

exit 0;




