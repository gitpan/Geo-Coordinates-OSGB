# Toby Thurston --- 28 Sep 2008

# test grid ref parsing and ll parsing

use Test::Simple tests=>24;

use Geo::Coordinates::OSGB qw(
    parse_trad_grid
    parse_GPS_grid
    parse_grid
    parse_landranger_grid
    format_grid_trad
    ll_to_grid
    grid_to_ll
    shift_ll_from_WGS84
    shift_ll_into_WGS84
);

ok( parse_grid('176/238714') eq parse_landranger_grid(176,238,714),     'Parse sheets');
ok( parse_grid('TA123567')   eq parse_trad_grid('TA123567'),            'Parse trad1');
ok( parse_grid('TA123567')   eq parse_trad_grid('TA 123 567'),          'Parse trad1a');
ok( parse_grid('TA123567')   eq parse_trad_grid('TA','123567'),         'Parse trad2');
ok( parse_grid('TA123567')   eq parse_trad_grid('TA',123,567),          'Parse trad3');
ok( parse_grid(1)            eq parse_landranger_grid(1),                    'Parse sheet1');
ok( parse_grid(1)            eq format_grid_trad(429000,1179000) ,      'Parse formatting');
ok( parse_grid(204)          eq format_grid_trad(172000,14000) ,        'Parse formatting');


ok( (($e,$n) = parse_grid('TQ 234 098')) && $e == 523_400 && $n == 109_800 , "Help example 1 $e $n");
ok( (($e,$n) = parse_grid('TQ234098')  ) && $e == 523_400 && $n == 109_800 , "Help example 2 $e $n");
ok( (($e,$n) = parse_grid('TQ',234,98) ) && $e == 523_400 && $n == 109_800 , "Help example 3 $e $n");

ok( (($e,$n) = parse_grid('TQ 23451 09893')) && $e == 523_451 && $n == 109_893 , "Help example 4 $e $n");
ok( (($e,$n) = parse_grid('TQ2345109893')  ) && $e == 523_451 && $n == 109_893 , "Help example 5 $e $n");
ok( (($e,$n) = parse_grid('TQ',23451,9893) ) && $e == 523_451 && $n == 109_893 , "Help example 6 $e $n");

# You can also get grid refs from individual maps.
# Sheet between 1..204; gre & grn must be 3 or 5 digits long

ok( (($e,$n) = parse_grid(176,123,994)     ) && $e == 512_300 && $n == 199_400 , "Help example 7 $e $n");
#
# With just the sheet number you get GR for SW corner
ok( (($e,$n) = parse_grid(184)) && $e == 389000 && $n == 115000 , "Help example 8 $e $n");


my
$gr = ll_to_grid(52.5,-5);            ok( $gr eq 'SM 963 933', "ISO form LL parsing -> $gr ");
$gr = ll_to_grid('+52.5-005/');       ok( $gr eq 'SM 963 933', "ISO form LL parsing -> $gr ");
$gr = ll_to_grid('+5230-00025/');     ok( $gr eq 'TL 074 903', "ISO form LL parsing -> $gr ");
$gr = ll_to_grid('+512021-0002502/'); ok( $gr eq 'TQ 102 612', "ISO form LL parsing -> $gr ");
$gr = ll_to_grid('+52-002/');         ok( $gr eq 'SP 000 335', "ISO form LL parsing -> $gr ");
$gr = ll_to_grid('+5255+00110+74/');  ok( $gr eq 'TG 128 402', "ISO form LL parsing -> $gr ");
$gr = ll_to_grid(shift_ll_from_WGS84(53.222691,-3.327814));
ok( $gr eq 'SJ 114 703', "ISO form LL parsing -> $gr ");


my
$ll = grid_to_ll(parse_grid('SM 963 933')); ok($ll eq '+5230-00500/');
