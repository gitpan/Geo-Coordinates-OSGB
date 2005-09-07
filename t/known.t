# Toby Thurston --- 25 Sep 2004

# test a known location converts correctly

use Geo::Coordinates::OSGB qw(ll2grid grid2ll map2grid);

print "1..16\n";

# the sw corner of OS Explorer sheet 161 (Cobham, Surrey)
# check we are within 10m (easily the limit of my ability
# to measure on a 1:25000 map)
my ($e,$n) = ll2grid('+5120','-00025');
print "$e 510300 $n 160600 NOT " unless abs(510300-$e)<=10 && abs(160600-$n)<=10;
print "ok 1\n";

my $gr = ll2grid('+5120','-00025');
print "NOT " unless $gr eq 'TQ 102 606';
print "ok 2\n";

# Hills above Loch Achall, OS Sheet 20
$gr = ll2grid('+5755','-00505','GPS');
print "NOT " unless $gr eq 'NH 17379 96054';
print "ok 3\n";

# and now a boggy path just north of Glendessary in Lochaber
# OS Sheet 40 topright corner.  A graticule intersection at
# 57N 5o20W is marked.  GR measured from the map.
# Fail unless we get to within 0.0001 of a degree.

my ($lat,$lon) = grid2ll(197575,794800);
print "NOT " unless abs(57-$lat)<0.0001 && abs(-5.33333333-$lon)<0.0001;
print "ok 4\n";

my $isoform = grid2ll('NM975948');
print "+5700-00520 <> $isoform <--!\nNOT " unless $isoform eq '+5700-00520';
print "ok 5\n";

$isoform = grid2ll('SX700683');
print "+5030-00350 <> $isoform <--!\nNOT " unless $isoform eq '+5030-00350';
print "ok 6\n";

$isoform = grid2ll('TQ103606');
print "+5120-00025 <> $isoform <--!\nNOT " unless $isoform eq '+5120-00025';
print "ok 7\n";

($lat,$lon) = grid2ll(510350,160600);
print "NOT " unless abs(51.3333-$lat)<0.001 && abs(-0.416666-$lon)<0.001;
print "ok 8\n";

$isoform = grid2ll('NH173960');
print "+5755-00505 <> $isoform <--!\nNOT " unless $isoform eq '+5755-00505';
print "ok 9\n";


print ll2grid(grid2ll('NM975948')) eq 'NM 975 948' ? '' : 'NOT ',"ok 10\n";
print ll2grid(grid2ll('NH073060')) eq 'NH 073 060' ? '' : 'NOT ',"ok 11\n";
print ll2grid(grid2ll('SX700682')) eq 'SX 700 682' ? '' : 'NOT ',"ok 12\n";
print ll2grid(grid2ll('TQ103606')) eq 'TQ 103 606' ? '' : 'NOT ',"ok 13\n";
print ll2grid(grid2ll('HY554300')) eq 'HY 554 300' ? '' : 'NOT ',"ok 14\n";

$isoform = grid2ll('HY232040');
print "+5855-00320 <> $isoform <--!\nNOT " unless $isoform eq '+5855-00320';
print "ok 15\n";

$gr = map2grid('40','975948');
print 'NOT ' unless $gr eq 'NM975948';
print "ok 16\n";
