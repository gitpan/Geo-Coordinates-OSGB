#! /usr/bin/perl -w

# Toby Thurston ---  8 Oct 2008
# Find all the 000 000 grid references that are on a LR map

use strict;
use Geo::Coordinates::OSGB "format_grid_landranger";

my @out = ();

my %title_for = ();

open F, 'lr-index.txt';
while (<F>) {
    next if /\A#/;
    my (undef, undef, $s, undef, undef, undef, undef, undef, @title) = split;
    $title_for{$s} = "@title";
}

for my $n (0 .. 12) {
    for my $e (0 .. 7) {
        my ($sq, undef, undef, @sheets) = format_grid_landranger($e*100000, $n*100000);
        next unless @sheets;
        my $title = $title_for{$sheets[0]};
        push @out, "$sq 000 000 is on Landranger sheet $sheets[0] $title\n";
    }
}

print sort @out;
