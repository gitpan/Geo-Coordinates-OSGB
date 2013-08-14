#! /usr/bin/perl -w

# Toby Thurston -- 14 Aug 2013 
# Find all the 000 000 grid references that are on a LR map

use strict;
use Geo::Coordinates::OSGB "format_grid_landranger";

my @out = ();

for my $n (0 .. 12) {
    for my $e (0 .. 7) {
        my ($sq, undef, undef, @sheets) = format_grid_landranger($e*100000, $n*100000);
        next unless @sheets;
        push @out, "$sq 000 000 is on Landranger sheet $sheets[0]\n";
    }
}

print sort @out;
