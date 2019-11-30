# handle pbn files.


# All we want to know about a pbn entry.
###############
package PBNent;
###############
use Exporter;
our(@ISA) = qw(Exporter);
use constant NORTH => 0;
use constant EAST => 1;
use constant SOUTH => 2;
use constant WEST => 3;

use constant SPADES => 0;
use constant HEARTS => 1;
use constant DIAMONDS => 2;
use constant CLUBS => 3;

our(@EXPORT) = qw(&NORTH &EAST &SOUTH &WEST &SPADES &HEARTS &DIAMONDS &CLUBS);
my(@acc) = qw(
             startl
             endl
             dealerl
             vull
             deall
             bno
             deal
             vul
             dealer
             ddealer
            );

{
    no strict 'refs';
    foreach my $sym (@acc) {
        *{$sym} = sub {
            my($self) = shift;
            my($in) = @_;
            my($old);
            $old = $self->{$sym};
            $self->{$sym} = $in if defined($in);
            return $old; };
    }
}


sub new
{
    my($class) = shift();
    my($self) =
      {
       startl => -1,
       endl => -1,
       dealerl => -1,
       vull => -1,
       deall => -1,
       bno => 0,
       deal => [ [], [], [], [] ],
       vul => "",
       dealer => ""
      };
    bless($self, $class);
    return $self;
}

sub rotate
{
    my($self) = shift();
    my($rot) = @_; # number of clockwise rotations.
    if ($rot == 0) {
        return;
    }
    my($r) = $rot;
    while ($r > 0) {
        my($tmp) = pop(@{$self->{deal}});
        unshift(@{$self->{deal}}, $tmp);
        $r--;
    }
    my($dn) = $self->dealer_number();
    $dn += $rot;
    $dn %= 4;
    # New dealer.
    $self->dealer(number_dealer($dn));
    my($vul) = $self->vul();

    print("Old vul is $vul\n");
    if ((($rot %2) == 1) && ($vul ne "None") && ($vul ne "All")) {
        if ($vul eq "NS") {
            $vul = "EW";
        } else {
            $vul = "NS";
        }
        $self->vul($vul);
    }
    print("New vul is $vul\n");
}

sub number_dealer
{
    my($num) = @_;
    if ($num == NORTH) {
        return "N";
    } elsif ($num == EAST) {
        return "E";
    } elsif ($num == SOUTH) {
        return "S";
    } elsif ($num == WEST) {
        return "W";
    } else {
        die("Unknown dealer number $num\n");
    }
}

sub dealer_number
{
    my($self) = shift();
    my($d) = $self->dealer();
    if ($d eq "N") {
        return NORTH;
    } elsif ($d eq "E") {
        return EAST;
    } elsif ($d eq "S") {
        return SOUTH;
    } elsif ($d eq "W") {
        return WEST;
    } else {
        die("Unknown dealer $d\n");
    }
}

##################
package Exportpbn;
##################
use strict;
use warnings;
use IO::File;
use Data::Dumper;
use Exporter;

PBNent->import;

our(@ISA) = qw(Exporter);
our(@EXPORT) = qw(&NORTH &EAST &SOUTH &WEST &SPADES &HEARTS &DIAMONDS &CLUBS);

sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    $self->{lines} = [];
    $self->{pbnents} = {};
    $self->{endpre} = -1; # The last line index of the preamble
    return ($self);
}


sub load
{
    my($self) = shift();
    my($fname) = @_;
    my($line);
    my($fh) = IO::File->new();

    if (!$fh->open($fname, "<:crlf")) {
        die("Failed to open $fname $!\n");
    }
    my($ind) = -1;
    my($lines) = $self->{lines};
    my($pre) = 1;
    my($pbnents) = $self->{pbnents};
    my($starti);
    my($mbno);
    my($d);
    my($ent);
    my($deal);
    my($vul);

    while ($line = $fh->getline()) {
        chomp($line);
        push(@$lines, $line);
        $ind++;

        if ($line =~ m/^\[Event /) {
            if ($pre) {
                $self->{endpre} = $ind - 1;
                $pre = 0;
            }
            if (defined($ent)) {
                $ent->endl($ind - 1);
                $self->insert($ent);
            }
            $ent = PBNent->new();
            $ent->startl($ind);
            next;
        }
        if (($mbno) = $line =~ m/^\[Board\s*"(\d+)"/) {
            print("Found [Board line] ($line)\n");
            if (!defined($ent)) {
                print("ent is not defined\n");
                $ent = PBNent->new();
                $ent->startl($ind);
            } else {
                if ($ent->bno() != 0) {
                    # I've ready seen a Board line, but without an Event!
                    if ($pre) {
                        $self->{endpre} = $ind - 1;
                        $pre = 0;
                    }
                    $ent->endl($ind - 1);
                    $self->insert($ent);
                    $ent = PBNent->new();
                    $ent->startl($ind);
                }
            }
            $ent->bno($mbno);
            next;
        }
        if (($d) = $line =~ m/^\[Dealer\s*"([NSEW])"/) {
            $ent->dealerl($ind);
            $ent->dealer($d);
            next;
        }
        if (($deal) = $line =~ m/^\[Deal\s*"([^"]+)"/) {
            $ent->deall($ind);
            my($ddealer, $other, @fields);
            ($ddealer, $other) = split(":", $deal);
            @fields = split(" ", $other);
            if (scalar(@fields) != 4) {
                die("Failed to split the deal line into 4\n");
            }
            $ent->ddealer($ddealer);
            my($rot);
            if ($ddealer eq "N") {
                $rot = 0;
            } elsif ($ddealer eq "E") {
                $rot = 3;
            } elsif ($ddealer eq "S") {
                $rot = 2;
            } elsif ($ddealer eq "W") {
                $rot = 1;
            } else {
                die("Deal dealer is not legal $ddealer\n");
            }
            while ($rot > 0) {
                my($tmp) = shift(@fields);
                push(@fields, $tmp);
                $rot--;
            }
            $ent->deal([map {[ split(/\./, $_, 4) ]; } @fields]);
            next;
        }

        if (($vul) = $line =~ m/^\[Vulnerable\s*"([^"]+)"/) {
            $ent->vull($ind);
            $ent->vul($vul);
            next;
        }
    }
    if (defined($ent)) {
        $ent->endl($ind - 1);
        $self->insert($ent);
    }
}

# You can ask for all the hands to a board,
# by specifing just the board number, in which case you
# get returned an array of arrays of strings.
# Or you can ask for a players hand, by specifing board number
# and player, which returns an array of 4 strings.
# Or you can ask for a suit, by passing board number, player
# and suit


sub insert
{
    my($self) = shift();
    my($ent) = @_;

    my($bno) = $ent->bno();
    if ($bno == 0) {
        die("Attempting insert with a bno of $bno\n");
    }
    if (exists($self->{pbnents}->{$bno})) {
        die("Insert failed with duplicate of $bno\n");
    }
    print("Inserting $bno\n");
    $self->{pbnents}->{$bno} = $ent;
}

sub hand
{
    my($self) = shift();
    my(@args) = @_;
    if (@args == 1) {
        return $self->{pbnents}->{$args[0]}->deal();
    } elsif (@args == 2) {
        return $self->{pbnents}->{$args[0]}->deal()->[$args[1]];
    } else {
        return $self->{pbnents}->{$args[0]}->deal()->[$args[1]]->[$args[2]];
    }
}

sub validboard
{
    my($self) = shift();
    my($bno) = @_;
    if (exists($self->{pbnents}->{$bno})) {
        return 1;
    }
    return 0;
}

sub bnos
{
    my($self) = shift();
    return (sort({$b <=> $a} keys(%{$self->{pbnents}})))[0];
}

sub save
{
    my($self) = shift;
    my($fname, $renumber) = @_;
    my($fh);
    my($lines) = $self->{lines};

    $fh = IO::File->new();
    if (!$fh->open($fname, ">")) {
        die("Failed to open $fname $!\n");
    }


    # Renumber the boards from 1;
    if ($renumber) {
        print("renumbering\n");
        my($newpbnents) = {};
        my($top) = $self->bnos();
        my($i);
        my($nbno) = 1;
        for ($i = 1; $i <= $top; $i++) {
            if ($self->validboard($i)) {
                my($ent) = $self->{pbnents}->{$i};
                $ent->bno($nbno);
                $newpbnents->{$nbno} = $ent;
                $nbno++;
            }
        }
        $self->{pbnents} = $newpbnents;
    }

    # Write out the preamble, if any.
    print("The end index of the preamble is $self->{endpre}\n");
    if ($self->{endpre} != -1) {
        $fh->print(join("\n", @$lines[0 .. $self->{endpre}]), "\n");
    }

    my($ent);
    my($top) = $self->bnos();
    my($i);
    for ($i = 1; $i <= $top; $i++) {
        if (!$self->validboard($i)) {
            next;
        }
        $ent = $self->{pbnents}->{$i};
        $lines->[$ent->dealerl()] = qq/[Dealer "/ . $ent->dealer() . qq/"]/;
        # 2. Vulnerability
        $lines->[$ent->vull()] = qq/[Vulnerable "/ . $ent->vul() . qq/"]/;
        # 3. the Deal.
        $lines->[$ent->startl()] = qq/[Board "/ . $ent->bno() . qq/"]/;

        my($deal);
        @$deal = @{$ent->deal()};
        my($rot) = 0;
        if ($ent->dealer() eq "N") {
            $rot = 0;
        } elsif ($ent->dealer() eq "E") {
            $rot = 1;
        } elsif ($ent->dealer() eq "S") {
            $rot = 2;
        } elsif ($ent->dealer() eq "W") {
            $rot = 3;
        } else {
            die("Dealer is not one of N,S,E,W but ", $ent->dealer(), "\n");
        }
        while ($rot > 0) {
            my($tmp) = shift(@$deal);
            push(@$deal, $tmp);
            $rot--;
        }
        $lines->[$ent->deall()] =
          qq/[Deal "/ .
            $ent->dealer() .
              ":" . join(" ",map({join(".", @{$_})} @$deal)) .
                qq/"]/;
    }
    # Now print each bno.
    for ($i = 1; $i <= $top; $i++) {
        if (!$self->validboard($i)) {
            next;
        }
        $ent = $self->{pbnents}->{$i};
        my($s, $e);
        $s = $ent->startl();
        $e = $ent->endl();
        $fh->print(join("\n", @$lines[$s .. $e]), "\n");
    }
}

# Given a board number, return an array ref of 52 entries. giving the 
# position of each card, 0 == north, 1 == east, 2 == south, 3 == west.
# The index into the array gives the card, 0 = Aces of spades, 1 = king, ..
# 13 = Ace of hearts, then diamonds and then clubs.

my($cardlookup) = {
                   A => 0,
                   K => 1,
                   Q => 2,
                   J => 3,
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
    if (!defined($self->hand($bno))) {
        die("Can't find board $bno as requested in playerpos\n");
    }
    my($hand, $suit, $rank, $ind, $val);
    foreach $hand (&NORTH, &EAST, &SOUTH, &WEST){
        foreach $suit (&SPADES, &HEARTS, &DIAMONDS, &CLUBS) {
            $val = $self->hand($bno, $hand, $suit);
            # We want to yomp along the string.
            foreach $rank (split("", $val)) {
                $ind = $suit * 13 + $cardlookup->{$rank};
                $reta->[$ind] = $hand;
            }
        }
    }
    return $reta;
}

# remove
#
# Takes a list of boardnumbers to keep.
sub remove
{
    my($self) = shift();
    my(@bnos) = @_;

    my($bno);
    my($top) = $self->bnos();
    my($aref) = $self->{pbnents};

    foreach $bno (@bnos) {
        if (exists($aref->{$bno})) {
            delete($aref->{$bno});
        }
    }
}



1;
