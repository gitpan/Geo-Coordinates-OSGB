package Geo::Coordinates::OSGB;
require Exporter;
use strict;
our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

@ISA = qw(Exporter);

$VERSION = '1.06';

=head1 NAME

Geo::Coordinates::OSGB --- Convert Coordinates from Long/Lat to UK Grid

A UK-specific implementation of co-ordinate conversion, following formulae from the
Ordnance Survey of Great Britain (hence the name).

Version: 1.06

=head1 SYNOPSIS

  use Geo::Coordinates::OSGB qw(ll2grid grid2ll);

  # basic conversion routines
  ($easting,$northing) = ll2grid($lat,$lon);
  ($long,$lat) = grid2ll($easting,$northing);

  # format full easting and northing into traditional formats
  $trad_gr       = format_grid_trad($easting,$northing);  # TQ 234 098
  $GPS_gr        = format_grid_GPS($easting,$northing);   # TQ 23451 09893
  $landranger_gr = format_grid_landranger($easting, $northing) # 234098 on Sheet 176

  # you can call these in list context to get the individual parts
  # add "=~ s/\s//g" to the result to remove the spaces

  # and there are corresponding parse routines to convert from these formats to full e,n
  ($e,$n) = parse_trad_grid('TQ 234 098'); # spaces optional, can give list as well
  ($e,$n) = parse_GPS_grid('TQ 23451 09893'); # spaces optional, can give list as well
  ($e,$n) = parse_landranger_grid($sheet, $gre, $grn); # gre/grn must be 3 or 5 digits long
  ($e,$n) = parse_landranger_grid($sheet); # this gives you the SW corner of the sheet

  # some convenience routines that bundle these up for you
  map2ll();
  map2grid();

  # set parameters
  set_ellipsoid(6377563.396,6356256.91);                 # not needed for UK use
  set_projection(49, -2, 400000, -100000, 0.9996012717); # not needed for UK use


=head1 DESCRIPTION

This module provides a collection of routines to convert between longitude
& latitude and map grid references, using the formulae given in the British
Ordnance Survey's excellent information leaflet, referenced below in
L<"Theory">.

The module is implemented purely in Perl, and should run on any Perl platform.
In this description `OS' means `the Ordnance Survey of Great Britain': the UK
government agency that produces the standard maps of England, Wales, and
Scotland.  Any mention of `sheets' or `maps' refers to one or more of the 204
sheets in the 1:50,000 scale `Landranger' series of OS maps.

=cut

our ($a, $b, $e2, $n);            # ellipsoid constants
our ($N0, $E0, $F0, $phi0, $lam0);# projection constants
use Math::Trig qw(tan sec);
use Carp;

use constant PI  => 4 * atan2 1, 1;
use constant RAD => PI / 180;
use constant DAR => 180 / PI;

our $GSq_Pattern = qr /[GHJMNORST][A-Z]/i;
our $GR_Pattern = qr /^($GSq_Pattern)\s?(\d{3})\D?(\d{3})$/;
our $Long_GR_Pattern = qr /^($GSq_Pattern)\s?(\d{5})\D?(\d{5})$/;

our @Grid = ( [ qw( V W X Y Z ) ],
              [ qw( Q R S T U ) ],
              [ qw( L M N O P ) ],
              [ qw( F G H J K ) ],
              [ qw( A B C D E ) ] );

our %Big_off = (
                 G => { E => -1, N => 2 },
                 H => { E =>  0, N => 2 },
                 J => { E =>  1, N => 2 },
                 M => { E => -1, N => 1 },
                 N => { E =>  0, N => 1 },
                 O => { E =>  1, N => 1 },
                 R => { E => -1, N => 0 },
                 S => { E =>  0, N => 0 },
                 T => { E =>  1, N => 0 },
           );

our %Small_off = (
                 A => { E =>  0, N => 4 },
                 B => { E =>  1, N => 4 },
                 C => { E =>  2, N => 4 },
                 D => { E =>  3, N => 4 },
                 E => { E =>  4, N => 4 },

                 F => { E =>  0, N => 3 },
                 G => { E =>  1, N => 3 },
                 H => { E =>  2, N => 3 },
                 J => { E =>  3, N => 3 },
                 K => { E =>  4, N => 3 },

                 L => { E =>  0, N => 2 },
                 M => { E =>  1, N => 2 },
                 N => { E =>  2, N => 2 },
                 O => { E =>  3, N => 2 },
                 P => { E =>  4, N => 2 },

                 Q => { E =>  0, N => 1 },
                 R => { E =>  1, N => 1 },
                 S => { E =>  2, N => 1 },
                 T => { E =>  3, N => 1 },
                 U => { E =>  4, N => 1 },

                 V => { E =>  0, N => 0 },
                 W => { E =>  1, N => 0 },
                 X => { E =>  2, N => 0 },
                 Y => { E =>  3, N => 0 },
                 Z => { E =>  4, N => 0 },
           );

use constant BIG_SQUARE => 500000;
use constant SQUARE     => 100000;

# Landranger sheet data
# These are the full GRs (as metres from Newlyn) of the SW corner of each sheet.
our %LR = (
1   => [ 429000 ,1179000 ] ,
2   => [ 433000 ,1156000 ] ,
3   => [ 417000 ,1144000 ] ,
4   => [ 420000 ,1107000 ] ,
5   => [ 340000 ,1020000 ] ,
6   => [ 321000 , 996000 ] ,
7   => [ 315000 , 970000 ] ,
8   => [ 117000 , 926000 ] ,
9   => [ 212000 , 940000 ] ,
10  => [ 252000 , 940000 ] ,
11  => [ 292000 , 929000 ] ,
12  => [ 300000 , 939000 ] ,
13  => [  95000 , 903000 ] ,
14  => [ 105000 , 886000 ] ,
15  => [ 196000 , 900000 ] ,
16  => [ 236000 , 900000 ] ,
17  => [ 276000 , 900000 ] ,
18  => [  69000 , 863000 ] ,
19  => [ 174000 , 860000 ] ,
20  => [ 214000 , 860000 ] ,
21  => [ 254000 , 860000 ] ,
22  => [  57000 , 823000 ] ,
23  => [ 113000 , 836000 ] ,
24  => [ 150000 , 830000 ] ,
25  => [ 190000 , 820000 ] ,
26  => [ 230000 , 820000 ] ,
27  => [ 270000 , 830000 ] ,
28  => [ 310000 , 833000 ] ,
29  => [ 345000 , 830000 ] ,
30  => [ 377000 , 830000 ] ,
31  => [  50000 , 783000 ] ,
32  => [ 130000 , 800000 ] ,
33  => [ 170000 , 790000 ] ,
34  => [ 210000 , 780000 ] ,
35  => [ 250000 , 790000 ] ,
36  => [ 285000 , 793000 ] ,
37  => [ 325000 , 793000 ] ,
38  => [ 365000 , 790000 ] ,
39  => [ 120000 , 770000 ] ,
40  => [ 160000 , 760000 ] ,
41  => [ 200000 , 750000 ] ,
42  => [ 240000 , 750000 ] ,
43  => [ 280000 , 760000 ] ,
44  => [ 320000 , 760000 ] ,
45  => [ 360000 , 760000 ] ,
46  => [  92000 , 733000 ] ,
47  => [ 120000 , 732000 ] ,
48  => [ 120000 , 710000 ] ,
49  => [ 160000 , 720000 ] ,
50  => [ 200000 , 710000 ] ,
51  => [ 240000 , 720000 ] ,
52  => [ 270000 , 720000 ] ,
53  => [ 294000 , 720000 ] ,
54  => [ 334000 , 720000 ] ,
55  => [ 164000 , 680000 ] ,
56  => [ 204000 , 682000 ] ,
57  => [ 244000 , 682000 ] ,
58  => [ 284000 , 690000 ] ,
59  => [ 324000 , 690000 ] ,
60  => [ 110000 , 640000 ] ,
61  => [ 131000 , 662000 ] ,
62  => [ 160000 , 640000 ] ,
63  => [ 200000 , 642000 ] ,
64  => [ 240000 , 645000 ] ,
65  => [ 280000 , 650000 ] ,
66  => [ 316000 , 650000 ] ,
67  => [ 356000 , 650000 ] ,
68  => [ 157000 , 600000 ] ,
69  => [ 175000 , 613000 ] ,
70  => [ 215000 , 605000 ] ,
71  => [ 255000 , 605000 ] ,
72  => [ 280000 , 620000 ] ,
73  => [ 320000 , 620000 ] ,
74  => [ 357000 , 620000 ] ,
75  => [ 390000 , 620000 ] ,
76  => [ 195000 , 570000 ] ,
77  => [ 235000 , 570000 ] ,
78  => [ 275000 , 580000 ] ,
79  => [ 315000 , 580000 ] ,
80  => [ 355000 , 580000 ] ,
81  => [ 395000 , 580000 ] ,
82  => [ 195000 , 530000 ] ,
83  => [ 235000 , 530000 ] ,
84  => [ 265000 , 540000 ] ,
85  => [ 305000 , 540000 ] ,
86  => [ 345000 , 540000 ] ,
87  => [ 367000 , 540000 ] ,
88  => [ 407000 , 540000 ] ,
89  => [ 290000 , 500000 ] ,
90  => [ 317000 , 500000 ] ,
91  => [ 357000 , 500000 ] ,
92  => [ 380000 , 500000 ] ,
93  => [ 420000 , 500000 ] ,
94  => [ 460000 , 485000 ] ,
95  => [ 213000 , 465000 ] ,
96  => [ 303000 , 460000 ] ,
97  => [ 326000 , 460000 ] ,
98  => [ 366000 , 460000 ] ,
99  => [ 406000 , 460000 ] ,
100 => [ 446000 , 460000 ] ,
101 => [ 486000 , 460000 ] ,
102 => [ 326000 , 420000 ] ,
103 => [ 360000 , 420000 ] ,
104 => [ 400000 , 420000 ] ,
105 => [ 440000 , 420000 ] ,
106 => [ 463000 , 420000 ] ,
107 => [ 500000 , 420000 ] ,
108 => [ 320000 , 380000 ] ,
109 => [ 360000 , 380000 ] ,
110 => [ 400000 , 380000 ] ,
111 => [ 430000 , 380000 ] ,
112 => [ 470000 , 385000 ] ,
113 => [ 510000 , 386000 ] ,
114 => [ 220000 , 360000 ] ,
115 => [ 240000 , 345000 ] ,
116 => [ 280000 , 345000 ] ,
117 => [ 320000 , 340000 ] ,
118 => [ 360000 , 340000 ] ,
119 => [ 400000 , 340000 ] ,
120 => [ 440000 , 350000 ] ,
121 => [ 478000 , 350000 ] ,
122 => [ 518000 , 350000 ] ,
123 => [ 210000 , 320000 ] ,
124 => [ 250000 , 305000 ] ,
125 => [ 280000 , 305000 ] ,
126 => [ 320000 , 300000 ] ,
127 => [ 360000 , 300000 ] ,
128 => [ 400000 , 308000 ] ,
129 => [ 440000 , 310000 ] ,
130 => [ 480000 , 310000 ] ,
131 => [ 520000 , 310000 ] ,
132 => [ 560000 , 310000 ] ,
133 => [ 600000 , 310000 ] ,
134 => [ 617000 , 290000 ] ,
135 => [ 250000 , 265000 ] ,
136 => [ 280000 , 265000 ] ,
137 => [ 320000 , 260000 ] ,
138 => [ 345000 , 260000 ] ,
139 => [ 385000 , 268000 ] ,
140 => [ 425000 , 270000 ] ,
141 => [ 465000 , 270000 ] ,
142 => [ 504000 , 274000 ] ,
143 => [ 537000 , 274000 ] ,
144 => [ 577000 , 270000 ] ,
145 => [ 200000 , 220000 ] ,
146 => [ 240000 , 225000 ] ,
147 => [ 270000 , 240000 ] ,
148 => [ 310000 , 240000 ] ,
149 => [ 333000 , 228000 ] ,
150 => [ 373000 , 228000 ] ,
151 => [ 413000 , 230000 ] ,
152 => [ 453000 , 230000 ] ,
153 => [ 493000 , 234000 ] ,
154 => [ 533000 , 234000 ] ,
155 => [ 573000 , 234000 ] ,
156 => [ 613000 , 250000 ] ,
157 => [ 165000 , 201000 ] ,
158 => [ 189000 , 190000 ] ,
159 => [ 229000 , 185000 ] ,
160 => [ 269000 , 205000 ] ,
161 => [ 309000 , 205000 ] ,
162 => [ 349000 , 188000 ] ,
163 => [ 389000 , 190000 ] ,
164 => [ 429000 , 190000 ] ,
165 => [ 460000 , 195000 ] ,
166 => [ 500000 , 194000 ] ,
167 => [ 540000 , 194000 ] ,
168 => [ 580000 , 194000 ] ,
169 => [ 607000 , 210000 ] ,
170 => [ 269000 , 165000 ] ,
171 => [ 309000 , 165000 ] ,
172 => [ 340000 , 155000 ] ,
173 => [ 380000 , 155000 ] ,
174 => [ 420000 , 155000 ] ,
175 => [ 460000 , 155000 ] ,
176 => [ 495000 , 160000 ] ,
177 => [ 530000 , 160000 ] ,
178 => [ 565000 , 155000 ] ,
179 => [ 603000 , 133000 ] ,
180 => [ 240000 , 112000 ] ,
181 => [ 280000 , 112000 ] ,
182 => [ 320000 , 130000 ] ,
183 => [ 349000 , 115000 ] ,
184 => [ 389000 , 115000 ] ,
185 => [ 426000 , 116000 ] ,
186 => [ 465000 , 125000 ] ,
187 => [ 505000 , 125000 ] ,
188 => [ 545000 , 125000 ] ,
189 => [ 585000 , 115000 ] ,
190 => [ 207000 ,  87000 ] ,
191 => [ 247000 ,  72000 ] ,
192 => [ 287000 ,  72000 ] ,
193 => [ 310000 ,  90000 ] ,
194 => [ 349000 ,  75000 ] ,
195 => [ 389000 ,  75000 ] ,
196 => [ 429000 ,  76000 ] ,
197 => [ 469000 ,  90000 ] ,
198 => [ 509000 ,  97000 ] ,
199 => [ 549000 ,  94000 ] ,
200 => [ 175000 ,  50000 ] ,
201 => [ 215000 ,  47000 ] ,
202 => [ 255000 ,  32000 ] ,
203 => [ 132000 ,  11000 ] ,
204 => [ 172000 ,  14000 ] ,
);


=head1 FUNCTIONS

The following functions can be exported from the C<Geo::Coordinates::OSGB>
module:

    ll2grid
    grid2ll

    format_grid_trad
    format_grid_GPS
    format_grid_landranger

    parse_trad_grid
    parse_GPS_grid
    parse_landranger_grid

    map2ll
    map2grid

    set_ellipsoid
    set_projection

None is exported by default.

=cut

@EXPORT = qw();
@EXPORT_OK = qw(
    ll2grid
    grid2ll
    set_ellipsoid
    set_projection
    format_grid_trad
    format_grid_GPS
    format_grid_landranger
    parse_trad_grid
    parse_GPS_grid
    parse_landranger_grid
    map2ll
    map2grid
);

=pod

This code is fine tuned to the British national grid system.  You can use it
elsewhere but you will need to adapt it.  This is explained in some detail in
the L<Examples> section below.

The default values for ellipsoid and projection are suitable for mapping
between GPS longitude and latitude data and the UK National Grid.

=cut

# set defaults for Britain

set_ellipsoid(6377563.396,6356256.91);
set_projection(49, -2, 400000, -100000, 0.9996012717);

=over 4

=item ll2grid(lat,lon)

When called in a void context, or with no arguments C<ll2grid> does nothing.
When called in a list context, C<ll2grid> returns two numbers that represent
the easting and the northing corresponding to the latitude and longitude
supplied.

The parameters can be supplied as real numbers representing degrees or in ISO
`degrees, minutes, and seconds' form.  That is 'C<sdd[mm[ss]]>' for I<lat>
and 'C<sddd[mm[ss]]>' for I<long>.  The magnitude of the arguments is used to
infer which form is being used.  Note the leading C<s> is the sign +
(North,East) or - (South,West).  If you use the ISO format be sure to 'quote'
the arguments, otherwise Perl will think that they are numbers, and strip
leading 0s and + signs which may give you unexpected results.  For example:

    my ($e,$n) = ll2grid('+5120','-00025');

If you have trouble remembering the order of the arguments, note that
latitude comes before longitude in the alphabet too.

The easting and northing will be returned as a whole number of metres from
the point of origin defined by the projection you have set.  In the case of
the Britain this is a point a little way to the south-west of the Scilly
Isles.  If you want the grid presented in a more traditional format you
should pass the results to one of the grid formatting routines, which are
described below.

If you call C<ll2grid> in a scalar context, it will automatically call C<format_grid_trad>.
For example:

    my $gridref = ll2grid('+5120','-00025');

In this case the string returned represents the `full national
grid reference' with two letters and two sets of three numbers, like this
`TQ 102 606'.  If you want to remove the spaces, just apply C<s/\s//g> to it.

To force it to call one of the other grid formatting routines, try one of these:

    $gridref = ll2grid('+5120','-00025','Trad');
    $gridref = ll2grid('+5120','-00025','GPS');
    $gridref = ll2grid('+5120','-00025','Landranger');

=cut

sub ll2grid {
    return unless defined wantarray;
    return unless @_ > 1;

    my ($lat, $lon, $form, undef) = (@_, 'TRAD');

    if    ($lat =~ /^([+-])(\d\d)(\d\d)(\d\d)$/ ) { $lat = $1.($2+$3/60+$4/3600) }
    elsif ($lat =~ /^([+-])(\d\d)(\d\d)$/ )       { $lat = $1.($2+$3/60) }
    if    ($lon =~ /^([+-])(\d\d\d)(\d\d)(\d\d)$/){ $lon = $1.($2+$3/60+$4/3600) }
    elsif ($lon =~ /^([+-])(\d\d\d)(\d\d)$/ )     { $lon = $1.($2+$3/60) }

    my $phi = RAD * $lat;
    my $lam = RAD * $lon;

    my $sp2  = sin($phi)**2;
    my $nu   = $a * $F0 * (1 - $e2 * $sp2 ) ** -0.5;
    my $rho  = $a * $F0 * (1 - $e2) * (1 - $e2 * $sp2 ) ** -1.5;
    my $eta2 = $nu/$rho - 1;

    my $M = _compute_M($phi);

    my $cp = cos($phi); my $sp = sin($phi); my $tp = tan($phi);
    my $tp2 = $tp*$tp ; my $tp4 = $tp2*$tp2 ;

    my $I    = $M+$N0;
    my $II   = $nu/2  * $sp * $cp;
    my $III  = $nu/24 * $sp * $cp**3 * (5-$tp2+9*$eta2);
    my $IIIA = $nu/720* $sp * $cp**5 *(61-58*$tp2+$tp4);

    my $IV   = $nu*$cp;
    my $V    = $nu/6   * $cp**3 * ($nu/$rho-$tp2);
    my $VI   = $nu/120 * $cp**5 * (5-18*$tp2+$tp4+14*$eta2-58*$tp2*$eta2);

    my $l = $lam-$lam0;
    my $north = $I  + $II*$l**2 + $III*$l**4 + $IIIA*$l**6;
    my $east  = $E0 + $IV*$l    +   $V*$l**3 +   $VI*$l**5;

    $east  = int($east+0.2);  # round to nearest metre, mainly rounding down
    $north = int($north+0.2);

    return ($east,$north) if wantarray;
    return format_grid_GPS($east,$north)        if $form =~ /gps/io;
    return format_grid_landranger($east,$north) if $form =~ /landranger/io;
    return format_grid_trad($east,$north);

}

=item format_grid_trad(e,n)

Formats an (easting, northing) pair into traditional `full national grid
reference' with two letters and two sets of three numbers, like this `TQ 102
606'.  If you want to remove the spaces, just apply C<s/\s//g> to it.
If you want the individual components call it in a list context.

=cut

sub format_grid_trad {
    use integer;
    my ($sq, $e, $n) = format_grid_GPS(@_);
    ($e,$n) = ($e/100,$n/100);
    return ($sq, $e, $n) if wantarray;
    return sprintf "%s %03d %03d", $sq, $e, $n;
}

=item format_grid_GPS(e,n)

Users who have bought a GPS receiver may initially have been puzzled by the
unfamiliar format used to present coordinates in the British national grid format.
On my Garmin Legend C it shows this sort of thing in the display.

    TQ 23918
   bng 00972

and in the track logs the references look like this

    TQ 23918 00972

These are just the same as the references described on the OS sheets, except
that the units are metres rather than hectometres, so you get five digits in
each of the easting and northings instead of three.  C<format_grid_GPS>
returns a string representing this format, or a list of the square, the
truncated easting, and the truncated northing if you call it in a list
context.

Note that, at least until WAAS is working in Europe, the results from your GPS are
unlikely to be more accurate that plus or minus 10m even with perfect reception.

=cut


sub format_grid_GPS {
    use integer;
    my $e = shift;
    my $n = shift;
    my $sq = sprintf "%s%s", _letter(2+$e/BIG_SQUARE,1+$n/BIG_SQUARE),
                             _letter(( $e % BIG_SQUARE )/SQUARE, ( $n % BIG_SQUARE )/SQUARE );
    ($e,$n) = ($e % SQUARE, $n % SQUARE);
    return ($sq, $e, $n) if wantarray;
    return sprintf "%s %05d %05d", $sq, $e, $n;
}



=item format_grid_landranger(e,n)

This does the same as C<format_grid_trad>, but it appends the number of the
relevant OS Landranger 1:50,000 scale map to the traditional grid reference.
Note that there may be several or no sheets returned.  This is because many
(most) of the Landranger sheets overlap, and many other valid grid references are
not on any of the sheets (because they are in the sea or a remote island.
This module does not cope with the detached insets on some sheets (yet).

In a list context you will get back a list like this: (square, easting, northing,
sheet) or (square, easting, northing, sheet1, sheet2) etc.  There are a few places
where three sheets overlap, and one corner of Herefordshire which appears
on four maps (sheets 137, 138, 148, and 149).  If the GR is not on any sheet,
then the list of sheets will be empty.

In a scalar context you will get back the same information in a helpful
string form like this "NN 241 738 on OS Sheet 44".  Note that the easting and
northing will have been truncated to the normal truncated `hectometre' three
digit form.

=cut

sub format_grid_landranger {
    use integer;
    my ($e,$n) = @_;
    my @sheets = ();
    for my $sheet (1..204) {
        my $de = $e-$LR{$sheet}->[0];
        my $dn = $n-$LR{$sheet}->[1];
        push @sheets, $sheet if $de>=0 && $de < 40000
                             && $dn>=0 && $dn < 40000;
    }
    my $sq;
    ($sq, $e, $n) = format_grid_trad($e,$n);

    return ($sq, $e, $n, @sheets) if wantarray;

    return sprintf("%s %03d %03d is not on any OS Sheet", $sq, $e, $n) unless @sheets;
    return sprintf("%s %03d %03d on OS Sheet %d"        , $sq, $e, $n, $sheets[0]) if 1==@sheets;
    return sprintf("%s %03d %03d on OS Sheets %d and %d", $sq, $e, $n, @sheets)    if 2==@sheets;
    return sprintf("%s %03d %03d on OS Sheets %s", $sq, $e, $n, join(', ', @sheets[0..($#sheets-1)], "and $sheets[-1]"));

}

sub _letter {
    my $x = shift;
    my $y = shift;
    die "Argument out of range in _letter\n"
        unless defined $x && $x=~/^\d+$/ && $x>=0 && $x<5
            && defined $y && $y=~/^\d+$/ && $y>=0 && $y<5;

    return $Grid[$y][$x];
}

=item parse_trad_grid(grid_ref)

Turns a traditional grid reference into a full easting and northing pair in
metres from the point of origin.  The I<grid_ref> can be a string like
`TQ203604' or `SW 452 004', or a list like this C<('TV', '435904')> or a list
like this C<('NN', '345', '208')>.

=cut

sub parse_trad_grid {
    my ($letters, $e, $n);
    if    ( @_ == 1 && $_[0] =~ $GR_Pattern ) {
        ($letters, $e, $n) = ($1,$2,$3)
    }
    elsif ( @_ == 2 && $_[0] =~ $GSq_Pattern && $_[1] =~ /^(\d{3})(\d{3})$/ ) {
        $letters = $_[0]; ($e, $n) = ($1,$2)
    }
    elsif ( @_ == 3 && $_[0] =~ $GSq_Pattern && $_[1] =~ /^\d{3}$/ && $_[2] =~ /^\d{3}$/ ) {
        ($letters, $e, $n) = @_
    }
    else { confess "Cannot parse @_ as a traditional grid reference\n"; }

    return _parse_grid($letters, $e*100, $n*100)
}


=item parse_GPS_grid(grid_ref)

Does the same as C<parse_trad_grid> but is looking for five digit numbers
like `SW 45202 00421', or a list like this C<('NN', '34592', '20804')>.

=cut

sub parse_GPS_grid {
    my ($letters, $e, $n);
    if    ( @_ == 1 && $_[0] =~ $Long_GR_Pattern ) {
        ($letters, $e, $n) = ($1,$2,$3)
    }
    elsif ( @_ == 2 && $_[0] =~ $GSq_Pattern && $_[1] =~ /^(\d{5})(\d{5})$/ ) {
        $letters = $_[0]; ($e, $n) = ($1,$2)
    }
    elsif ( @_ == 3 && $_[0] =~ $GSq_Pattern && $_[1] =~ /^\d{5}$/ && $_[2] =~ /^\d{5}$/ ) {
        ($letters, $e, $n) = @_
    }
    else { confess "Cannot parse @_ as a GPS-style grid reference\n"; }

    return _parse_grid($letters, $e, $n)
}

sub _parse_grid {
    return unless defined wantarray;

    my ($letters, $e, $n) = @_;

    my $c = substr($letters,0,1);
    $e += $Big_off{$c}->{E}*BIG_SQUARE;
    $n += $Big_off{$c}->{N}*BIG_SQUARE;

    my $d = substr($letters,1,1);
    $e += $Small_off{$d}->{E}*SQUARE;
    $n += $Small_off{$d}->{N}*SQUARE;

    return ($e,$n);
}

=item parse_landranger_grid($sheet, $e, $n)

This converts an OS Landranger sheet number and a local grid reference
into a full easting and northing pair in metres from the point of origin.

The OS Landranger sheet number should be between 1 and 204 inclusive (but
I may extend this when I support insets).  You can supply (e,n) as 3-digit
hectometre numbers or 5-digit metre numbers.  In either case if you supply
any leading zeros you should 'quote' the numbers to stop Perl thinking that
they are octal constants.

This module will croak at you if you give it an undefined sheet number, or
if the grid reference that you supply does not exist on the sheet.

In order to get just the coordinates of the SW corner of the sheet, just call
it with the sheet number.

=cut

sub _get_en {
    my $e = shift;
    my $n = shift;
    if ( $e =~ /^(\d{3})(\d{3})$/ && not defined $n  ) { return ($1*100, $2*100) }
    if ( $e =~ /^\d{3}$/          && $n =~ /^\d{3}$/ ) { return ($e*100, $n*100) }
    if ( $e =~ /^\d{4}$/          && $n =~ /^\d{4}$/ ) { return ($e*10,  $n*10 ) }
    if ( $e =~ /^\d{5}$/          && $n =~ /^\d{5}$/ ) { return ($e*1,   $n*1  ) }
    confess "I was expecting a grid reference here, not this: @_\n";
}


sub parse_landranger_grid {

    return unless defined wantarray;

    my $sheet = shift;

    confess "$sheet is not one of the OS Sheet numbers I know about\n" unless defined $LR{$sheet};

    return @{$LR{$sheet}} unless @_;

    use integer;

    my ($e,$n) = &_get_en; # convert grid refs to metres

    my ($lle,$lln) = @{$LR{$sheet}};

    # offset from start, corrected if we are in the next 100km sq
    my $offset = $e - $lle%100_000 ; $offset += 100_000 if $offset < 0;
    confess "Easting given is not on Sheet $sheet\n" unless $offset <= 40_000 && $offset >= 0;
    $e = $lle + $offset;

    $offset = $n - $lln%100_000 ; $offset += 100_000 if $offset < 0;
    confess "Northing given is not on Sheet $sheet\n" unless $offset <= 40_000 && $offset >= 0;
    $n = $lln + $offset;

    return ($e, $n);

}

=item grid2ll(e,n) or grid2ll(grid_ref)

When called in list context C<grid2ll> returns a pair of numbers
representing longitude and latitude coordinates, as real numbers.  Following
convention, positive numbers are North and East, negative numbers are South
and West.  The fractional parts of the results represent fractions of degrees.

When called in scalar context it returns a string in ISO longitude and latitude
form, such as '+5025-00403' with the result rounded to the nearest minute (the
formulae are not much more accurate than this).  In a void context it does
nothing.

The arguments can be either an (easting, northing) pair of integers
representing the absolute grid reference in metres from the point of origin,
or a single string that represents a full grid reference in traditional
hectometre form, such as 'NH868943' or 'NH 868 943'.

To force it to read GPS format grid references you can try C<grid2ll(grid_ref,'GPS')>.
This should then recognize strings like 'NH 87612 27623'.

=cut


sub grid2ll {

    return unless defined wantarray;

    my ($E,$N) = @_;
    ($E,$N) = parse_trad_grid($E) unless defined $N;
    ($E,$N) = parse_trad_grid($E) if $N =~ /TRAD/oi;
    ($E,$N) = parse_GPS_grid($E) if $N =~ /GPS/oi;

    my $dN = $N-$N0;

    my $phi = $phi0 + $dN/($a*$F0);
    my $M = _compute_M($phi);

    while ($dN-$M >= 0.001) {
       $phi = $phi + ($dN-$M)/($a*$F0);
       $M = _compute_M($phi);
    }

    my $sp2  = sin($phi)**2;
    my $nu   = $a * $F0 * (1 - $e2 * $sp2 ) ** -0.5;
    my $rho  = $a * $F0 * (1 - $e2) * (1 - $e2 * $sp2 ) ** -1.5;
    my $eta2 = $nu/$rho - 1;

    my $tp = tan($phi); my $tp2 = $tp*$tp ; my $tp4 = $tp2*$tp2 ;

    my $VII  = $tp /   (2*$rho*$nu);
    my $VIII = $tp /  (24*$rho*$nu**3) *  (5 +  3*$tp2 + $eta2 - 9*$tp2*$eta2);
    my $IX   = $tp / (720*$rho*$nu**5) * (61 + 90*$tp2 + 45*$tp4);

    my $sp = sec($phi); my $tp6 = $tp4*$tp2 ;

    my $X    = $sp/$nu;
    my $XI   = $sp/(   6*$nu**3)*($nu/$rho + 2*$tp2);
    my $XII  = $sp/( 120*$nu**5)*(      5 + 28*$tp2 +   24*$tp4);
    my $XIIA = $sp/(5040*$nu**7)*(    61 + 662*$tp2 + 1320*$tp4 + 720*$tp6);

    my $e = $E-$E0;
       $phi = $phi  - $VII*$e**2 + $VIII*$e**4 -  $IX*$e**6;
    my $lam = $lam0 +   $X*$e    -   $XI*$e**3 + $XII*$e**5 - $XIIA*$e**7;

    return ($phi * DAR, $lam * DAR) if wantarray;

    return _iso_form_LL($phi * DAR, $lam * DAR);
}


=item map2grid()

Shorthand for C<format_grid_trad(parse_landranger_grid())>.

=item map2ll()

Shorthand for C<grid2ll(parse_landranger_grid())>.

=cut


sub map2grid {
    my $gr = format_grid_trad(&parse_landranger_grid);
    $gr =~ s/\s//g;
    return $gr
}

sub map2ll { return grid2ll(&parse_landranger_grid) }

=item set_ellipsoid(a,b)

Defines the ellipsoid used to interpret the longitude and latitude values.
The arguments I<a> and I<b> are the lengths (in metres) of the semi-major
axes of the ellipsoid used to represent the earth's surface.  Values used
in the UK are given in Annex A of the paper referenced below in L<"Theory">.

You should call set_ellipsoid() before doing anything else, unless you are
converting data for the UK National Grid.
It will default to the values for the `Airy 1830' ellipsoid that is used
with the UK National Grid.

=cut


sub set_ellipsoid {
    $a = shift;
    $b = shift;
    $e2 = ($a**2-$b**2)/$a**2;
    $n = ($a-$b)/($a+$b);
}


=item set_projection(lat,long,E,N,F)

Defines the projection used to interpret the grid references.
The projection is a `Transverse Mercator projection'.  The first two
arguments define the longitude and latitude of the true origin of the
grid to be used, and the second two are the grid coordinates of this
position.  Note the order that they are given.  Latitude then longitude,
followed by easting, then northing.  This may seem illogical but it does
conform to normal practice.

The fifth argument is the scale factor on the central meridian
of the grid area.  See the paper referenced below in L<"Theory"> for
a table of values suitable for the UK and a full explanation of the
theory.

You don't need to call this if you just want to use the normal OS grid.

=back

=cut


sub set_projection {
    $phi0 = RAD * shift;
    $lam0 = RAD * shift;
    $E0   = shift;
    $N0   = shift;
    $F0   = shift;
}


sub _iso_form_LL { sprintf "%+05d%+06d", _dm($_[0]), _dm($_[1]) }

sub _dm {
    my $r = shift;
    return (0,0) unless $r;
    my $sign = $r/abs($r); $r=abs($r);
    my $deg = int($r);
    my $min = int(0.5+60*($r-$deg));
    return $sign*($deg*100+$min);  # beware that -1 * 0 = +0 in Perl!
}

sub _compute_M {
    my $phi = shift;
    return  $b * $F0 * ((1 + $n * (1 + 5/4*$n*(1 + $n)))*($phi-$phi0)
         - (3*$n * ( 1 + $n * (1 + 7/8*$n))*sin($phi-$phi0)*cos($phi+$phi0))
         + (15/8*$n * ($n*(1+$n)))*sin(2*($phi-$phi0))*cos(2*($phi+$phi0))
         - 35/24*$n**3*sin(3*($phi-$phi0))*cos(3*($phi+$phi0)));
}


1;
__END__

=head1 THEORY

The algorithms and theory for these conversion routines are all from
I<A Guide to Coordinate Systems in Great Britain>
published by the Ordnance Survey, April 1999 and available at
http://www.gps.gov.uk/info.asp

You may also like to read some of the other introductory material there.
Should you be hoping to adapt this code to your own custom Mercator
projection, you will find the paper called I<Surveying with the
National GPS Network>, especially useful.

The true point of origin of the British Grid is the point 49N 2W (near the Channel
Islands).  If you look at the appropriate OS maps you will notice that the 2W
meridian is parallel to all the vertical grid lines.  To avoid negative numbers
in grid references the (0,0) point on the grid is offset 400 km west and 100 km north
of this point.  This is called the `false point of origin' and all grid references
are measured in metres from this point.  The easting is always given before the
northing.

For everyday use, the OS suggest that grid references are given in units of
100m (hectometres), and that the country should divided into a series of 100km
squares.  Within each of these large squares, we need only be concerned with the last
three digits of the full national grid reference.  If we combine the easting
and northing we get the familiar traditional six figure grid reference.
Each of these grid references is repeated in each of the large 100km squares
but for local use, this does not usually matter.  Where it does matter, the OS suggest
that the six figure reference is prefixed with the identifier of the large grid
square to give a `full national grid reference'.  This system is described in
the notes of in the corner of every Landranger 1:50,000 scale map.

Modern GPS receivers can all display coordinates in the OS grid system.  You
just need to set the display units to be `British National Grid' or whatever
similar name is used on your unit.  Most units display the coordinates as two
groups of five digits and a grid square identifier.  The units are metres within
the grid square (although beware that the GPS fix is unlikely to be accurate down
to the last metre).

Each of the large squares is identified in pair of letters:  TQ, SU, ND, etc.
The grid of the big squares actually used is something like this:

                               HP
                               HU
                            HY
                   NA NB NC ND
                   NF NG NH NJ NK
                   NL NM NN NO NP
                      NR NS NT NU
                      NW NX NY NZ
                         SC SD SE TA
                         SH SJ SK TF TG
                      SM SN SO SP TL TM
                      SR SS ST SU TQ TR
                   SV SW SX SY SZ TV

with SW covering most of Cornwall, TQ London, and HU the Shetlands.  Clearly
it could extend much further in each direction.  Note that it has the neat
feature that N and S are directly above each other, so that most Sx squares
are in the south and most Nx squares are in the north.

=head1 BUGS

The conversions are only approximate.   So after

  ($a1,$b1) = grid2ll(ll2grid($a,$b));

neither C<$a==$a1> nor C<$b==$b1>. However C<abs($a-$a1)> and C<abs($b-$b1)>
should be less than C<0.00001> which will give you accuracy to within a few
centimetres.  Note that the error increases the further away you are from the
reference point of your grid system.

When using ll2grid in scalar mode to get a "TQ999999" type of grid reference
OSGB tends to round to the *nearest* 100m grid intersection rather than to
the one to the left and below, this may cause your grid references to be to off
by one in the last digit, but probably gives more consistent results overall.

The conversion of lat/long or grid to map sheets does not take account of inset areas
on the sheets.  So if you use C<ll2map()> with the coordinates of the Scilly Isles,
it will tell you that they are not on any Landranger sheet, whereas in fact the Scilly Isles
are on an inset in the SW corner of Sheet 203.  There is nothing in the design that
prevents me adding the insets, they just need to be added as extra sheets with names
like "Sheet 2003 Inset 1" with their own reference points and special sheet sizes.
Collecting the data is another matter.

Not enough testing has been done.

=head1 EXAMPLES

This module is intended for use in the UK with the Ordnance Survey's National
Grid, however the conversion routines are written in an entirely generic way
that you can adapt to provide you with a Transverse Mercator Projection for
any location on the the globe (or any other approximately spherical planet
for that matter).  What you need to do is to define the size of an ellipsoid
that closely approximates your planet, and then define a suitable projection
on top of it.

For the non-mathematicians among us, an ellipsoid is a sort of squashed ball
that approximately represents the shape of the Earth.  Using an approximation
greatly simplifies working out latitudes and longitudes.  Over the years
cartographers have used a variety of different approximations that suit their
local conditions and the tools they have at their disposal.  You need to
choose an appropriate approximation for your work.  For example coordinates
given by a GPS device will be based on one approximation, while coordinates
you read from an 18th century chart might use another.  You can find the
numbers that define frequently used historical and modern approximations in a
table such as the one given in the OS paper referenced above.

Choosing the exact ellipsoid model it a matter of some theoretical
discussion, but for most practical purposes on earth the default values used
by the UK ordnance survey will probably work for your data.  However you may
get better results setting the ellipsoid to the standard WGS84 shape, which is
what the GPS satellite network uses and is appropriate for working with
GPS-derived longitude and latitude coordinates.

To use WGS84, add the "set_ellipsoid" function to the list that you import
from C<Geo::Coordinates::OSGB>, and call it like this in your script:

   set_ellipsoid(6378137.0,6356752.3141)

Next you have to define the projection that defines your local grid and the
reference points for the grid.  This can be done with the "set_projection"
function, which you will also need to import.  To get the parameters for
"set_projection" you need to start by choosing an point in the middle of your
area and finding the longitude and latitude.  This is known as the True
Origin of the Projection.

You then need to know (or invent) the grid reference for this point.  This is
entirely arbitrary unless you are trying to conform to someone else's grid.
The simplest thing is to set the reference to 0,0.  However you will then get
negative coordinates for points south and west of your chosen centre point.
It is more convenient to choose grid coordinates that make all of your
results positive.  To do this the eastings and northings should be a point
just to the south of the southerly limit of your survey and just to the west
of the westerly limit.  This point will have grid coordinates (0, 0), and all
your other grid coordinates will be positive.  This point is known as the
False Origin of the Projection.

So assuming your reference point is 150 degrees west and 47 degrees north,
and you want this point to be grid reference 100000 east, 200000 north (in
metres) then you should set

  set_projection(47.0,-150.0,100000,200000,1)

The fifth parameter is the scale factor on the central meridian of the
projection:  for small areas just set this equal to 1. Making this parameter
slightly less than 1 can reduce the scale distortion on the far east and west
sides of the grid.

=head1 AUTHOR

Toby Thurston --- 16 May 2005

web: http://www.wildfire.dircon.co.uk

=head1 SEE ALSO

The UK Ordnance Survey's theory paper referenced above in L<"Theory">.

See L<Geo::Coordinates::Convert> for a general approach (not based on the above
paper).

See L<Geo::Coordinates::Lambert> for a French approach.

=cut
