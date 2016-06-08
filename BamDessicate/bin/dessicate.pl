#!/usr/bin/perl

use strict;

use Bio::DB::DamFile;

my $in  = shift;
my $out = shift;

$in && $out or die "Usage: dessicate.pl <infile.bam> <outfile.dam>";

my $bd = Bio::DB::DamFile->new();
$bd->dessicate($in,$out);

exit 0;

