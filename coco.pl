use Geo::Coordinates::OSGB qw/grid2map grid2ll/;
use strict;
my $gr = shift;
print scalar grid2ll($gr),"\n";
print scalar grid2map($gr),"\n";
