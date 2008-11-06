# Toby Thurston --- 22 Sep 2008

# out of range conditions

use strict;
use Geo::Coordinates::OSTN02 qw/ETRS89_to_OSGB36 OSGB36_to_ETRS89/;
use Geo::Coordinates::OSGB   qw/grid_to_ll ll_to_grid/;

use Test::Simple tests=>4;

my $r = Geo::Coordinates::OSTN02::_get_ostn_ref(0,0);
ok( @$r == 3 && $r->[0] == 0 && $r->[1] == 0 && $r->[2] == 0 );

my ($ETRS_e, $ETRS_n) = ll_to_grid(55.2597198486328,-6.1883339881897, 'ETRS89');

ok($ETRS_e == 133894.603 && $ETRS_n == 604236.831,
  "$ETRS_e <> 133894.603    $ETRS_n <> 604236.831");

my ($e, $n) = ETRS89_to_OSGB36($ETRS_e, $ETRS_n);
ok($e == 133894.603 && $n == 604236.831,
  "$e <> 133894.603    $n <> 604236.831");

my ($OFF_e, $OFF_n) = ll_to_grid(66,40, 'ETRS89');
my ($zze, $zzn) = ETRS89_to_OSGB36($OFF_e, $OFF_n);

ok($zze == 2184421.573 && $zzn == 2427674.014,
  "$zze <> 2184421.573    $zzn <> 2427674.014");
