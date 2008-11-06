#! /usr/bin/perl -w

# Toby Thurston ---  5 Nov 2008
# Parse LL and show as National Grid ref

use strict;
use warnings;

use lib 'lib';
use Geo::Coordinates::OSGB qw/
        parse_ISO_ll
        ll_to_grid
        shift_ll_from_WGS84
        format_ll_trad
        format_grid_trad
        format_grid_landranger/;

if ( @ARGV == 0 ) {
    die "Usage: $0 lat lon\n"
}

my ($lon, $lat);
if ( @ARGV == 1 ) {
    ($lon, $lat) = parse_ISO_ll($ARGV[0]);
} else {
    ($lon, $lat) = @ARGV;
}

my ($glo, $gla, undef) = shift_ll_from_WGS84($lon, $lat);
my ($ge, $gn) = ll_to_grid($glo, $gla);
my ($e,  $n)  = ll_to_grid($lon, $lat);

print "Your input: @ARGV\n";
printf "is %s\n", scalar format_ll_trad($lon, $lat);

printf "== %d %d from OSGB  (%s)\n", $e, $n, scalar format_grid_landranger($e, $n);
printf "or %d %d from WGS84 (%s)\n", $ge, $gn, scalar format_grid_landranger($ge, $gn);
