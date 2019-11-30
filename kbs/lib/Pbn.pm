############
package Pbn;
############

use strict;
use warnings;
use Exporter;
use IO::File;
use Data::Dumper;
# $Id: Pbn.pm 1622 2016-10-17 15:30:44Z phaff $
# Code to load a Pbn format file.

our(@ISA) = qw(Exporter);

use constant PBN_NORTH => 0;
use constant PBN_EAST => 1;
use constant PBN_SOUTH => 2;
use constant PBN_WEST => 3;

use constant PBN_SPADES => 0;
use constant PBN_HEARTS => 1;
use constant PBN_DIAMONDS => 2;
use constant PBN_CLUBS => 3;

our(@EXPORT) = qw(&PBN_NORTH &PBN_EAST &PBN_SOUTH &PBN_WEST
                  &PBN_SPADES &PBN_HEARTS &PBN_DIAMONDS &PBN_CLUBS);

sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    return $self;
}

# Load and verify a pbn file.
# We are only interested in the cards, so
# discard everything else.
# Pass in the filename to open.
# Store an array of boards, each with an array of 4 hands (N,E,S,W),
# each with an array of suites (S,H,D,C) that contain a string of
# cards.
# Array indexes

sub load
{
    my($self) = shift();
    my($fname) = @_;
    my($boards) = [];
    my($hands);
    my($suits);
    my($bno) = 0;
    my($line);
    my($inmake) = 0;
    # Makeable contracts
    # Index by $bno -1.
    # Each is a hash,
    # keyed by direction, nsew, followed by suit cdhsn
    my($makecon) = [];

    my($fh) = IO::File->new();

    if (!$fh->open($fname, "<")) {
        return (0, "Failed to open $fname $!");
    }
    my($lc) = 0;
    while ($line = $fh->getline()) {
        $lc++;
        next if $line =~ m/^\s*$/; # ignore blank lines
        if ($line =~ m/^\[Board/) {
            ($bno) = $line =~ m/"(\d+)"/;
            if (!defined($bno)) {
                chomp($line);
                return (0, "Unable to extract board number from $line $lc");
            }
            $inmake = 0;
            next;
        }
        $line =~ s/\r//;
        if ($line =~ m/^\[Deal /) {
            if ($bno == 0) {
                return (0, "The board number has not been set at line $lc");
            }
            chomp($line);
            my($ret, $rea);
            ($ret, $rea) = $self->verify($lc, $boards, $bno, $line);
            if (!$ret) {
                return ($ret, $rea);
            }
            # So we can spot missing "[Board" lines.
            next;
        }
        if ($line =~ m/^\[OptimumResultTable /) {
            if ($bno == 0) {
                return (0, "At line $lc I have seen a OptimumResultTable line, but not after a Deal line")
            }
            $inmake = 1;
            next;
        }
        if ($inmake) {
            if ($line =~ m/^\[/) {
                my($ret, $rea);
                # Hit the end of the road Jack.
                $inmake = 0;
                ($ret, $rea) = checkmake($makecon->[$bno - 1]);
                if ($ret == 0) {
                    return ($ret, $rea);
                }
                next;
            }
            chomp($line);
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            my(@fields) = split(/\s+/, $line);
            if (scalar(@fields) != 3) {
                return (0, "At line $lc the line has not split into 3 fields - line ($line)");
            }
            my($key) = $fields[0] . substr($fields[1], 0, 1);
            $key = lc($key);
            $makecon->[$bno - 1]->{$key} = $fields[2];
        }
    }
    $self->{boards} = $boards;
    $self->{makecon} = $makecon;
    $fh->close();
    return (1, "");
}

sub gettop
{
    my($self) = shift();
    return scalar(@{$self->{boards}});
}

sub verify
{
    my($self) = shift();
    my($lc, $boards, $bno, $line) = @_;
    my($first, $str) = $line =~ m/^\s*\[Deal\s+"([NEWS]):(.*)"\]$/;

    if (!defined($str)) {
        return (0, "Initial pattern match error line $lc ($line)");
    }
    my($len) = length($str);
    if ($len != 67) {
        return (0,
         "Bad length error line $lc. Actual length $len, expected 67");
    }
    my(@hands) = split(m/\s+/, $str);
    if (@hands != 4) {
        return (0,
          "Bad number of hands at $lc: Hand count ", scalar(@hands));
    }
    my($handcnt) = 0;
    my($hand);
    my($look) = {};
    $look->{1} = {};
    $look->{2} = {};
    $look->{3} = {};
    $look->{4} = {};

    # Rotate the hands based on the first hand indicator
    my($rot);
    if ($first eq "N") {
        $rot = 0;
    } elsif ($first eq "E" ) {
        $rot = 3;
    } elsif ($first eq "S") {
        $rot = 2;
    } else {
        $rot = 1;
    }

    while ($rot > 0) {
        my($top) = shift(@hands);
        push(@hands, $top);
        $rot--;
    }

    foreach $hand (@hands) {
        $handcnt++;
        my(@suits) = split(m/\./, $hand, -1);
        if (@suits != 4) {
            return (0,
              "Bad number of suits in hand $handcnt line $lc. " .
              "Number of suits " .  scalar(@suits) . " hand contains $hand");
        }
        my($suitcnt) = 0;
        my($suit);
        foreach $suit (@suits) {
            $suitcnt++;
            # Only uppercase?
            if ($suit =~ m/[^2-9AKQJT]/) {
                return (0,
                  "Bad character in suit $suitcnt hand $hand line $lc. ",
                  "($suit)");
            }
            if (defined($suit)) {
                my(@cards) = split(m//, $suit);
                my($card);
                foreach $card (@cards) {
                    if (exists($look->{$suitcnt}->{$card})) {
                        return (0,
                          "Card $card alreay exists in suit $suitcnt ",
                          "hand $handcnt at ",
                          "line $lc");
                    } else {
                        $look->{$suitcnt}->{$card} = 1;
                    }
                }
                $boards->[$bno - 1]->[$handcnt - 1]->[$suitcnt - 1] =  $suit
            }
        }
    }
    return (1, "");
}

my($makekeys) = {
                 nc => 0,
                 nd => 0,
                 nh => 0,
                 ns => 0,
                 nn => 0,
                 ec => 0,
                 ed => 0,
                 eh => 0,
                 es => 0,
                 en => 0,
                 sc => 0,
                 sd => 0,
                 sh => 0,
                 ss => 0,
                 sn => 0,
                 wc => 0,
                 wd => 0,
                 wh => 0,
                 ws => 0,
                 wn => 0,
};


sub checkmake
{
    my($makecon) = @_;
    my($ret, $rea);
    my($chash);
    my($key, $val);
    my($count) = 0;
    # Fresh
    %$chash = %$makekeys;

    while (($key, $val) = each(%$makecon)) {
        if (!exists($chash->{$key})) {
            return (0, "Key $key is not valid");
        }
        if ($chash->{$key} != 0) {
            return (0, "Key $key is duplicated");
        }
        $chash->{$key}++;
        $count++;
    }
    if ($count != 20) {
        return (0, "We have $count keys instead of 20");
    }
    return (1, "");
}


sub getstr
{
    my($self) = shift();
    my($bno, $hand, $suit) = @_;

    my($str) = $self->{boards}->[$bno - 1]->[$hand]->[$suit];
    if (!defined($str)) {
        return "unknown";
    }
    return $str;
}

sub havemake
{
    my($self) = shift();
    my($bno) = @_;

    if (defined($self->{makecon}->[$bno - 1])) {
        return 1;
    }
    return 0;
}


sub validboard
{
    my($self) = shift();
    my($bno) = @_;

    if (exists($self->{boards}->[$bno - 1])) {
        return 1;
    }
    return 0;
}

sub makecontracts
{
    my($self) = shift();
    my($bno, $dir, $suit) = @_;

    $dir = lc($dir);
    $suit = lc($suit);

    if ($dir !~ /^[news]$/) {
        print("Bad dir\n");
        return undef;
    }
    if ($suit!~ /^[cdhsn]$/) {
        print("Bad suit\n");
        return undef;
    }
    my($makec) = $self->{makecon};
    if (!defined($makec->[$bno - 1])) {
        print("bad bno\n");
        return undef;
    }
    my($key) = $dir . $suit;
    return ($makec->[$bno - 1]->{$key});
}



#
# Some code to produce postscript output.
#


our($suitlookup) = {
                   &PBN_SPADES => "s",
                   &PBN_HEARTS => "h",
                   &PBN_DIAMONDS => "d",
                   &PBN_CLUBS => "c",
                  };
our($handlookup) = {
                   &PBN_NORTH => "north",
                   &PBN_SOUTH => "south",
                   &PBN_EAST => "east",
                   &PBN_WEST => "west",
                  };


our($postscript) = <<'EOF';
%! A test postscript page
/mm { 2.834 mul } def

/basex { 0 mm } def
/basey { 0 mm } def

/bno    (#bno) def
/norths (#norths) def
/northh (#northh) def
/northd (#northd) def
/northc (#northc) def

/easts (#easts) def
/easth (#easth) def
/eastd (#eastd) def
/eastc (#eastc) def

/souths (#souths) def
/southh (#southh) def
/southd (#southd) def
/southc (#southc) def

/wests (#wests) def
/westh (#westh) def
/westd (#westd) def
/westc (#westc) def

/hand
{
        gsave
        translate

        12 mm 8 mm moveto
        show

        12 mm 17 mm moveto
        show

        12 mm 25 mm moveto
        show

        12 mm 34 mm moveto
        show

        55 mm 41 mm moveto
        show

        grestore
} def

0 297 mm translate
270 rotate

/Times-Roman findfont
16 scalefont
setfont

bno norths northh northd northc 0 mm basex add 50 mm basey add hand
bno easts easth eastd eastc 75 mm basex add 50 mm basey add hand
bno souths southh southd southc 0 mm basex add 0 mm basey add hand
bno wests westh westd westc 75 mm basex add 0 mm basey add hand

showpage
EOF


# A single curtain card.
# Called $pbn->("outputfile", $boardnumber);
sub card
{
    my($self) = shift();
    my($of, $bno) = @_;

    my($hand, $suit);
    my($ps) = $postscript;
    print("card called with board number $bno\n");
    foreach $hand (PBN_NORTH, PBN_SOUTH, PBN_EAST, PBN_WEST){
        foreach $suit (PBN_SPADES, PBN_HEARTS, PBN_DIAMONDS, PBN_CLUBS) {
            my($key) = $handlookup->{$hand} . $suitlookup->{$suit};
            my($val) = $self->getstr($bno, $hand, $suit);
            if ($val eq "unknown") {
                print("Unknown returned for key $key board number $bno\n");
                return;
            }
            if ($val eq "") {
                $val = "-";
            }
            if (length($val) <= 9) {
                $val =~ s/(.)/$1 /g;
            }
            $ps =~ s/#$key/$val/m;
        }
    }
    $ps =~ s/#bno/$bno/om;

    my($fh) = IO::File->new();
    if (!$fh->open($of, ">")) {
        die("Failed to open $of $!\n");
    }
    $fh->print($ps);
    $fh->close();
}


our($preamble) = <<'EOF';
%! A test postscript page
/mm { 2.834 mul } def

/fontsize 13 def

/times {/Times-Roman findfont fontsize scalefont setfont } def
/symbol {/Symbol findfont fontsize scalefont setfont } def

/spade { symbol (\252) show times } def
/heart {
        symbol currentrgbcolor 255 0 0 setrgbcolor (\251) show
        setrgbcolor times }        def
/diamond {
        symbol currentrgbcolor 255 0 0 setrgbcolor (\250) show
        setrgbcolor times } def

/club { symbol (\247) show times } def

/x1 4 mm def
/x2 32 mm def
/x3 70 mm def
/x4 95 mm def
/dy 3.7 mm def
/xsize 133 mm def
/ysize 48.5 mm def

/midboxx 70 mm def
/midboxy 19 mm def
/midboxsize dy 3 mul def
/nsym { 74 mm 26.5 mm } def
/ssym { 74 mm 20 mm } def
/esym { 78 mm 23 mm } def
/wsym { 70 mm 23 mm } def
/drawhand {
        gsave
        translate
        % draw box
        0 0 moveto
        0 ysize lineto
        xsize ysize lineto
        xsize 0 lineto
        closepath
        1 setlinewidth
        stroke

        x2 dy 5 mul moveto club show % west clubs
        x2 dy 6 mul moveto diamond show % west diamonds
        x2 dy 7 mul moveto heart show % west hearts
        x2 dy 8 mul moveto spade show % west spades

        x3 dy 1 mul moveto club show % south clubs
        x3 dy 2 mul moveto diamond show % south diamonds
        x3 dy 3 mul moveto heart show % south hearts
        x3 dy 4 mul moveto spade show % south spades

        x4 dy 5 mul moveto club show % south clubs
        x4 dy 6 mul moveto diamond show % south diamonds
        x4 dy 7 mul moveto heart show % south hearts
        x4 dy 8 mul moveto spade show % south spades

        x3 dy 9 mul moveto club show % north clubs
        x3 dy 10 mul moveto diamond show % north diamonds
        x3 dy 11 mul moveto heart show % north hearts
        x3 dy 12 mul moveto spade show % north spades

        %% board number
        %% dealer
        %% vul

        x1 dy 12 mul moveto (Board: ) show show
        x1 dy 11 mul moveto (Dealer: ) show show
        x1 dy 10 mul moveto (Vul: ) show show

        %%
        %% draw the middle box
        %%
        newpath
        midboxx midboxy moveto
        midboxx midboxsize add midboxy lineto
        midboxx midboxsize add midboxy midboxsize add lineto
        midboxx midboxy midboxsize add lineto
        closepath
        stroke

        nsym moveto
        (N) show
        ssym moveto
        (S) show
        esym moveto
        (E) show
        wsym moveto
        (W) show

        grestore
} def
EOF

our($startofhand) =<<'EOF';
%% We have a 1cm border
0 297 mm translate
270 rotate
15 mm 10 mm translate
times
EOF

our($postamble) =<<'EOF';
showpage
EOF

sub all
{
    my($self) = shift();
    my($of) = @_;
    my(@outstr);
    my($top);
    my($bn);
    my($suit);
    my($hand);
    my($xind) = 0;
    my($yind) = 0;
    my($needshow) = 0;

    $top = $self->gettop();
 BOARD:
    for ($bn = 1; $bn <= $top; $bn++) {
        if ($needshow == 0) {
            push(@outstr, $startofhand);
        }
        push(@outstr, "%% Board number $bn");
        push(@outstr, "(" . Board->vulstr($bn) . ")");
        push(@outstr, "(" . Board->dealstr($bn) . ")");
        push(@outstr, "($bn)");
        foreach $hand (PBN_NORTH, PBN_EAST, PBN_SOUTH, PBN_WEST){
            foreach $suit (PBN_SPADES, PBN_HEARTS, PBN_DIAMONDS, PBN_CLUBS) {
                my($key) = $handlookup->{$hand} . $suitlookup->{$suit};
                my($val) = $self->getstr($bn, $hand, $suit);
                if ($val eq "unknown") {
                    print("Unknown returned for key $key board number $bn\n");
                    next BOARD;
                }
                if ($val eq "") {
                    $val = "-";
                }
                if (length($val) < 8) {
                    $val =~ s/(.)/$1 /g;
                    $val =~ s/ $//;
                }
                push(@outstr, "($val)");
            }
        }
        push(@outstr, "$xind xsize mul " .
             (3 - $yind) . " ysize mul drawhand");
        $xind++;
        $needshow = 1;
        if ($xind == 2) {
            $xind = 0;
            $yind++;
            if ($yind == 4) {
                push(@outstr, "showpage");
                $yind = 0;
                $needshow = 0;
            }
        }
    }
    unshift(@outstr, $preamble);
    if ($needshow) {
        push(@outstr, $postamble);
    }

    my($fh) = IO::File->new();
    if (!$fh->open($of, ">")) {
        die("Failed to open $of $!\n");
    }
    $fh->print(join("\n", @outstr), "\n");
    $fh->close();
}

###################################
# This is all the stuff to print the
# sheets for classes, so the entry
# point is called 'classes'.
###################################

our($class_preamble) = <<'EOF';
%! (c) 2013 Paul Haffenden.
%% prints out the class hands onto A4, 8 hands a sheet.
/mm { 2.834 mul } def
/fontsize 13 def
/timesfont {/Times-Roman findfont fontsize scalefont setfont } def
/symbolfont {/Symbol findfont fontsize scalefont setfont } def

/spade { symbolfont (\252) show timesfont } def
/heart {
        symbolfont currentrgbcolor 255 0 0 setrgbcolor (\251) show
        setrgbcolor timesfont }        def
/diamond {
        symbolfont currentrgbcolor 255 0 0 setrgbcolor (\250) show
        setrgbcolor timesfont } def

/club { symbolfont (\247) show timesfont } def

%% The top of the page
/top 297 mm def

%% The gap to leave at the top of the page
/topmargin 10 mm def
%% The gap to leave to the left of the page
/leftmargin 5 mm def

%% the width of each 'hand' box. We fix 4 across an A4 sheet.
/xsize 50 mm def
%% The height of each 'hand' box. We fit upto 8 into an A4 sheet.
/ysize 34 mm def

%% Where the top of the top box appears.
/topoftable top topmargin sub def

%% row2off convert the top of stack into into a y offset of where to start the
%% box

/row2off {
1 add ysize mul
topoftable
exch
sub
} def

/col2off {
  xsize
  mul
  leftmargin
  add
} def

%% the offset from the left of the box where the suit symbols are placed
/suitoff 2 mm def

%% the gap between the lines
/gap 6 mm def

%% return y based on the line argument.
/line {
  gap mul ysize exch sub
} def

%% work out how far we need to start to right align
%% Get passed with our string
/fromright {
  %% push x and y on stack
  stringwidth
  %% pop y
  pop
  suitoff
  add
  xsize
  exch
  sub
} def

%% given a string parameter, work out its x point
%% so as to center it (Within a box)
/center {
  %% push x and y on stack
  stringwidth
  %% pop y
  pop
  %% halve it
  2
  div
  %% halve the width
  xsize
  2
  div
  exch
  %% Now substract the two
  sub
} def

%% Takes the following arguments
%% (deal+vul) - the dealer and vulnerability of the hand
%% (clubs) - the string of clubs for the hand
%% (diamonds) - the string of diamonds for the hand
%% (hearts) - the string of hearts for the hand
%% (spades) - the string of spades for the hand
%% (Board #) - the board number
%% (Postion) - either North, South, East, West
%% (x) - bottom position of bounding box
%% (y) - left position of bounding box 

/drawbox {
  gsave
    %% eats up x and y
    translate
    %% draw the box
    newpath  
    0 0 moveto
    0 ysize lineto
    xsize ysize lineto
    xsize 0 lineto
    closepath
    1 setlinewidth
    stroke
    suitoff 1 line moveto
    %% pops the position
    show
    dup fromright 1 line moveto
    %% pops the board
    show
    suitoff 2 line moveto
    %% pops the spade string
    spade show
    suitoff 3 line moveto
    %% pops the hearts string
    heart show
    suitoff 4 line moveto
    %% pops the diamonds string
    diamond show
    suitoff 5 line moveto
    %% pops the clubs string
    club show

    dup center 1 line moveto
    %% pops the dealer+vul string
    show
  grestore
} def

%% passed with string and offset
/eachheader {
  exch
  dup
  stringwidth
  pop 
  2 div 
  xsize 2 div
  %stack
  3 index col2off add
  exch
  sub
  topoftable 3 mm add moveto
  show
  pop
} def


/eachfooter {
  exch
  dup
  stringwidth
  pop 
  2 div 
  xsize 2 div
  %stack
  3 index col2off add
  exch
  sub
  8 mm moveto
  show
  pop
} def

%% Print the file bane at the top of each column
/headers {
  %% We have the string argument on the stack.
  dup 0 eachheader
  dup 1 eachheader
  dup 2 eachheader
  3 eachheader
} def


/footers {
  %% We have the string argument on the stack.
  dup 0 eachfooter
  dup 1 eachfooter
  dup 2 eachfooter
  3 eachfooter
} def

EOF

sub class_startpage
{
    my($outstr, $pageno, $top_pageno, $header) = @_;
    my($str);
    push(@$outstr, "timesfont");
    push(@$outstr, "($header) headers");

    $str = "Otford BC $pageno of $top_pageno";
    push(@$outstr, "($str) footers");
}

sub classes
{
    my($self) = shift();
    my($of, $header, $doublesided) = @_;
    my($top);
    my($bn);
    my($suit);
    my($hand);
    my($pageno);
    my($top_pageno);
    my(@outstr);
    my($needpage);
    my($boardgen) = 0;

    $top = $self->gettop();

    # Let's write the preable out.
    # Work out the max number of pages.
    $top_pageno = int ($top / 8);
    if (($top % 8) > 0) {
        $top_pageno++;
    }
    $pageno = 1;
    $needpage = 1;

    print("Top is $top\n");
 BOARD:
    for ($bn = 1; $bn <= $top; $bn++) {
        if ($needpage) {
            class_startpage(\@outstr, $pageno, $top_pageno, $header);
            $needpage = 0;
        }

        push(@outstr, "%% Board number $bn");
        # Output the header in the middle
        my($mid) = "[" . Board->dealstr($bn) . "-" . Board->vulstr($bn) . "]";

        # Now we want the clubs
        foreach $hand (PBN_NORTH, PBN_EAST, PBN_SOUTH, PBN_WEST) {
            my($ind);
            if ((($pageno % 2) == 0) && $doublesided) {
                $ind = PBN_WEST - $hand;
            } else {
                $ind = $hand;
            }

            push(@outstr, "($mid)");
            foreach $suit (PBN_CLUBS, PBN_DIAMONDS, PBN_HEARTS, PBN_SPADES) {
                my($key) = $handlookup->{$hand} . $suitlookup->{$suit};
                my($val) = $self->getstr($bn, $hand, $suit);
                if ($val eq "unknown") {
                    print("Unknown returned for key $key board number $bn\n");
                    next BOARD;
                }
                if ($val eq "") {
                    $val = "-";
                }
                if (length($val) < 8) {
                    $val =~ s/(.)/$1 /g;
                    $val =~ s/T/10/;
                    $val =~ s/ $//;
                }
                push(@outstr, "($val)");
            }
            # Thats all the cards.
            push(@outstr, "($bn)");
            push(@outstr, "(" . ucfirst($handlookup->{$hand}) . ")");
            push(@outstr, $ind, "col2off", $boardgen, "row2off drawbox");
        }
        $boardgen++;
        if ($boardgen >= 8) {
            push(@outstr, "showpage");
            $needpage = 1;
            $boardgen = 0;
            $pageno++;
        }
    }
    unshift(@outstr, $class_preamble);
    if ($boardgen > 0) {
        push(@outstr, "showpage");
    }

    my($fh) = IO::File->new();
    if (!$fh->open($of, ">")) {
        die("Failed to open $of $!\n");
    }
    $fh->print(join("\n", @outstr), "\n");
    $fh->close();
}

our($portpre) =<< 'EOF';
%! (c) 2013 Paul Haffenden.
%% prints out 16 hands per page, optionally with makeable contracts
%%
/mm { 2.834 mul } def
/fontsize 8 def
/timesfont {/Times-Roman findfont fontsize scalefont setfont } def
/symbolfont {/Symbol findfont fontsize scalefont setfont } def

/spade { symbolfont (\252) show timesfont } def
/heart {
        symbolfont currentrgbcolor 255 0 0 setrgbcolor (\251) show
        setrgbcolor timesfont }        def
/diamond {
        symbolfont currentrgbcolor 255 0 0 setrgbcolor (\250) show
        setrgbcolor timesfont } def

/club { symbolfont (\247) show timesfont } def

%% The top of the page
/top 297 mm def

%% The gap to leave at the top of the page
/topmargin 5 mm def
%% The gap to leave to the left of the page
/leftmargin 5 mm def

/bottommargin 5 mm def

%% Where the top of the top box appears.
/topoftable top topmargin sub def


%% the width of each 'hand' box. We fit 2 across an A4 sheet.
/xsize 100 mm def
%% The height of each 'hand' box. We fit 8 into an A4 sheet.
/ysize 36 mm def

/gap 2.9 mm def

/nsoff 43 mm def
/eoff 65 mm def
/suitoff 2 mm def
% inner box x offset
/inx 45 mm def
%% inner box y offset
/iny 13 mm def 

/insx 10 mm def
/insy 10 mm def

% center the inner box text
/centerib {

  dup
  stringwidth
  pop
  2
  div

  insx
  2
  div
  inx add

  exch

  sub
} def



%% return y based on the line argument.
/line {
  gap mul ysize exch sub
} def



/row2off {
  1 add ysize mul
  topoftable
  exch
  sub
} def

/col2off {
  xsize
  mul
  leftmargin
  add
} def



/drawbox {
  gsave
    %% eats up x and y
    translate
    %% draw the box
    newpath  
    0 0 moveto
    0 ysize lineto
    xsize ysize lineto
    xsize 0 lineto
    closepath
    1 setlinewidth
    stroke

    %% pop in the central box
    newpath
    inx iny moveto
    inx iny insy add lineto
    inx insx add iny insy add lineto
    inx insx add iny lineto
    closepath
    2 setlinewidth
    stroke

    (Board) centerib 6 line moveto show
    centerib 7 line moveto show

    suitoff 2 line moveto (Dealer: ) show show
    suitoff 3 line moveto (Vul: ) show show
    %
    %
    nsoff 1 line moveto spade show
    nsoff 2 line moveto heart show
    nsoff 3 line moveto diamond show
    nsoff 4 line moveto club show
    eoff 5 line moveto spade show
    eoff 6 line moveto heart show
    eoff 7 line moveto diamond show
    eoff 8 line moveto club show
    nsoff 9 line moveto spade show
    nsoff 10 line moveto heart show
    nsoff 11 line moveto diamond show
    nsoff 12 line moveto club show
    suitoff 5 line moveto spade show
    suitoff 6 line moveto heart show
    suitoff 7 line moveto diamond show
    suitoff 8 line moveto club show

  grestore
} def



%
% This is the makeable contracts handling
%

% x origin
/makex 84 mm def
% y origin
/makey 1.2 mm def
% width of each entry
/makexsize 2.5 mm def
% height of each entry
/makeysize 2 mm def


/row2make {
  4 exch
  sub
  makeysize
  mul
  makey
  add
} def

/col2make {
  makexsize
  mul
  makex
  add
  makexsize
  2
  div
  add
  1
  index
  stringwidth
  pop
  2
  div
  sub
} def

/smallfontsize 7 def
/smalltimes {/Times-Roman findfont smallfontsize scalefont setfont } def
/smallsymbol {/Symbol findfont smallfontsize scalefont setfont } def

/smallspade { smallsymbol (\252) } def
/smallheart {
        smallsymbol (\251) 
        } def
/smalldiamond {
        smallsymbol (\250)  } def

/smallclub { smallsymbol (\247) } def


/red { 
  currentrgbcolor 255 0 0 setrgbcolor
  3
  index
  show
  setrgbcolor
  pop
} def

/makes {
  gsave
    translate
    smalltimes
    (N) 0 col2make 1 row2make moveto show
    (S) 0 col2make 2 row2make moveto show
    (E) 0 col2make 3 row2make moveto show
    (W) 0 col2make 4 row2make moveto show

    smallclub 1 col2make 0 row2make moveto show smalltimes
    smalldiamond 2 col2make 0 row2make moveto red smalltimes
    smallheart 3 col2make 0 row2make moveto red smalltimes 
    smallspade 4 col2make 0 row2make moveto show smalltimes
    (N) 5 col2make 0 row2make moveto show

    1 col2make 1 row2make moveto show
    2 col2make 1 row2make moveto show
    3 col2make 1 row2make moveto show
    4 col2make 1 row2make moveto show
    5 col2make 1 row2make moveto show

    1 col2make 2 row2make moveto show
    2 col2make 2 row2make moveto show
    3 col2make 2 row2make moveto show
    4 col2make 2 row2make moveto show
    5 col2make 2 row2make moveto show

    1 col2make 3 row2make moveto show
    2 col2make 3 row2make moveto show
    3 col2make 3 row2make moveto show
    4 col2make 3 row2make moveto show
    5 col2make 3 row2make moveto show

    1 col2make 4 row2make moveto show
    2 col2make 4 row2make moveto show
    3 col2make 4 row2make moveto show
    4 col2make 4 row2make moveto show
    5 col2make 4 row2make moveto show

    grestore
} def

EOF


sub port
{
    my($self) = shift();
    my($of) = @_;
    my($bn);
    my($top);
    my($suit);
    my($hand);
    my(@outstr);
    my($needpage) = 1;
    my($boardgen) = 0;
    $top = $self->gettop();

 BOARD:
    for ($bn = 1; $bn <= $top; $bn++) {
        if (!$self->validboard($bn)) {
            next;
        }
        if ($needpage) {
            push(@outstr, "timesfont");
            $needpage = 0;
        }

        push(@outstr, "%% Board number $bn");
        # Now we want the clubs
        foreach $hand (PBN_WEST, PBN_SOUTH, PBN_EAST, PBN_NORTH) {
            foreach $suit (PBN_CLUBS, PBN_DIAMONDS, PBN_HEARTS, PBN_SPADES) {
                my($key) = $handlookup->{$hand} . $suitlookup->{$suit};
                my($val) = $self->getstr($bn, $hand, $suit);
                if ($val eq "") {
                    $val = "-";
                }
                if (length($val) < 8) {
                    $val =~ s/(.)/$1 /g;
                    $val =~ s/T/10/;
                    $val =~ s/ $//;
                }
                push(@outstr, "($val)");
            }
        }
        # vul
        push(@outstr, "(" . Board->vulstr($bn) . ")");
        push(@outstr, "(" . Board->dealstr($bn) . ")");
        # dealer
        # bno
        push(@outstr, "($bn)");
        my($col) = $boardgen % 2;
        my($row) = int ($boardgen / 2);
        push(@outstr, $col, "col2off", $row, "row2off drawbox");

        # See if we have any makeable contracts
        if ($self->havemake($bn)) {
            foreach $hand ("w", "e", "s", "n") {
                foreach $suit ("n", "s", "h", "d", "c") {
                    my($val) = $self->makecontracts($bn, $hand, $suit);
                    if ($val < 7) {
                        $val = "-";
                    } else {
                        $val = $val - 6;
                    }
                    push(@outstr, "($val)");
                }
            }
            push(@outstr, $col, "col2off", $row, "row2off makes");
        }

        $boardgen++;
        if ($boardgen >= 16) {
            push(@outstr, "showpage");
            $needpage = 1;
            $boardgen = 0;
        }
    }
    unshift(@outstr, $portpre);
    if ($boardgen > 0) {
        push(@outstr, "showpage");
    }

    my($fh) = IO::File->new();
    if (!$fh->open($of, ">")) {
        die("Failed to open $of $!\n");
    }
    $fh->print(join("\n", @outstr), "\n");
    $fh->close();
}

sub pbnsave
{
    my($self) = shift();
    my($fname) = @_;
    my($fh) = IO::File->new();

    if (!$fh->open($fname, ">")) {
        die("Failed to open output file $fname $!\n");
    }
    my($bno);
    my($ent);
    $bno = 0;
    foreach $ent (@{$self->{boards}}) {
        $bno++;
        next if !defined($ent);
        $self->pbnout($fh, $bno, $ent);
    }
}

our($deal) =
[
 "N",
 "E",
 "S",
 "W",
];

our($dlookup) =
[
 {},
 {N => "E", E => "S", S => "W", W => "N" },
 {N => "S", E => "W", S => "N", W => "E" },
 {N => "W", E => "N", s => "E", W => "S" },
];
sub dealer
{
    my($self) = shift;
    my($bno) = @_;
    my($ind) = ($bno - 1) % 4;
    return $deal->[$ind];
}

our($vul) =
[
 "Neither",  # 1
 "NS",       # 2
 "EW",       # 3
 "Both",     # 4
 "NS",       # 5
 "EW",       # 6
 "Both",     # 7
 "Neither",  # 8
 "EW",       # 9
 "Both",     # 10
 "Neither",  # 11
 "NS",       # 12
 "Both",     # 13
 "Neither",  # 14
 "NS",       # 15
 "EW",       # 16
];

our($vlookup) =
[
 {},
 { NS => "EW", EW => "NS", Both => "Both", Neither => "Neither" },
 { NS => "NS", EW => "EW", Both => "Both", Neither => "Neither" },
 { NS => "EW", EW => "NS", Both => "Both", Neither => "Neither" },
];

sub vul
{
    my($self) = shift();
    my($bno) = @_;
    my($ind) = ($bno - 1) % 16;
    return $vul->[$ind];
}


sub pbnout
{
    my($self) = shift;
    my($fh, $bno, $ent) = @_;

    $fh->print(qq/[Event "?"]\n[Site "?"]\n[Date "?"]\n/);
    $fh->print(qq/[Board "$bno"]\n/);
    $fh->print(qq/[West "?"]\n[North "?"]\n[East "?"]\n[South "?"]\n/);
    $fh->print(qq/[Dealer "/, $self->dealer($bno), qq/"]\n/);
    $fh->print(qq/[Vulnerable "/, $self->vul($bno), qq/"]\n/);
    $fh->print(qq/[Deal "N:/, join(" ", map({ join(".", @{$_}) } @$ent)), qq/"]\n/);
    $fh->print(qq/[Scoring "?"]\n[Declarer "?"]\n[Contract "?"]\n[Result "?"]\n\n/);
}


# remove
#
# Takes a list of boardnumbers to remove.
sub remove
{
    my($self) = shift();
    my(@bnos) = @_;

    my($look) = {};
    my($bno);

    foreach $bno (@bnos) {
        $look->{$bno} = 1;
    }

    my($ent);
    $bno = 0;
    foreach $ent (@{$self->{boards}}) {
        $bno++;
        if (!exists($look->{$bno})) {
            $ent = undef;
        }
    }
}

# Given a board number, return an array ref of 52 entries. giving the 
# position of each card, 0 == north, 1 == east, 2 == south, 3 == west.
# The index into the array gives the card, 0 = Aces of spades, 1 = king, ..
# 13 = Ace of hearts, then diamonds and then clubs.

my($cardlookup) = {
                   a => 0,
                   A => 0,
                   k => 1,
                   K => 1,
                   q => 2,
                   Q => 2,
                   j => 3,
                   J => 3,
                   t => 4,
                   T => 4,
                   9 => 5,
                   8 => 6,
                   7 => 7,
                   6 => 8,
                   5 => 9,
                   4 => 10,
                   3 => 11,
                   2 => 12
};
sub playerpos
{
    my($self) = shift;
    my($bno) = @_;
    my($reta) = [];
    my($ent) = $self->{boards}->[$bno];
    if (!defined($ent)) {
        die("Can't find board $bno as requested in playerpos\n");
    }
    my($hand, $suit);
    foreach $hand (PBN_NORTH, PBN_EAST, PBN_SOUTH, PBN_WEST){
        foreach $suit (PBN_SPADES, PBN_HEARTS, PBN_DIAMONDS, PBN_CLUBS) {
            my($val) = $self->getstr($bno, $hand, $suit);
            my($rank);
            # We want to yomp along the string.
            print("val is $val\n");
            foreach $rank (split("", $val)) {
                print("rank is $rank\n");
                my($ind);
                $ind = $suit * 13 + $cardlookup->{$rank};
                $reta->[$ind] = $hand;
            }
        }
    }
    return $reta;
}



1;
