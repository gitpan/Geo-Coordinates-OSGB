# Toby Thurston ---  7 Sep 2007

# tests from the OS paper

use strict;
use Geo::Coordinates::OSTN02 qw/ETRS89_to_OSGB36 OSGB36_to_ETRS89/;
use Geo::Coordinates::OSGB   qw/grid_to_ll ll_to_grid/;

use Test::Simple tests=>3;

my ($ETRS_e, $ETRS_n) = ll_to_grid(52.658007833, 1.716073973, 'ETRS89');
ok($ETRS_e == 651307.003 && $ETRS_n == 313255.686,
  "$ETRS_e <> 651307.003    $ETRS_n <> 313255.686");

my ($e, $n) = ETRS89_to_OSGB36($ETRS_e, $ETRS_n);
ok($e == 651409.792 && $n == 313177.448,
  "$e <> 651409.792    $n <> 313177.448");


# start again
my ($e3, $n3) = OSGB36_to_ETRS89(651409.792, 313177.448);
ok($e3 == 651307.003 && $n3 == 313255.686,
  "$e3 <> 651307.003    $n3 <> 313255.686");
