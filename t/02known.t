# Toby Thurston ---  4 Sep 2007

# test a known location converts correctly

use Geo::Coordinates::OSGB ':all';

use Test::Simple tests => 17;

# the sw corner of OS Explorer sheet 161 (Cobham, Surrey)
# check we are within 10m (easily the limit of my ability
# to measure on a 1:25000 map)
# Note that here we are using OSGB36 through out, because the LL printed on OS maps
# is not based on WGS84

my ($e,$n) = ll_to_grid(51+20/60, -25/60);
my ($expected_e, $expected_n) = (510290, 160606);
ok( abs($expected_e-$e)<=10 && abs($expected_n-$n)<=10, "($e, $n) <=> ($expected_e, $expected_n)" );

my $gr = format_grid_trad(ll_to_grid(51+20/60, -25/60));
my $expected_gr = 'TQ 102 606';
ok( $gr eq $expected_gr, "$gr <=> $expected_gr");

# Hills above Loch Achall, OS Sheet 20
$gr = format_grid_GPS(ll_to_grid(57+55/60, -305/60));
$expected_gr = 'NH 17380 96054';
ok( $gr eq $expected_gr, "$gr <=> $expected_gr");

# and now a boggy path just north of Glendessary in Lochaber
# OS Sheet 40 topright corner.  A graticule intersection at
# 57N 5o20W is marked.  GR measured from the map.
# Fail unless we get to within 0.001 of a degree.
# it is not clear that Landranger sheets are printed to this accuracy this far north

my $eps = 0.001;

#56.9998371807847 57 -5.33448546228202 -5.333 NOT ok 4
#56.999834988726 57 -5.33456762730497 -5.333 NOT ok 4
my ($lat,$lon) = grid_to_ll(197600,794800);
my ($expected_lat, $expected_lon) = (57, -5.3333333333333);
ok( abs($expected_lat-$lat)<$eps && abs($expected_lon-$lon)<$eps, 'Glendessary');

my $isoform = format_ll_ISO(grid_to_ll(parse_trad_grid('NM975948')));
my $expected_iso = '+5700-00520/';
ok( $isoform eq $expected_iso, ">>$isoform<< Path above Glendessary");

$isoform = format_ll_ISO(grid_to_ll(parse_trad_grid('SX700683')));
$expected_iso = '+5030-00350/';
ok( $isoform eq $expected_iso, 'Scorriton, Devon');

$isoform = format_ll_ISO(grid_to_ll(parse_trad_grid('TQ103606')));
$expected_iso = '+5120-00025/';
ok( $isoform eq $expected_iso, $isoform . 'Chobham, Surrey');

($lat,$lon) = grid_to_ll(510350,160600);
($expected_lat, $expected_lon) = (51+20/60, -25/60);
ok( abs($expected_lat-$lat)<$eps && abs($expected_lon-$lon)<$eps, 'Chobham, Again');

$isoform = format_ll_ISO(grid_to_ll(parse_trad_grid('NH173960')));
$expected_iso = '+5755-00505/';
ok( $isoform eq $expected_iso, 'Glen Achall, Ullapool');

sub test_me {
    return format_grid_trad(ll_to_grid(grid_to_ll(parse_trad_grid($_[0]))));
}

ok( test_me('NM975948') eq 'NM 975 948' ,"NM975948");
ok( test_me('NH073060') eq 'NH 073 060' ,"NH073060");
ok( test_me('SX700682') eq 'SX 700 682' ,"SX700682");
ok( test_me('TQ103606') eq 'TQ 103 606' ,"TQ103606");
ok( test_me('HY554300') eq 'HY 554 300' ,"HY554300");

$isoform = format_ll_ISO(grid_to_ll(parse_trad_grid('HY232040')));
$expected_iso = '+5855-00320/';
ok( $isoform eq $expected_iso, 'Hoy, Orkney');

$gr = format_grid_trad(parse_landranger_grid('40','975948'));
$expected_gr = 'NM 975 948';
ok( $gr eq $expected_gr, "$gr <=> $expected_gr");

# Greenwich -- important test for long == 0
$gr = format_grid_trad(ll_to_grid(51.5,0));
$expected_gr = 'TQ 388 798';
ok( $gr eq $expected_gr, "$gr <=> $expected_gr");
