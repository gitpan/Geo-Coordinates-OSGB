# Toby Thurston -  2 Mar 2001

# first test by taking ten random pairs of long/lat in the range of
# the British Isles 1E -- 6W, 49N -- 59N and checking that we
# can convert back and forth with an error of less than 10cm, which
# roughly corresponds to $eps of 0.00001

use Geo::Coordinates::OSGB qw(ll2grid grid2ll
                              format_grid_landranger
                              map2grid map2ll);

print "1..20\n";

$eps = 0.0001;

for $i (1..10) {
    $phi = rand() * 10 + 49;  # 49 -- 59
    $lam = rand() * 7 - 1  ;  # -1 -- +6

    ($E,$N) = ll2grid($phi,$lam);
    ($phi2,$lam2) = grid2ll($E,$N);

    #  printf  "%6f :: $phi => $E => $phi2\n",abs($phi-$phi2);
    #  printf  "%6f :: $lam => $N => $lam2\n",abs($lam-$lam2);

    unless ( abs($phi-$phi2)<$eps && abs($lam-$lam2)<$eps ) { print "NOT " }
    print "ok $i\n";
}

# now test 10 random grid locations and cycle them through grid -> short grid -> map

for my $i (11..20) {

    $e = rand() * 289000 + 269000; # sheet 170 -- 122
    $n = rand() * 225000 + 165000; # sheet 170 -- 122

    (undef, $e, $n, @sheets) = format_grid_landranger($e,$n);

    if ( @sheets ) {
        $gr1 = map2grid($sheets[0],sprintf("%03d",$e),sprintf("%03d",$n));
        $gr2 = ll2grid(map2ll($sheets[0],sprintf("%03d",$e),sprintf("%03d",$n)));
        $gr2 =~ s/\s//g;
        print "NOT " unless $gr1 eq $gr2 && $sheets[0] > 100 && $sheets[0] < 180;

    }
    print "ok $i\n";

}
