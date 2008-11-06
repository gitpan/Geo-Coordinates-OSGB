# Toby Thurston --- 28 Sep 2008

# test grid ref parsing and ll parsing

use Test::Simple tests=>13;

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
ok( parse_grid(1)            eq parse_landranger_grid(1),                    'Parse sheet1');
ok( parse_grid(1)            eq format_grid_trad(429000,1179000) ,      'Parse formatting');
ok( parse_grid(204)          eq format_grid_trad(172000,14000) ,        'Parse formatting');

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
