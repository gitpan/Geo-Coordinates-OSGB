#! perl -w

use strict;
use warnings;

use Geo::Coordinates::OSGB qw/parse_grid grid_to_ll shift_ll_into_WGS84 format_ll_dms format_grid_landranger/;

my $gr = "@ARGV";

my ($e, $n) = parse_grid($gr);
my ($lon, $lat) = grid_to_ll($e, $n);
my ($glo, $gla, undef) = shift_ll_into_WGS84($lon, $lat);

print "Your input: $gr\n";
printf "is %s\n", scalar format_grid_landranger($e, $n);

printf "and %s on that sheet\n", format_ll_dms($lon, $lat);
printf "but %s in WGS84 terms.\n", format_ll_dms($glo, $gla);
