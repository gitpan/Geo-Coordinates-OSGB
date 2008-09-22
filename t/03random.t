# Toby Thurston ---  7 Sep 2007

# first test by taking ten random pairs of long/lat in the range of
# the British Isles 1E -- 6W, 49N -- 59N and checking that we
# can convert back and forth with an error of less than 10cm, which
# roughly corresponds to $eps of 0.00001

use Geo::Coordinates::OSGB qw(
    ll_to_grid
    grid_to_ll
    format_grid_landranger
    format_grid_trad
    parse_landranger_grid
    format_ll_ISO
    shift_ll_into_WGS84
    shift_ll_from_WGS84
    );

use Test::Simple tests => 30;
use strict;

my $eps = 0.0001;

for (1..10) {
    my $phi = rand() * 2 + 51;  # 51 -- 53
    my $lam = rand() * 2 - 1 ;  # -1 -- +1

    my ($E,$N) = ll_to_grid($phi,$lam);
    my ($ph2,$la2) = grid_to_ll($E,$N);

    ok( abs($phi-$ph2)<$eps && abs($lam-$la2)<$eps, sprintf "Grid/LL: %s=%s",
                                                    format_ll_ISO($phi, $lam),
                                                    format_ll_ISO($ph2, $la2) );
}


for (1..10) {
    my $phi = rand() * 3 + 51;  # 51 -- 54
    my $lam = rand() * 3 - 2 ;  # -2 -- +1

    my ($p84,$l84) = shift_ll_into_WGS84($phi,$lam);
    my ($ph2,$la2) = shift_ll_from_WGS84($p84,$l84);

    ok( abs($phi-$ph2)<$eps && abs($lam-$la2)<$eps, sprintf "WGS84/LL: %s=%s",
                                                      format_ll_ISO($phi, $lam),
                                                      format_ll_ISO($ph2, $la2) );
}

# now test 10 random grid locations and cycle them through grid -> short grid -> map

for (1..10) {

    my $e = rand() * 289000 + 269000; # sheet 170 -- 122
    my $n = rand() * 225000 + 165000; # sheet 170 -- 122
    my @sheets;

    (undef, $e, $n, @sheets) = format_grid_landranger($e,$n);

    if ( @sheets ) {
        my $gr1 = format_grid_trad(
                     parse_landranger_grid($sheets[0],sprintf("%03d",$e),sprintf("%03d",$n))
               );
        my $gr2 = format_grid_trad(
                 ll_to_grid(
                   grid_to_ll(
                     parse_landranger_grid($sheets[0],sprintf("%03d",$e),sprintf("%03d",$n))
                   )
                 )
               );

        ok( ($gr1 eq $gr2) && ($sheets[0] > 100) && ($sheets[0] < 180), "GR: $gr1=$gr2" );

    }
}
