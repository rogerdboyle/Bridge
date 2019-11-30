#############
package Biff;
#############

# $Id: Biff.pm 928 2012-06-16 08:39:28Z phaff $
#
# Code to decode a Palm biff file

use strict;
use warnings;
use IO::File;

use Conf;
use lib "lib";
use Single;

use constant MAXPAIRS => 40;
use constant MAXBOARDS => 40;
# some important offsets into the r0 data array

use constant NOB => 5;
use constant BPR => 6;
#use constant EWPAIRS => 12;
use constant MOVEID => 2;
use constant MYPAIR => 7;
use constant MISSPAIR => 9;
use constant MAGIC => (ord('K') << 24) | (ord('A') << 16) | (ord('T') << 8) |
  ord('E');

# The file beamed from the palm consists of 3 records.
# r0 comes first and contains:
#
# typedef struct record0 {
#  UInt32 magic;4
#  UInt32 ver;8
#  UInt32 movementid;12
#  UInt16 formID;14

#  UInt8  round;15
#  UInt8  nob; // number of boards. 16
#  UInt8  bpr; // boards per round. 17
#  UInt8  mypair; 18
#  UInt8  bno; // Current board number. 19
#  UInt8  mpair; // The missing pair for half table movements 20
#  UInt16 flags; // control bits
#
# } record0_t;

# struct board2pairs {
#  UInt8 nspair;
#  UInt8 ewpair;
#};
# Does pair number selection based on boards per round.
#typedef struct record1 {
#  struct board2pairs boardpairs[MAXBOARDS];
#} record1_t;

#struct result {
#(0)  UInt8  type;  // type of result, 0 == normal, 1 == Pass out 2 == adjusted
#(1)  UInt8  ns;    // The North/South pair number.
#(2)  UInt8  ew;    // The East/West pair number.
#(3)  UInt8  level; // Contract level 1-7
#(4)  UInt8  csuit; // Contracted suit 'C', 'D', 'H', 'S', 'N'
#(5)  UInt8  pen;   // Penalty (dbl,redouble etc) ' ', 'D', 'R'
#(6)  UInt8  by;    // declarer. 'N','E', 'S' 'W'
#(7)  UInt8  rank;  // Rank of the card lead '2' - '9', 'T' - 'A' 'x'
#(8)  UInt8  lsuit; // Suit lead 'C' 'D' 'H' 'S'
#(9)  UInt8  tricks;// 0-13
#(10) UInt8  nsadj; // adjusted percentage score
#(11) UInt8  ewadj; // adjusted percentage score
#(12) UInt8  state; // If it is valid.
#(13) UInt16 teamscore; // The points scored by our teammates

#};


# Constant offsets into the r2 record (struct result)
use constant TYPE   => 0;
use constant NS     => 1;
use constant EW     => 2;
use constant LEVEL  => 3;
use constant CSUIT  => 4;
use constant PEN    => 5;
use constant BY     => 6;
use constant RANK   => 7;
use constant LSUIT  => 8;
use constant TRICKS => 9;
use constant NSADJ  => 10;
use constant EWADJ  => 11;
use constant STATE  => 12;

sub new
{
    my($class) = shift();

    my($self) = {};
    bless($self, $class);
    return ($self);
}

sub load
{
    my($self) = shift();
    my($fname) = @_;
    my($fh) = IO::File->new();
    my($pdb);
    my($aref) = [];
    # The player hash
    my($phash) = {};

    $self->{fname} = $fname;

    # We just use the file suffix to determine if we
    # need to use the database module.
    if ($fname =~ m/\.pdb$/i) {
        # Only pull in the required modules
        # if we need to use them.
        require Palm::Raw;
        import Palm::Raw;
        print("Assumming a database file\n");
        $pdb = Palm::Raw->new();
        $pdb->Load($fname);

        my($n);
        my($r0fmt);
        my($r2fmt);
        my($r0sz);
        my($r2sz);
        my($r3sz);
        my($r3fmt);
        my($maxpairs) = MAXPAIRS;
        my($data);
        my($i);

        $r2sz = 16;
        $r3sz = 4;
        $r3fmt = "nn";

        $data = $pdb->{records}->[0]->{data};
        $r0fmt = "NNNnCCCCCCn";

        my(@data) = unpack($r0fmt, $data);

        if ($data[0] != MAGIC) {
            die("The magic number has not been detected\n");
        }
        my($nob) = $data[NOB];
        $self->{nob} = $nob;
        $self->{moveid} = $data[MOVEID];
        $self->{bpr} = $data[BPR];
        $self->{misspair} = $data[MISSPAIR];
        $self->{mypair} = $data[MYPAIR];


        print("Number of boards: $nob\n",
              "moveid: $data[MOVEID]\n",
              "bpr: $data[BPR]\n",
              "missing pair $data[MISSPAIR]\n",
              "mypair $data[MYPAIR]\n");



        $r2fmt = "C14n";
        for ($i = 0; $i < $nob; $i++) {
            my($inaref) = [];
            $aref->[$i] = $inaref;

            $data = substr($pdb->{records}->[2]->{data}, $i * $r2sz, $r2sz);
            @data = unpack($r2fmt, $data);


            print("data is:\n");
            foreach my $char (@data) {
                printf("0x%x ", $char);
            }
            print("\n");

            # This is set to true for valid entries
            next if !$data[STATE];
            my($pen);

            if ($data[PEN] == 0) {
                $pen = "";
            } elsif ($data[PEN] == 1) {
                $pen = "*";
            } elsif ($data[PEN] == 2) {
                $pen = "**";
            } else {
                die("Illegal penalty value for board ", $i + 1, "\n");
            }

            my($instr);
            # This is the type field
            $inaref->[0] = $data[NS];
            if ($data[TYPE] == 0) {
                my($csuit);
                my($rtricks); # the relative number of tricks.
                my($by);
                my($lead);
                my($lsuit);

                $rtricks = $data[TRICKS] - ($data[LEVEL] + 6);
                if ($rtricks == 0) {
                    $rtricks = "";
                }
                # We store all data in the db file in lower case.
                $csuit = lc(chr($data[CSUIT]));
                $by = lc(chr($data[BY]));
                $lead = lc(chr($data[RANK]));
                $lsuit = lc(chr($data[LSUIT]));
                $instr =
                  "$data[NS] $data[EW] $data[LEVEL]$csuit$pen$rtricks " .
                    "$by $lead$lsuit";
            } elsif ($data[TYPE] == 1) {
                # Passed out;
                $instr = "$data[NS] $data[EW] p";
            } elsif ($data[TYPE] == 2) {
                $instr = "$data[NS] $data[EW] a";
                my($adj);
                $adj = $self->adjchar($data[NSADJ]);
                $adj .= $self->adjchar($data[EWADJ]);
                if ($adj ne "==") {
                    $instr .= $adj;
                }
            } else {
                die("Unknown type ($data[TYPE]) on board ", $i + 1, "\n");
            }
            $inaref->[1] = $instr;
        }
        # The player decode.
        my($lookplay) = [ "N", "E", "S", "W" ];
        for ($i = 0; $i < 4; $i++) {
            $data = substr($pdb->{records}->[3]->{data}, $i * $r3sz, $r3sz);
            @data = unpack($r3fmt, $data);
            if ($data[0]) {
                $phash->{$lookplay->[$i]} = $data[1];
            }
        }
    } else {
        if (!$fh->open($fname, "<")) {
            die("Failed to open the biff file $fname $!\n");
        }
        my($line);
        while ($line = $fh->getline()) {
            chomp($line);
            my($id, $d) = $line =~ m/^(.)=(.*)/;
            if (!defined($id)) {
                next;
            }
            if ($id eq "r") {
                $self->{rev} = $d;
            } elsif ($id eq "m") {
                $self->{moveid} = $d;
            } elsif ($id eq "b") {
                $self->{bpr} = $d;
            } elsif ($id eq "n") {
                $self->{nob} = $d;
            } elsif ($id eq "p") {
                $self->{mypair} = $d;
            } elsif ($id eq "M") {
                $self->{misspair} = $d;
            } elsif ($id eq "i") {
                my($inaref) = [];
                my($instr);
                my($ind);
                my($key);
                $d = lc($d);
                my(@f) = split(m/\s+/, $d);
                $ind = $f[0];
                $inaref->[0] = $f[1];
                $instr = "$f[1] $f[2]";
                if ($f[3] eq "a") {
                    $instr .= " " . "a" . $self->adjchar($f[4]) .
                      $self->adjchar($f[5]);
                    $key = $instr;
                } elsif ($f[3] eq "p") {
                    $instr .= " p";
                    $key = $instr;
                } else {
                    shift(@f);
                    shift(@f);
                    shift(@f);
                    $key = $instr;
                    $instr .= " " . join(" ", @f);

                    # Leave the card lead off
                    pop(@f);
                    $key .= " " . join(" ", @f);
                }
                $inaref->[1] = $instr;
                $inaref->[2] = $key;
                $aref->[$ind - 1] = $inaref;
            } elsif ($id eq "P") {
                my(@f) = split(m/\s+/, $d, -1);
                if (scalar(@f) != 2) {
                    die("I have a player entry with more that 2 fields " .
                        "($line)\n");
                }
                if ($f[0] !~ m/[NSEW]/) {
                    die("The player identifier is not one of N,E,S or W " .
                        "($f[0])\n");
                }
                $phash->{$f[0]} = $f[1];
            }
        }
    }
    $self->{aref} = $aref;
    $self->{phash} = $phash;
}

sub adjchar
{
    my($self) = shift();
    my($char) = @_;

    if ($char < 10) {
        die("Adjusted score less than 10 ($char)\n");
    }
    if ($char > 90) {
        die("Adjusted score greater than 90 ($char)\n");
    }
    if ($char % 10) {
        die("Adjusted score not a multiple of 10 ($char)\n");
    }
    if ($char == 50) {
        return ("=");
    } elsif ($char > 50) {
        return ("+");
    } else {
        return ("-");
    }
}

# This isn't a method, but a plain function.
sub merge
{
    my($fh, $biffs, $mc, $pairmap) = @_;
    my($nob) = $biffs->[0]->{nob};
    my($i);

    for ($i = 0; $i < $nob; $i++) {
        $fh->print("board=", $i + 1, "\n");
        my($instr);
        my($biff);
        my($check) = {};
        foreach $biff (@$biffs) {
            if (defined($biff->{aref}->[$i]) &&
              scalar(@{$biff->{aref}->[$i]})) {
                my($aref) = $biff->{aref}->[$i];
                if (exists($check->{$aref->[0]})) {
                    if (!exists($check->{$aref->[0]}->{$aref->[2]})) {
                        $fh->print("instr=$aref->[1]\n");
                        $check->{$aref->[0]}->{$aref->[2]} = 1;
                        print("Warning: mismatched result ($aref->[1]) ",
                            "board number ",
                            $i + 1, "\n");
                        my(@keys) = keys(%{$check->{$aref->[0]}});
                        print("With keys:\n");
                        foreach my $key (@keys) {
                            print("($key)\n");
                        }
                    }
                } else {
                    $fh->print("instr=$aref->[1]\n");
                    if (defined($aref->[2])) {
                        $check->{$aref->[0]}->{$aref->[2]} = 1;
                    }
                }
            }
        }
    }

    # Can only look up the players if we have a movement specifed
    if (defined($mc)) {

        # Now we have to handle the player data.
        # So we can check a player is only reffed once.
        my($oneplayer) = {};

        # Get the 1st round table entries.
        my($tables) = $mc->{rndctl}->[0]->{tables};
        my($single) = Single->new();
        my($ret) = $single->load("contact.csv");
        if ($ret) {
            die("Failed to load the player database\n");
        }

    BIFF:
        foreach my $biff (@$biffs) {
            my($tbl, $moveid, $isns, $item, $ns, $ew, $play, $id0, $id1);

            $moveid = $biff->{moveid};
            use integer;
            $tbl = $moveid % 1000;
            $tbl /= 10;
            $isns = $moveid % 10;

            $item = $tables->[$tbl - 1];
            $ns = $item->{ns};
            $ew = $item->{ew};

            my($chpair);
            if ($isns) {
                $chpair = $ns;
            } else {
                $chpair = $ew;
            }
            if ($chpair != $biff->{mypair}) {
                die("The pair calculated from the movement number ($chpair) ",
                    "does not match the pair specified in the biff file ",
                    "$biff->{mypair}\n");
            }
            $play = $biff->{phash};
            foreach my $key ("N", "E", "S", "W") {
                if (exists($play->{$key})) {
                    if (exists($oneplayer->{$play->{$key}})) {
                        print("The same player ($key) has been specifed more ",
                              "than once\n");
                        last BIFF;
                    }
                    $oneplayer->{$play->{$key}} = 1;
                }
            }
            $id0 = 0;
            $id1 = 0;

            if (exists($play->{N})) {
                $id0 = $play->{N};
            }
            if (exists($play->{S})) {
                $id1 = $play->{S};
            }
            if ($id0 && $id1) {
                $pairmap->addpair($ns, $id0, $id1);
            }

            $id0 = 0;
            $id1 = 0;

            if (exists($play->{E})) {
                $id0 = $play->{E};
            }
            if (exists($play->{W})) {
                $id1 = $play->{W};
            }
            if ($id0 && $id1) {
                $pairmap->addpair($ew, $id0, $id1);
            }
        }
    }
}
1;
