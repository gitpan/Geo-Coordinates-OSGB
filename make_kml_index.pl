#! /usr/bin/perl -wc

use strict;
use warnings;
use Readonly;

# Create a KML file to show all the LR sheets in Google Earth

warn "**************************************************************************************\n";
warn "***********  Experimental output!  May not work in your version of Google Earth ******\n";
warn "***********  Experimental output!  May not work in your version of Google Earth ******\n";
warn "***********  Experimental output!  May not work in your version of Google Earth ******\n";
warn "***********  Experimental output!  May not work in your version of Google Earth ******\n";
warn "**************************************************************************************\n";

# approach:
# using OSGB::CC get all the SW corner locations for each sheet in m
# workout the coordinates of each corner (by adding 40km)
# and translate to ll WGS84

# write KML header
# for each square write a polygon into the
# write KML trailer

use XML::Simple;
use Geo::Coordinates::OSGB qw(grid_to_ll parse_landranger_grid format_grid_GPS);
use Geo::Coordinates::OSTN02 qw(OSGB36_to_ETRS89);
use Getopt::Std;

sub grid2ll {
    my $e = shift;
    my $n = shift;
    my ($x,$y,undef) = OSGB36_to_ETRS89($e,$n,0);
    my ($lat, $lon) = grid_to_ll($x,$y,'ETRS89');
    return ($lat, $lon);
}

my @sheets = ();
Readonly my $sheet_size => 40_000; # in metres
Readonly my $sheet_count => 204; # in metres

for my $s (1..$sheet_count) {
    my ($swe, $swn) = parse_landranger_grid($s);
    push @sheets, { number => $s,
                    sw => [ grid2ll( $swe             , $swn             ) ],
                    nw => [ grid2ll( $swe             , $swn+$sheet_size ) ],
                    ne => [ grid2ll( $swe+$sheet_size , $swn+$sheet_size ) ],
                    se => [ grid2ll( $swe+$sheet_size , $swn             ) ],
                  };
}


print <<'END_HEADER';
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.0">
<Document>
<name>OSGB_Landranger_index.kml</name>
<Style id="normalLRMaps">
<PolyStyle id="MagentaOutline">
      <color>bb00bbff</color>
      <fill>0</fill>
      <outline>1</outline>
</PolyStyle>
</Style>
<Style id="selectLRMaps">
<PolyStyle id="MagentaOutline">
      <color>bb00bbff</color>
      <fill>0</fill>
      <outline>3</outline>
</PolyStyle>
</Style>
<StyleMap id="LRMaps">
  <Pair>
    <key>normal</key>
    <styleUrl>#normalLRMaps</styleUrl>
  </Pair>
  <Pair>
    <key>highlight</key>
    <styleUrl>#selectLRMaps</styleUrl>
  </Pair>
</StyleMap>
END_HEADER

for my $s (@sheets) {
    print "<Placemark>\n";
    print "<name>Sheet $s->{number}</name>\n";
    print "<styleURL>#LRMaps</styleURL>\n";
    print "<description>Sheet $s->{number}</description>\n";
    print "<Polygon><outerBoundaryIs><LinearRing><coordinates>\n";
    print join(',', reverse(@{$s->{sw}}), 0) , "\n";
    print join(',', reverse(@{$s->{nw}}), 0) , "\n";
    print join(',', reverse(@{$s->{ne}}), 0) , "\n";
    print join(',', reverse(@{$s->{se}}), 0) , "\n";
    print join(',', reverse(@{$s->{sw}}), 0) , "\n";
    print "</coordinates></LinearRing></outerBoundaryIs></Polygon>\n";
    print "</Placemark>\n";
}


print <<'END_FOOTER';
</Document>
</kml>
END_FOOTER
