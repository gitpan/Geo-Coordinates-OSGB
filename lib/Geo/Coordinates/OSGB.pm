package Geo::Coordinates::OSGB;
require Exporter;
use strict;
use warnings;

our @ISA = qw(Exporter);
our $VERSION = '2.01';
our @EXPORT = qw();
our @EXPORT_OK = qw(
    ll_to_grid
    grid_to_ll
    parse_ll
    format_ll_dms
    format_ll_ISO
    parse_grid
    parse_trad_grid
    parse_GPS_grid
    parse_landranger_grid
    format_grid_trad
    format_grid_GPS
    format_grid_landranger
    shift_ll_into_WGS84
    shift_ll_from_WGS84
);

use Math::Trig qw(tan sec);
use Carp;

use constant PI  => 4 * atan2 1, 1;
use constant RAD => PI / 180;
use constant DAR => 180 / PI;

use constant WGS84_MAJOR_AXIS => 6378137.000;
use constant WGS84_FLATTENING => 1 / 298.257223563;

# set defaults for Britain
our %ellipsoid_shapes = (
    WGS84  => [ 6378137.0000, 6356752.31425 ],
    ETRS89 => [ 6378137.0000, 6356752.31425 ],
    ETRN89 => [ 6378137.0000, 6356752.31425 ],
    GRS80  => [ 6378137.0000, 6356752.31425 ],
    OSGB36 => [ 6377563.396,  6356256.910  ],
);
# yes the first four are all synonyms

# constants for OSGB mercator projection
use constant LAM0 => RAD * -2;  # lon of grid origin
use constant PHI0 => RAD * 49;  # lat of grid origin
use constant E0   =>  400000;   # Easting for origin
use constant N0   => -100000;   # Northing for origin
use constant F0   => 0.9996012717; # Convergence factor

sub ll_to_grid {
    return unless defined wantarray;

    if (@_ < 2) {
        croak "Bad call to ll_to_grid (less than two arguments supplied)\n";
    }

    my $lat   = shift;
    my $lon   = shift;
    my $shape = shift || 'OSGB36';

    if ( !defined $ellipsoid_shapes{$shape} ) {
        croak "Bad call to ll_to_grid (unknown shape: $shape)\n";
    }

    my ($a,$b) = @{$ellipsoid_shapes{$shape}};

    my $e2 = ($a**2-$b**2)/$a**2;
    my $n = ($a-$b)/($a+$b);

    my $phi = RAD * $lat;
    my $lam = RAD * $lon;

    my $sp2  = sin($phi)**2;
    my $nu   = $a * F0 * (1 - $e2 * $sp2 ) ** -0.5;
    my $rho  = $a * F0 * (1 - $e2) * (1 - $e2 * $sp2 ) ** -1.5;
    my $eta2 = $nu/$rho - 1;

    my $M = _compute_M($phi, $b, $n);

    my $cp = cos($phi); my $sp = sin($phi); my $tp = tan($phi);
    my $tp2 = $tp*$tp ; my $tp4 = $tp2*$tp2 ;

    my $I    = $M + N0;
    my $II   = $nu/2  * $sp * $cp;
    my $III  = $nu/24 * $sp * $cp**3 * (5-$tp2+9*$eta2);
    my $IIIA = $nu/720* $sp * $cp**5 *(61-58*$tp2+$tp4);

    my $IV   = $nu*$cp;
    my $V    = $nu/6   * $cp**3 * ($nu/$rho-$tp2);
    my $VI   = $nu/120 * $cp**5 * (5-18*$tp2+$tp4+14*$eta2-58*$tp2*$eta2);

    my $l = $lam - LAM0;
    my $north = $I  + $II*$l**2 + $III*$l**4 + $IIIA*$l**6;
    my $east  = E0 + $IV*$l    +   $V*$l**3 +   $VI*$l**5;

    # round to 3dp (mm)
    ($east, $north) = map { sprintf "%.3f", $_ } ($east, $north);

    return ($east,$north) if wantarray;
    return format_grid_trad($east, $north);
}

sub grid_to_ll {

    return unless defined wantarray;

    if (@_ < 2) {
        croak "Bad call to grid_to_ll (less than two arguments supplied)\n";
    }

    my $E     = shift;
    my $N     = shift;
    my $shape = shift || 'OSGB36';

    if ( !defined $ellipsoid_shapes{$shape} ) {
        croak "Bad call to grid_to_ll (unknown shape: $shape)\n";
    }
    my ($a,$b) = @{$ellipsoid_shapes{$shape}};

    my $e2 = ($a**2-$b**2)/$a**2;
    my $n = ($a-$b)/($a+$b);

    my $dN = $N - N0;

    my ($phi, $lam);
    $phi = PHI0 + $dN/($a * F0);

    my $M = _compute_M($phi, $b, $n);
    while ($dN-$M >= 0.001) {
       $phi = $phi + ($dN-$M)/($a * F0);
       $M = _compute_M($phi, $b, $n);
    }

    my $sp2  = sin($phi)**2;
    my $nu   = $a * F0 *             (1 - $e2 * $sp2 ) ** -0.5;
    my $rho  = $a * F0 * (1 - $e2) * (1 - $e2 * $sp2 ) ** -1.5;
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

    my $e = $E - E0;

    $phi = $phi         - $VII*$e**2 + $VIII*$e**4 -   $IX*$e**6;
    $lam = LAM0 + $X*$e -  $XI*$e**3 +  $XII*$e**5 - $XIIA*$e**7;

    $phi *= DAR;
    $lam *= DAR;

    return ($phi, $lam) if wantarray;
    return format_ll_ISO($phi,$lam);
}

sub _compute_M {
    my ($phi, $b, $n) = @_;
    my $p_plus  = $phi + PHI0;
    my $p_minus = $phi - PHI0;
    return $b * F0 * (
           (1 + $n * (1 + 5/4*$n*(1 + $n)))*$p_minus
         - 3*$n*(1+$n*(1+7/8*$n))  * sin(  $p_minus) * cos(  $p_plus)
         + (15/8*$n * ($n*(1+$n))) * sin(2*$p_minus) * cos(2*$p_plus)
         - 35/24*$n**3             * sin(3*$p_minus) * cos(3*$p_plus)
           );
}


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

sub format_grid_trad {
    use integer;
    my ($sq, $e, $n) = format_grid_GPS(@_);
    ($e,$n) = ($e/100,$n/100);
    return ($sq, $e, $n) if wantarray;
    return sprintf "%s %03d %03d", $sq, $e, $n;
}

sub format_grid_GPS {
    my $e = shift;
    my $n = shift;

    croak "Easting must not be negative\n" if $e<0;
    croak "Northing must not be negative\n" if $n<0;

    # round to nearest metre
    ($e,$n) = map { $_+0.5 } ($e, $n);
    my $sq;

    {
        use integer;
        $sq = sprintf "%s%s", _letter( 2 + $e/BIG_SQUARE         , 1+$n/BIG_SQUARE        ),
                              _letter(($e % BIG_SQUARE ) / SQUARE, ( $n % BIG_SQUARE )/SQUARE );

        ($e,$n) = map { $_ % SQUARE } ($e, $n);
    }

    return ($sq, $e, $n) if wantarray;
    return sprintf "%s %05d %05d", $sq, $e, $n;
}

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

our $GSq_Pattern     = qr /[GHJMNORST][A-Z]/i;
our $LR_Pattern      = qr /^(\d{1,3})\D+(\d{3})\D?(\d{3})$/;
our $GR_Pattern      = qr /^($GSq_Pattern)\s?(\d{3})\D?(\d{3})$/;
our $Long_GR_Pattern = qr /^($GSq_Pattern)\s?(\d{5})\D?(\d{5})$/;

sub parse_grid {
    my $s = shift;
    return parse_trad_grid($s) if $s =~ $GR_Pattern;
    return parse_GPS_grid($s)  if $s =~ $Long_GR_Pattern;
    return parse_landranger_grid($1, $2, $3) if $s =~ $LR_Pattern;
    confess "$s <-- this does not match my grid ref patterns\n";
    return
}

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
    $letters = uc($letters);

    my $c = substr($letters,0,1);
    $e += $Big_off{$c}->{E}*BIG_SQUARE;
    $n += $Big_off{$c}->{N}*BIG_SQUARE;

    my $d = substr($letters,1,1);
    $e += $Small_off{$d}->{E}*SQUARE;
    $n += $Small_off{$d}->{N}*SQUARE;

    return ($e,$n);
}


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

sub map_to_grid {
    return format_grid_trad(parse_landranger_grid(@_));
}

sub parse_ll {
    my $lat = shift;
    my $lon = shift;

    if    ($lat =~ /^([+-])(\d\d)(\d\d)(\d\d)$/ ) { $lat = $1.($2+$3/60+$4/3600) }
    elsif ($lat =~ /^([+-])(\d\d)(\d\d)$/ )       { $lat = $1.($2+$3/60) }

    if    ($lon =~ /^([+-])(\d\d\d)(\d\d)(\d\d)$/){ $lon = $1.($2+$3/60+$4/3600) }
    elsif ($lon =~ /^([+-])(\d\d\d)(\d\d)$/ )     { $lon = $1.($2+$3/60) }

}

sub format_ll_dms {
    my $lat = shift;
    my $lon = shift;

    my $out = '';
    my ($formatted_lat, $is_north) = _dms($lat);
    $out = $formatted_lat . ' ' . ($is_north ? 'N' : 'S');

    $out .= ' ';

    my ($formatted_lon, $is_east) = _dms($lon);
    $out .= $formatted_lon . ' ' . ($is_east ? 'E' : 'W');

    return $out;

}

sub _dms {
    my $dd = shift;
    my $is_positive = ($dd>=0);

    $dd = abs($dd);
    my $d = int($dd);     $dd = $dd-$d;
    my $m = int($dd*60);  $dd = $dd-$m/60;
    my $s = $dd*3600;
    return sprintf("%d°%02d'%02d", $d, $m, $s), $is_positive;
}

sub format_ll_ISO {
    return sprintf "%+05d%+06d", _dm($_[0]), _dm($_[1])
}

sub _dm {
    my $r = shift;
    return 0 unless $r;

    my $sign = $r/abs($r); $r=abs($r);
    my $deg = int($r);
    my $min = int(0.5+60*($r-$deg));
    if ( $min == 60) {
        $deg++;
        $min=0;
    }
    return $sign*($deg*100+$min);  # beware that -1 * 0 = +0 in Perl!
}

my %datums = (

    "OSGB36" => [ 573.604, 0.119600236/10000, 375, -111, 431 ],

    );

sub shift_ll_from_WGS84 {

    my ($lat, $lon, $elevation) = (@_, 0);

    my $target_da = -573.604;
    my $target_df = -0.119600236/10000;
    my $target_dx = -375;
    my $target_dy = +111;
    my $target_dz = -431;

    my $reference_major_axis = WGS84_MAJOR_AXIS;
    my $reference_flattening = WGS84_FLATTENING;

    return _transform($lat, $lon, $elevation,
                      $reference_major_axis, $reference_flattening,
                      $target_da, $target_df,
                      $target_dx, $target_dy, $target_dz);
}

sub shift_ll_into_WGS84 {
    my ($lat, $lon, $elevation) = (@_, 0);

    my $target_da = +573.604;
    my $target_df = +0.119600236/10000;
    my $target_dx = +375;
    my $target_dy = -111;
    my $target_dz = +431;

    my $reference_major_axis = WGS84_MAJOR_AXIS - $target_da;
    my $reference_flattening = WGS84_FLATTENING - $target_df;

    return _transform($lat, $lon, $elevation,
                      $reference_major_axis, $reference_flattening,
                      $target_da, $target_df,
                      $target_dx, $target_dy, $target_dz);
}

sub _transform {
    return unless defined wantarray;

    my $lat = shift;
    my $lon = shift;
    my $elev = shift;

    my $from_a = shift;
    my $from_f = shift;

    my $da = shift;
    my $df = shift;
    my $dx = shift;
    my $dy = shift;
    my $dz = shift;

    my $sin_lat = sin( $lat * RAD );
    my $cos_lat = cos( $lat * RAD );
    my $sin_lon = sin( $lon * RAD );
    my $cos_lon = cos( $lon * RAD );

    my $b_a      = 1 - $from_f;
    my $e_sq     = $from_f*(2-$from_f);
    my $ecc      = 1 - $e_sq*$sin_lat*$sin_lat;

    my $Rn       = $from_a / sqrt($ecc);
    my $Rm       = $from_a * (1-$e_sq) / ($ecc*sqrt($ecc));

    my $d_lat = ( - $dx*$sin_lat*$cos_lon
                  - $dy*$sin_lat*$sin_lon
                  + $dz*$cos_lat
                  + $da*($Rn*$e_sq*$sin_lat*$cos_lat)/$from_a
                  + $df*($Rm/$b_a + $Rn*$b_a)*$sin_lat*$cos_lat
                ) / ($Rm + $elev);


    my $d_lon = ( - $dx*$sin_lon
                  + $dy*$cos_lon
                ) / (($Rn+$elev)*$cos_lat);

    my $d_elev = + $dx*$cos_lat*$cos_lon
                 + $dy*$cos_lat*$sin_lon
                 + $dz*$sin_lat
                 - $da*$from_a/$Rn
                 + $df*$b_a*$Rn*$sin_lat*$sin_lat;

    my ($new_lat, $new_lon, $new_elev) = (
         $lat + $d_lat * DAR,
         $lon + $d_lon * DAR,
         $elev + $d_elev,
       );

    return ($new_lat, $new_lon, $new_elev) if wantarray;
    return sprintf "%s, (%s m)", format_ll_dms($new_lat, $new_lon), $new_elev;

}

1;
__END__

=head1 NAME

Geo::Coordinates::OSGB - Convert Coordinates from Lat/Long to UK Grid

A UK-specific implementation of co-ordinate conversion, following formulae
from the Ordnance Survey of Great Britain (hence the name), from the OSGB
grid to latitude and longitude.

Used on their own, these modules will allow you convert accurately between a
grid reference and lat/lon coordinates based on the OSGB Airy 1830 geoid
model (the traditional model used for maps in the UK for the last 180 years)
and last amended by the OS in 1936.  This model is sometimes referred to as OSGB36.

OSGB36 fits the British Isles very well, but is rather different from the
WGS84 model that has rapidly become the de facto universal standard model
thanks to the popularity of GPS devices and maps on the Internet.  So, if you
are trying to translate from a OSGB grid reference to lat/lon coordinates
that can be used in in Google Earth, Wikipedia, or some other Internet based
tool, you will need to do two transformations.  First translate your grid ref
into OSGB lat/lon, then nudge the result into WGS84.  Routines are provided
to do both of these operations, but they are only approximate.  The inaccuracy
of the approximation varies according to where you are in the country but may
be as much as several metres in some areas.

To get really accurate results you need to combine this module with its
companion L<Geo::Coordinates::OSTN02> which implements the transformation
(known as OSTN02) that now defines the relationship between GPS survey data
based on WGS84 and the British National Grid.  Using this module you should
be able to get results that are accurate to within a few centimetres, but it
is a little bit slower and requires a bit more memory to run.

Version: 2.01

=head1 SYNOPSIS

  use Geo::Coordinates::OSGB qw(ll_to_grid grid_to_ll);

  # basic conversion routines
  ($easting,$northing) = ll_to_grid($lat,$lon);
  ($lat,$long) = grid_to_ll($easting,$northing);

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

  # latitude and longitude are returned according to the OSGB36 (as printed on OS maps)
  # if you want them to work in Google Earth or some other tool that uses WGS84 then
  # you need to adjust the results
  ($lat, $long, $elevation) = shift_ll_into_WGS84($lat, $long, $elevation);



=head1 DESCRIPTION

This module provides a collection of routines to convert between longitude &
latitude and map grid references, using the formulae given in the British
Ordnance Survey's excellent information leaflet, referenced below in
L<"Theory">.  There are some key concepts explained in that section that you
need to know in order to use these modules successfully, so you are
recommended to at least skim through it now.

The module is implemented purely in Perl, and should run on any Perl platform.

In this description `OS' means `the Ordnance Survey of Great Britain': the UK
government agency that produces the standard maps of England, Wales, and
Scotland.  Any mention of `sheets' or `maps' refers to one or more of the 204
sheets in the 1:50,000 scale `Landranger' series of OS maps.

=head1 FUNCTIONS

The following functions can be exported from the C<Geo::Coordinates::OSGB>
module:

    ll_to_grid
    grid_to_ll

    parse_grid
    parse_trad_grid
    parse_GPS_grid
    parse_landranger_grid
    format_grid_trad
    format_grid_GPS
    format_grid_landranger

    parse_ll
    format_ll_dms
    format_ll_ISO

    shift_ll_into_WGS84
    shift_ll_from_WGS84

None of these is exported by default.

This code is fine tuned to the British national grid system.  You could use it
elsewhere but you will need to adapt it.  Some starting points for doing this
are explained in detail in the L<"Examples"> section below.

=over 4

=item ll_to_grid(lat,lon)

When called in a void context, or with no arguments C<ll_to_grid> does nothing.
When called in a list context, C<ll_to_grid> returns two numbers that represent
the easting and the northing corresponding to the latitude and longitude
supplied.

The parameters can be supplied as real numbers representing degrees or in ISO
`degrees, minutes, and seconds' form.  That is 'C<sdd[mm[ss]]>' for I<lat>
and 'C<sddd[mm[ss]]>' for I<long>.  The magnitude of the arguments is used to
infer which form is being used.  Note the leading C<s> is the sign +
(North,East) or - (South,West).  If you use the ISO format be sure to 'quote'
the arguments, otherwise Perl will think that they are numbers, and strip
leading 0s and + signs which may give you unexpected results.  For example:

    my ($e,$n) = ll_to_grid('+5120','-00025');

If you have trouble remembering the order of the arguments, note that
latitude comes before longitude in the alphabet too.

The easting and northing will be returned as a whole number of metres from
the point of origin of the British Grid (which is a point a little way to the
south-west of the Scilly Isles).  If you want the grid presented in a more
traditional format you should pass the results to one of the grid formatting
routines, which are described below.

If you call C<ll_to_grid> in a scalar context, it will automatically call
C<format_grid_trad>.  For example:

    my $gridref = ll_to_grid('+5120','-00025');

In this case the string returned represents the `full national
grid reference' with two letters and two sets of three numbers, like this
`TQ 102 606'.  If you want to remove the spaces, just apply C<s/\s//g> to it.
To get the grid reference formatted differently, just wrap it in the appropriate
format routine, like this:

    $gridref = format_grid_GPS(ll_to_grid('+5120','-00025'));
    $gridref = format_grid_landranger(ll_to_grid('+5120','-00025'));

It is not needed for any normal work, but C<ll_to_grid()> also takes an
optional third argument that sets the ellipsoid model to use.  This normally
defaults to "OSGB36", the name of the normal model for working with British
maps.  If you are working with the highly accurate OSTN02 conversions
supplied in the companion module in this distribution, then you will need to
produce pseudo-grid references as input to those routines.  For these
purposes you should call C<ll_to_grid()> like this:

    my $pseudo_gridref = ll_to_grid('+5120','-00025', 'WGS84');

and then transform this to a real grid reference using C<ETRS89_to_OSGB36()>
from the companion module.

=item format_grid_trad(e,n)

Formats an (easting, northing) pair into traditional `full national grid
reference' with two letters and two sets of three numbers, like this `TQ 102
606'.  If you want to remove the spaces, just apply C<s/\s//g> to it.
If you want the individual components call it in a list context.


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

Note that, at least until WAAS is working in Europe, the results from your
GPS are unlikely to be more accurate than plus or minus 5m even with perfect
reception.  Most GPS devices can display the accuracy of the current fix you
are getting, but you should be aware that all normal consumer-level GPS
devices can only ever produce an approximation of an OS grid reference, no
matter what level of accuracy they may display.  The reasons for this are
discussed below in the section on L<Theory>.


=item format_grid_landranger(e,n)

This routine does the same as C<format_grid_trad>, but it appends the number
of the relevant OS Landranger 1:50,000 scale map to the traditional grid
reference.  Note that there may be several or no sheets returned.  This is
because many (most) of the Landranger sheets overlap, and many other valid
grid references are not on any of the sheets (because they are in the sea or
a remote island.  This module does not cope with the detached insets on some
sheets (yet).

In a list context you will get back a list like this:  (square, easting,
northing, sheet) or (square, easting, northing, sheet1, sheet2) etc.  There
are a few places where three sheets overlap, and one corner of Herefordshire
which appears on four maps (sheets 137, 138, 148, and 149).  If the GR is not
on any sheet, then the list of sheets will be empty.

In a scalar context you will get back the same information in a helpful
string form like this "NN 241 738 on OS Sheet 44".  Note that the easting and
northing will have been truncated to the normal truncated `hectometre' three
digit form.


=item parse_trad_grid(grid_ref)

Turns a traditional grid reference into a full easting and northing pair in
metres from the point of origin.  The I<grid_ref> can be a string like
`TQ203604' or `SW 452 004', or a list like this C<('TV', '435904')> or a list
like this C<('NN', '345', '208')>.


=item parse_GPS_grid(grid_ref)

Does the same as C<parse_trad_grid> but is looking for five digit numbers
like `SW 45202 00421', or a list like this C<('NN', '34592', '20804')>.


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
it with the sheet number.  It is easy to work out the coordinates of the
other corners, because all OS Landranger maps cover a 40km square (if you
don't count insets or the occasional sheet that includes extra details
outside the formal margin).

=item parse_grid('string')

Attempts to match a grid reference some form or other
in the input string and will then call the appropriate grid
parsing routine from those defined above.  In particular it will parse strings in the form
'176-345210' meaning grid ref 345 210 on sheet 176, as well as 'TQ345210' and 'TQ 34500 21000' etc.

=item grid_to_ll(e,n) or grid_to_ll(grid_ref)

When called in list context C<grid_to_ll> returns a pair of numbers
representing longitude and latitude coordinates, as real numbers.  Following
convention, positive numbers are North and East, negative numbers are South
and West.  The fractional parts of the results represent fractions of
degrees.

When called in scalar context it returns a string in ISO longitude and latitude
form, such as '+5025-00403' with the result rounded to the nearest minute (the
formulae are not much more accurate than this).  In a void context it does
nothing.

The arguments must be an (easting, northing) pair
representing the absolute grid reference in metres from the point of origin.
You can get these from a grid reference string by calling C<parse_grid()> first.

An optional third argument defines the geoid model to use just as it does for
C<ll_to_grid()>.  This is only necessary is you are working with the
pseudo-grid references produced by the OSTN02 routines.  See L<Theory> for
more discussion.

=back

=head1 THEORY

The algorithms and theory for these conversion routines are all from
I<A Guide to Coordinate Systems in Great Britain>
published by the Ordnance Survey, April 1999 and available at
http://www.ordnancesurvey.co.uk/oswebsite/gps/information/index.html

You may also like to read some of the other introductory material there.
Should you be hoping to adapt this code to your own custom Mercator
projection, you will find the paper called I<Surveying with the
National GPS Network>, especially useful.

=head2 The British National Grid

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

=head2 Geoid models

This section explains the fundamental problems of mapping a spherical earth
onto a flat piece of paper (or computer screen).  A basic understanding of
this material will help you use these routines more effectively.  It will
also provide you with a good store of ammunition if you ever get into an
argument with someone from the Flat Earth Society.

It is a direct consequence of Newton's law of universal gravitation (and in
particular the bit that states that the gravitational attraction between two
objects varies inversely as the square of the distance between them) that all
planets are roughly spherical.  (If they were any other shape gravity would
tend to pull them into a sphere).  Most useful surfaces for displaying maps
(such as pieces of paper or screens) on the other hand are flat.  There is
therefore a fundamental problem in making any maps of the earth that its
curved surface being mapped must be distorted at least slightly in order to
get it to fit onto the flat map.

This module sets out to solve the corresponding problem of converting
latitude and longitude coordinates (designed for a spherical surface) to and
from a rectangular grid (for a flat surface).  This projection is in itself
is a fairly lengthy bit of maths, but what makes it complicated is that the
earth is not quite a sphere.  Because our planet is also spinning about its
axis, it tends to bulge out slightly in the middle, so it is more of an
oblate spheroid than a sphere.  This makes the maths even longer, but the
real problem is that the earth is not a regular oblate spheroid either, but
an irregular lump that closely resembles an oblate spheroid and which is
constantly (if slowly) being rearranged by plate tectonics.  So the best we
can do is to pick an imaginary regular oblate spheroid that provides a good
fit for the region of the earth that we are interested in mapping.  The
British Ordnance Survey did this back in 1830 and have used it ever since
(with revisions in 1936) as the base on which the National Grid for Great
Britain is constructed.  You can also call an oblate spheroid an ellipsoid if
you like.  The ellipsoid model that the OS defined is called OSGB36 for
short, and it's parameters are built into these modules.

The general idea is that you can establish your latitude and longitude by
careful observation of the sun, the moon, the planets, or your GPS handset,
and that you then do some clever maths to work out the corresponding grid
reference, using a suitable idealised ellipsoid model of the earth (which is
generally known as a "geoid").  These modules let you do the clever maths,
and the model they use is the OSGB36 one.  Unfortunately, while this model
suits Britain very well, it is less useful in the rest of the world, and
there are many other models in use in other countries.  In the mid-1980s a
new standard geoid model was defined to use with the fledgling global
positioning system (GPS).  This model is known as WGS84, and is designed to
be a compromise model that works equally well for all parts of the globe (or
equally poorly depending on your point of view).  WGS84 has grown in
importance as GPS systems have become consumer items and useful global
mapping tools (such as Google Earth) have become freely available through the
Internet.  Most latitude and longitude coordinates quoted on the Internet
(for example in Wikipedia) are WGS84 coordinates.  All of this means that
there is no such thing as an accurate set of coordinates for every unique
spot on earth.  There are only approximations based on one or other of the
accepted geoid models, however for most practical purposes good
approximations are all you need.  In Europe the official definition of WGS84
is sometime referred to as ETRS89.  For all practical purposes, you can
regard ETRS89 as identical to WGS84.

So, if you are working exclusively with British OS maps and you merely want
to convert from the grid to the latitude and longitude coordinates prined (as
faint blue crosses) on those maps, then all you need from these modules are
the plain C<grid_to_ll()> and C<ll_to_grid()> routines.  On the other hand if
you want to produce latitude and longitude coordinates suitable for Google
Earth or Wikipedia from a British grid reference, then you need an extra
step.  Convert your grid reference using C<grid_to_ll()> and then shift it
from the OSGB36 model to the WGS84 model using C<shift_ll_into_WGS84()>.  To
go the other way round, shift your WGS84 lat/lon coordinated into OSGB36,
using C<shift_ll_from_WGS84()>, before you convert them using
C<ll_to_grid()>.

If you have a requirement for really accurate work (say to within a
millimetre or two) then the above routines may not satisfy you, as they are
only really accurate to within a metre or two.  Instead you will need to use
the OS's newly published transformation matrix called OSTN02.  This
monumental work re-defines the British grid interms of offsets from WGS84 to
allow really accurate grid references to be determined from really accurate
GPS readings (the sort you get from professional fixed base stations, not
from your car's sat nav or your hand held device).  The problem with it is
that it defines the grid in terms of a deviation in three dimensions from a
pseudo-grid based on WGS84 and it does this separately for every square metre
of the country, so the data set is huge and takes several seconds to load
even on a fast machine.  Nevertheless a Perl version of OSTN02 is included as
a seperate module in this distribution just in case you really need it (but
you don't need it for any "normal" work).  Because of the way it is defined,
it works differently from the approximate routines described above.

Starting with a really accurate lat/lon reading in WGS84 terms, you need to
transform it into a pseudo-grid reference using C<ll_to_grid()> with an
optional argument to tell it to use the WGS84 geoid parameters instead of the
default OSGB36 parameters.  C<Geo::Coordinates::OSTN02> then provides a
routine called C<ETRS89_to_OSGB36()> which will shift this pseudo-grid
reference into an accurate OSGB grid reference.  To go back the other way,
you use C<OSGB36_to_ETRS89()> to make a pseudo-grid reference, and then call
C<grid_to_ll()> with the WGS84 parameter to get WGS84 lat/long coordinates.

=head1 BUGS

The conversions are only approximate.   So after

  ($a1,$b1) = grid_to_ll(ll_to_grid($a,$b));

neither C<$a==$a1> nor C<$b==$b1>. However C<abs($a-$a1)> and C<abs($b-$b1)>
should be less than C<0.00001> which will give you accuracy to within a few
centimetres.  Note that the error increases the further away you are from the
reference point of the grid system.

When using ll_to_grid in scalar mode to get a "TQ999999" type of grid reference
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
that you can adapt to any other ellipsoid model that is suitable for your
local area of the earth.

Once you have defined the ellipsoid to use in terms of its major and minor
diameters you have to define the projection that defines your local grid and
the reference points for the grid.  You need to start by choosing an point in
the middle of your area and finding the longitude and latitude.  This is
known as the True Origin of the Projection.

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

In Britain the True Point of Origin is a point (near the northern coast of
France) at 49° North and 2° West (in the OSGB36 model), and this is given the
grid coordinated (400000,-100000) so that the False point of origin, point
(0,0) is just to the SW of the Scilly Isles.


=head1 AUTHOR

Toby Thurston ---  6 Sep 2007

web: http://www.wildfire.dircon.co.uk

=head1 SEE ALSO

The UK Ordnance Survey's theory paper referenced above in L<"Theory">.

See L<Geo::Coordinates::Convert> for a general approach (not based on the above
paper).

See L<Geo::Coordinates::Lambert> for a French approach.

=cut

1;
