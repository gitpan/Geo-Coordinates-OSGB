# Toby Thurston ---  4 Sep 2007

# test grid ref parsing

use Test::Simple tests=>2;

use Geo::Coordinates::OSGB qw(
    parse_trad_grid
    parse_GPS_grid
    parse_grid
    parse_landranger_grid
);

ok( parse_grid('176/238714') eq parse_landranger_grid(176,238,714),     'Parse sheets');
ok( parse_grid('TA123567')   eq parse_trad_grid('TA123567'),            'Parse trad1');


