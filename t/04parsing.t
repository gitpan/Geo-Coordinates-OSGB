# Toby Thurston ---  4 Sep 2007

# test grid ref parsing

use Test::Simple tests=>5;

use Geo::Coordinates::OSGB qw(
    parse_trad_grid
    parse_GPS_grid
    parse_grid
    parse_landranger_grid
    format_grid_trad
);

ok( parse_grid('176/238714') eq parse_landranger_grid(176,238,714),     'Parse sheets');
ok( parse_grid('TA123567')   eq parse_trad_grid('TA123567'),            'Parse trad1');
ok( parse_grid(1)            eq parse_landranger_grid(1),                    'Parse sheet1');
ok( parse_grid(1)            eq format_grid_trad(429000,1179000) ,      'Parse formatting');
ok( parse_grid(204)          eq format_grid_trad(172000,14000) ,        'Parse formatting');


