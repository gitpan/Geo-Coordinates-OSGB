#! perl -w
use strict;
#
# A program to produce a post-script plot of all the Landranger sheets,
# complete with the GB coast line and the 100km grid sqaure letters.
# Toby Thurston ---  7 Oct 2008
#
use Geo::Coordinates::OSGB "ll_to_grid", "parse_landranger_grid", "format_grid_GPS";
use Getopt::Std;
our $opt_a = 4;
getopt('a'); # paper size...
$opt_a = 4 unless $opt_a =~ /\A\d\Z/ && $opt_a < 6;


my @sheets = ();
my %squares = ();

my $extreme_south = 200000;
my $extreme_north = 0;
my $extreme_west  = 200000;
my $extreme_east  = 0;

my $sheet_size = 40_000;

my $GR_pattern = qr/^([A-Z][A-Z])(\d\d\d)(\d\d\d)$/;

for my $sheet (1 .. 204) {

    # get the grid coordinates for the SW corner of the map
    my ($x, $y) = parse_landranger_grid($sheet);

    # put this sheet into the list of sheets
    push @sheets, sprintf "%f %f moveto currentpoint %d dup rectstroke %d dup rmoveto (%s) cshow\n",
                          $x/1000, $y/1000, $sheet_size/1000, $sheet_size/2000, $sheet;


    # which grid squares does this sheet touch?
    for my $xx ($x, $x+$sheet_size-100) {
        for my $yy ($y, $y+$sheet_size-100) {
            my ($sq, $e, $n) = format_grid_GPS($xx,$yy);
            next if defined $squares{$sq};
            $squares{$sq} = sprintf "%f %f moveto currentpoint 100 100 rectstroke 50 40 rmoveto (%s) cshow\n",
                                      ($xx-$e)/1000, ($yy-$n)/1000, $sq;

        }
    }

    # keep track of bounding box
    $extreme_east = $x if $x > $extreme_east;
    $extreme_west = $x if $x < $extreme_west;
    $extreme_north = $y if $y > $extreme_north;
    $extreme_south = $y if $y < $extreme_south;

}

# allow for most north-eastern sheets
$extreme_east  += $sheet_size;
$extreme_south += $sheet_size;
$extreme_north += $sheet_size*4; # allow for the top most grid square ...

my $ew_range = $extreme_east-$extreme_west;
my $ns_range = $extreme_north-$extreme_south;

# size of the paper in mm
my ($width, $height) = (148,210);

$opt_a == 4 && (($width, $height) = (210,297));
$opt_a == 3 && (($width, $height) = (297,420));
$opt_a == 2 && (($width, $height) = (420,594));
$opt_a == 1 && (($width, $height) = (594,840));
$opt_a == 0 && (($width, $height) = (840,1188));

# convert to points and deduct margins (20pts)
$width  = int($width  / 25.4 * 72 + 0.5) - 40;
$height = int($height / 25.4 * 72 + 0.5) - 40;

my $urx = $width  + 20;
my $ury = $height + 20;

my $scale = 1000 * $width / $ew_range;
my $h_scale = 1000 * $height / $ns_range;
$scale = $h_scale if $h_scale < $scale;

print << "PREAMBLE";
%!PS-Adobe-3.0 EPSF-3.0
%%Creator: $0
%%Copyright: (C) 2008 Toby Thurston
%%Title:(Index to the Landranger Sheets)
%%CreationDate: (17 Jan 2008)
%%BoundingBox: 20 20 $urx $ury
%%Pages: 1
%%EndComments
%%BeginSetup
/Large { /Helvetica 24 selectfont } def
/small { /Helvetica 8 selectfont } def
/cshow { /s exch def s stringwidth pop neg 2 div dup 0 exch 0 rmoveto s show rmoveto } def
%%EndSetup
%%Page: 1 1
%%BeginPageSetup
/pgsave save def
%%EndPageSetup
small
$scale dup scale
170 30 translate
-120 0 850 1280 rectclip

PREAMBLE

# a file of longitude & latitude data in "matlab" format
open GB, "<gb-coastline.dat";
my $cmd = "moveto";
print "gsave .6 .6 1 setrgbcolor\n";
while (<GB>) {
    chomp;
    my ($lon, $lat) = split;
    if ( $lon eq '#' ) {
        print "stroke\n";
        $cmd = 'moveto'
    }
    else {
        my ($e, $n) = ll_to_grid($lat,$lon);
        printf "%.3f %.3f %s\n", $e/1000, $n/1000, $cmd;
        $cmd = 'lineto' if ($cmd eq 'moveto');
    }
}
close GB;
print "grestore\n";

print "gsave .6 1 .6 setrgbcolor\n";
for my $lon (-9 .. 2) {
    my ($e, $n) = ll_to_grid(49.95, $lon);
    printf "%.3f %.3f moveto gsave 2 0 rmoveto small ($lon) show /degree glyphshow grestore\n", $e/1000, $n/1000;
    for my $lat (500 .. 609) {
        ($e,$n) = ll_to_grid($lat/10, $lon);
        printf "%.3f %.3f lineto\n", $e/1000, $n/1000;
    }
    print "gsave 2 0 rmoveto small ($lon) show /degree glyphshow grestore stroke\n";
}

for my $lat (51 .. 60) {
    my ($e, $n) = ll_to_grid($lat, -9.2);
    printf "%.3f %.3f moveto gsave -2 2 rmoveto small ($lat) show /degree glyphshow grestore\n", $e/1000, $n/1000;
    for my $lon (-91 .. 22) {
        ($e,$n) = ll_to_grid($lat, $lon/10);
        printf "%.3f %.3f lineto\n", $e/1000, $n/1000;
    }
    print "gsave 0 2 rmoveto small ($lat) show /degree glyphshow grestore stroke\n";
}
print "grestore\n";

print "gsave Large 1 .6 .6 setrgbcolor\n";
print $squares{$_} for sort keys %squares;
print "grestore\n";

print ".3 setlinewidth\n";
print @sheets;
print "pgsave restore showpage\n%%EOF\n";
