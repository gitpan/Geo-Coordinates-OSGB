#! /usr/bin/perl -w

# Toby Thurston ---  8 Oct 2008
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
my ($lon, $lat) = grid_to_ll($e, $n);
my ($glo, $gla, undef) = shift_ll_into_WGS84($lon, $lat);

print "Your input: $gr\n";
printf "is %s\n", scalar format_grid_landranger($e, $n);

printf "and %s on that sheet\n",   scalar format_ll_trad($lon, $lat);
printf "but %s in WGS84 terms\n", scalar format_ll_trad($glo, $gla);
printf "or in ISO form %s.\n", scalar format_ll_ISO($glo, $gla);
