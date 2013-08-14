#! /usr/bin/perl -w

# Toby Thurston ---  6 May 2009
# Parse a National Grid ref and show it as LL coordinates

use strict;
use warnings;

use Geo::Coordinates::OSGB qw/
        parse_grid
        grid_to_ll
        shift_ll_into_WGS84
        format_ll_trad
        format_ll_ISO
        format_grid_landranger/;

my $gr = "@ARGV";

my ($e, $n) = parse_grid($gr);
my ($lat, $lon) = grid_to_ll($e, $n);
my ($gla, $glo, undef) = shift_ll_into_WGS84($lat, $lon);

print "Your input: $gr\n";
printf "is %s\n", scalar format_grid_landranger($e, $n);

printf "and %s on that sheet\n",   scalar format_ll_trad($lat, $lon);
printf "but %s in WGS84 terms\n", scalar format_ll_trad($gla, $glo);
printf "or in ISO form %s.\n", scalar format_ll_ISO($gla, $glo);

