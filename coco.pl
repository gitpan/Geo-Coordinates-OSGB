use Geo::Coordinates::OSGB qw/ll_to_grid grid_to_ll parse_GPS_grid format_grid_GPS/;
use strict;

my $lat = shift;
my $lon = shift;

my ($e, $n) = ll_to_grid($lat, $lon);
printf "%s %s %s\n", $e, $n, scalar format_grid_GPS($e, $n);

$e = shift;
$n = shift;
($e,$n) = parse_GPS_grid($e) unless defined $n;
print "--> $e $n\n";

($lat, $lon) = grid_to_ll($e, $n);
printf "Lat: %f Lon: %f\n", $lat, $lon;
printf "Lat: %s Lon: %s\n", dd2dms($lat), dd2dms($lon);
exit;

sub dd2dms {
    my $dd = shift;
    my $d = int($dd);     $dd = $dd-$d;
    my $m = int($dd*60);  $dd = $dd-$m/60;
    my $s = sprintf '%.3f', $dd*3600;
    return "$d $m $s";
}
