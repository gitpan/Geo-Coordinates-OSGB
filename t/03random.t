# Toby Thurston --- 30 Jan 2007

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
    );

use Test::Simple tests => 20;

$eps = 0.0001;

for (1..10) {
    $phi = rand() * 2 + 51;  # 51 -- 53
    $lam = rand() * 2 - 1 ;  # -1 -- +1

    ($E,$N) = ll_to_grid($phi,$lam);
    ($phi2,$lam2) = grid_to_ll($E,$N);

  # warn sprintf  "%6f :: $phi => $E => $phi2\n",abs($phi-$phi2);
  # warn sprintf  "%6f :: $lam => $N => $lam2\n",abs($lam-$lam2);

    ok( abs($phi-$phi2)<$eps && abs($lam-$lam2)<$eps, sprintf "LL: %8.5f°=%8.5f°", $phi, $phi2);
}

# now test 10 random grid locations and cycle them through grid -> short grid -> map

for (1..10) {

    $e = rand() * 289000 + 269000; # sheet 170 -- 122
    $n = rand() * 225000 + 165000; # sheet 170 -- 122

    (undef, $e, $n, @sheets) = format_grid_landranger($e,$n);

    if ( @sheets ) {
        $gr1 = format_grid_trad(
                     parse_landranger_grid($sheets[0],sprintf("%03d",$e),sprintf("%03d",$n))
               );
        $gr2 = format_grid_trad(
                 ll_to_grid(
                   grid_to_ll(
                     parse_landranger_grid($sheets[0],sprintf("%03d",$e),sprintf("%03d",$n))
                   )
                 )
               );

        ok( ($gr1 eq $gr2) && ($sheets[0] > 100) && ($sheets[0] < 180), "GR: $gr1 eq $gr2" );

    }
}
