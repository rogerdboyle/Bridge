#
# Store all the info about a movement.
# $Id: Moveconfig.pm 1334 2014-08-24 07:29:41Z root $


#########################
package Move::Moveconfig;
#########################

use strict;
use warnings;

use IO::File;

use Move::Tables;
use Move::Relays;
use Move::Boards;

our(@tablesubs) = qw(ns ew board boardcode nscode ewcode);
our(@relaysubs) = qw(board boardcode);

sub new
{
    my($class) = shift();

    if (@_ != 0) {
        die("Moveconfig->new: wrong args\n");
    }
    my($self) = {};
    return (bless($self, $class));
}

sub setoutput
{
    my($self) = shift();
    my($outfh) = @_;
    $self->{outfh} = $outfh;
}

sub load
{
    my($self) = shift();
    if (@_ != 1) {
        die("Moveconfig->load: wrong args\n");
    }
    my($fh) = @_;
    my($line);
    my($keys) = {};
    my($lc) = 0;
    my($not, $nor, $nos, $bpr);
    my($indesc) = 1;
    my($desc) = "";

    my($tblno) = 0;
    my($relno) = 0;

    while($line = $fh->getline()) {
        $lc++;

        if ($line =~ m/^DESCEND$/) {
            $indesc = 0;
            next;
        }

        if ($indesc) {
            $desc .= $line;
            next;
        }
        next if $line =~ m/^\s*#/; # A comment line.
        next if $line =~ m/^\s*$/; # a blank line.
        chomp($line);
        my($key, $val) = $line =~ m/([^=]+)=(.*)/;
        if (!defined($key)) {
            die("Unable to decode the line ($line) at $lc\n");
        }
        if ($key eq "Table") {
            $tblno = $val;
            $relno = 0;
            next;
        }
        if ($key eq "Relay") {
            $relno = $val;
            $tblno = 0;
            next;
        }

        if ($key =~ m/^(ns|ew|board|boardcode|nscode|ewcode|share|sharecode|nsdir|ewdir)$/) {
            if ($tblno) {
                $key = "T$tblno" . $key;
            } elsif ($relno) {
                $key = "R$relno" . $key;
            } else {
                die("Neither a table or relay number has been set\n");
            }
        }

        if (exists($keys->{$key})) {
            die("Duplicate key value ($key) at line $lc\n");
        }
        # First try to substitute any value starting with a '$'
        if (substr($val, 0, 1) eq '$') {
            # Make new key for lookup.
            my($subkey) = substr($val, 1);
            if (exists($keys->{$subkey})) {
                # Bingo, replace val with this value.
                $val = $keys->{$subkey};
            } else {
                die("I don't know key ($subkey) at line $lc\n");
            }
        }
        $keys->{$key} = $val;
    }
    $self->{desc} = $desc;
    if (!exists($keys->{rounds})) {
        die("The rounds key is missing\n");
    }
    $self->{rounds} = $keys->{rounds};
    # The keys have the following format.
    # ns= on table x set the n/s pair
    # ew= on table x set the e/w pair
    # nscode= the movement code for the n/s pair
    # ewcode= the movement code for the e/w pair
    # board= Set the boards.
    # boardcode=

    # share= which table do we share
    # sharecode

    # bpr= number of boards per round!

    my($tbls);
    my($rels);
    my($bds);

    # Locate all of the table entries;
    $tbls = Move::Tables->new($self, keycheck($keys, "T", \@tablesubs));
    $not = $tbls->num();

    $self->{trav} = {};
    $self->{not} = $not;
    $self->{tables} = $tbls;

    $rels = Move::Relays->new($self, keycheck($keys, "R", \@relaysubs));
    $nor = $rels->num();

    $self->{nor} = $nor;
    $self->{relays} = $rels;


    # Work out the number of boards sessions.
    ($nos, $bpr) = $self->sessioncalc($keys);

    $self->{bpr} = $bpr;
    $self->{nos} = $nos;
    $bds = Move::Boards->new($self);
    $self->{boards} = $bds;

    if (exists($keys->{rnddesc})) {
        $self->{rnddesc} = $keys->{rnddesc};
    }
    if (exists($keys->{maxrounds})) {
        $self->{maxrounds} = $keys->{maxrounds};
    }

    $self->settables($keys);
    $self->setrelays($keys);
    $self->{id} = $keys->{id};
    if (exists($keys->{maxplay})) {
        $self->{maxplay} = $keys->{maxplay};
    }
}

# Get the control structure for a particular round.
sub get_ctltbl
{
    my($self) = shift();
    my($rnd) = @_;
    my($ctl) = $self->{rndctl}->[$rnd - 1];
    if (!defined($ctl)) {
        die("Failed to select the control item. Perhaps the argument $rnd is too large\n");
    }
    return ($ctl->{tables});
}

sub generate
{
    my($self) = shift();
    my($roundlimit) = @_;
    my($round);
    my($rounds);

    $self->{winners} = 0;
    $self->{rndctl} = [];
    # An entry for each pair that plays.
    # Each entry is an array of two items,
    # The first the number of times played ns
    # the second the number players ew.
    $self->{pairs} = {};
    $self->{ops} = {}; #  record opponent counts

    if ($roundlimit) {
        if ($roundlimit > $self->get_maxrounds()) {
            die("You have specified a round limit ($roundlimit) ",
                "greater than the number of rounds (",
                $self->get_rounds(), ") in the setup file\n");
        }
        $rounds = $roundlimit;
    } else {
        $rounds = $self->get_rounds();
    }
    $round = 1;
    $self->{round} = $round;
    $self->printtables();

    while ($round < $rounds) {
        $round++;
        $self->{round} = $round;
        $self->runupdate();
        $self->printtables();
    }
    $self->printtravs();

    # Now set winners by looking at the pairs hash.
    my($pairs) = $self->{pairs};
    my($val);
    my($win) = 2;
    while ((undef, $val) = each(%$pairs)) {
        if (($val->[0] > 0) && ($val->[1] > 0)) {
            # This pair has played both ways, so
            # this can only be a one player movement.
            $win = 1;
            last;
        }
    }
    $self->{winners} = $win;
    print("Number of winners $win\n") if $self->{outfh};
    if (($win == 2) && $self->{fixew} ) {
        $self->fixew_display();
    }
}

sub get_winners
{
    my($self) = shift();
    return ($self->{winners});
}

# Return number of tables.
sub get_not
{
    my($self) = shift();
    return ($self->{not});
}

# Return number of board 'sessions'
sub get_nos
{
    my($self) = shift();
    return ($self->{nos});
}

# Return the id of the movement.
sub get_id
{
    my($self) = shift();
    return ($self->{id});
}

# Return number of relays
sub get_nor
{
    my($self) = shift();
    return ($self->{nor});
}

# Return the tables object
sub get_tables
{
    my($self) = shift();
    return ($self->{tables});
}
# Return the relays object
sub get_relays
{
    my($self) = shift();
    return ($self->{relays});
}

# Return the boards object
sub get_boards
{
    my($self) = shift();
    return ($self->{boards});
}


# Return the number of rounds
sub get_rounds
{
    my($self) = shift();
    return ($self->{rounds});
}


# Return the maximum number of rounds
sub get_maxrounds
{
    my($self) = shift();
    if (exists($self->{maxrounds})) {
        return ($self->{maxrounds});
    }
    return $self->{rounds};
}

sub get_maxplay
{
    my($self) = shift();
    if (exists($self->{maxplay})) {
        return $self->{maxplay};
    }
    return 1;
}


# return numer of boards per round
sub get_bpr
{
    my($self) = shift();
    return ($self->{bpr});
}

# Set the number of boards per round
sub set_bpr
{
    my($self) = shift();
    my($bpr) = @_;
    $self->{bpr} = $bpr;
}


# Get the description
sub get_desc
{
    my($self) = shift();
    return ($self->{desc});
}

# Init the tables for the first round.
sub settables
{
    my($self) = shift();
    if (@_ != 1) {
        die("Moveconfig->settables: wrong args\n");
    }
    my($keys) = @_;

    my($i, $top, $tbl, $sub, $base);
    my($A);

    my($rounds) = $self->get_maxrounds();
    my($tbls) = $self->get_tables();

    $top = $tbls->num();
    for ($i = 1; $i <= $top; $i++) {
        $tbl = $tbls->gettable($i);
        $base = "T$i";
        $tbl->setboards($keys->{$base . "board"});
        $A = [split(m/\s+/, $keys->{$base . "boardcode"})];
        if ((@$A != 1) && (@$A != ($rounds - 1))) {
            die("Wrong number of entries for table $i boardcode\n");
        }
        $tbl->setboards_code($A);

        $tbl->setns($keys->{$base . "ns"});
        $tbl->setew($keys->{$base . "ew"});

        $A = [split(m/\s+/, $keys->{$base . "nscode"})];
        if ((@$A != 1) && (@$A != ($rounds - 1))) {
            die("Wrong number of entries for table $i nscode\n");
        }
        $tbl->setns_code($A);

        $A = [split(m/\s+/, $keys->{$base . "ewcode"})];
        if ((@$A != 1) && (@$A != ($rounds - 1))) {
            die("Wrong number of entries for table $i ewcode\n");
        }
        $tbl->setew_code($A);


        if (exists($keys->{$base . "share"})) {
            $tbl->setshare($keys->{$base . "share"});
        }

        if (exists($keys->{$base . "sharecode"})) {
            $A = [split(m/\s+/, $keys->{$base . "sharecode"})];
            if ((@$A != 1) && (@$A != ($rounds - 1))) {
                die("Wrong number of entries for table $i sharecode\n");
            }
            $tbl->setshare_code($A);
        }


        if (exists($keys->{$base . "nsdir"})) {
            $tbl->setns_dir($keys->{$base . "nsdir"});
        }

        if (exists($keys->{$base . "ewdir"})) {
            $tbl->setew_dir($keys->{$base . "ewdir"});
        }
    }
}				


sub setrelays
{
    my($self) = shift();
    if (@_ != 1) {
        die("Moveconfig->setrelays: wrong args\n");
    }
    my($keys) = @_;
    my($rounds) = $self->get_rounds();
    my($rels) = $self->get_relays();
    my($i, $top, $rel, $sub, $base);
    my($A);
    $top = $rels->num();

    for ($i = 1; $i <= $top; $i++) {
        $rel = $rels->getrelay($i);
        $base = "R$i";
        $rel->setboards($keys->{$base . "board"});
        $A = [split(m/\s+/, $keys->{$base . "boardcode"})];
        if ((@$A != 1) && (@$A != ($rounds - 1))) {
            die("Wrong number of entries for relay $i boardcode\n");
        }
        $rel->setboards_code($A);
    }
}				


sub sessioncalc
{
    my($self) = shift();
    if (@_ != 1) {
        die("Moveconfig->sessioncalc: wrong args\n");
    }
    my($keys) = @_;
    my($boards) = {};
    my($tbls) = $self->get_tables();
    my($rels) = $self->get_relays();
    # Look through all the keys lokking for the setboard keys.
    my($i, $bs, $top);

    # Do tables first.
    for ($i = 1; $i <= $tbls->num(); $i++) {
        my($key) = "T$i" . "board";
        $bs = $keys->{$key};
        if (!defined($bs)) {
            # I don't think this is possible
            die("I can't find the key $key\n");
        }
        # Ignore share directives.
        if ($bs =~ m/\D/) {
            next;
        }
        if ($bs < 0) {
            die("Session may not be negative\n");
        }

        if (exists($boards->{$bs})) {
            die("I have a board session repeat: $bs\n");
        } else {
            if ($bs) {
                $boards->{$bs} = 1;
            }
        }
    }
    for ($i = 1; $i <= $rels->num(); $i++) {
        my($key) = "R$i" . "board";
        $bs = $keys->{$key};
        if (!defined($bs)) {
            # I don't think this is possible
            die("I can't find the key $key\n");
        }
        if ($bs =~ m/\D/) {
            die("Session ($bs) is not numeric\n");
        }
        if ($bs < 0) {
            die("Session may not be negative\n");
        }

        if (exists($boards->{$bs})) {
            die("I have a board session repeat: $bs\n");
        } else {
            $boards->{$bs} = 1;
        }
    }
    $i = 1;
    my(@keys) = sort({$a <=> $b } keys(%$boards));
    $top = $keys[-1];
    for($i = 1; $i <= $top; $i++) {
        if (!exists($boards->{$i})) {
            die("I have a missing keys in the board sequence $i\n");
        }
    }
    if (!exists($keys->{bpr})) {
        die("I am missing the bpr key\n");
    }
    return ($top, $keys->{bpr});
}


# examine the main input keys to check that we have all
# the required keys. Return the number of tables or relays found.
sub keycheck
{
    my($keys, $base, $subkeys) = @_;
    my($i) = 0;

    for (;;) {
        $i++;
        my($basekey) = "$base$i";
        my($n) = 0;
        my(@misskey);
        foreach my $sub (@$subkeys) {
            my($fullkey) = $basekey . $sub;
            if (exists($keys->{$fullkey})) {
                $n++;
            } else {
                push(@misskey, $fullkey);
            }
        }
        if ($n == 0) {
            last;
        }
        if ($n != scalar(@$subkeys)) {
            die("Missing key for relay $i: @misskey\n");
        }
    }
    $i--;
    return ($i);
}

sub dec
{
    my($self) = shift();
    if (@_ != 2) {
        die("Moveconfig->dec: wrong args\n");
    }
    my($id, $inc) = @_;
    my($not) = $self->get_not();

    my($newid) = $id - $inc;
    if ($newid <= 0) {
        $newid = $not + $newid;
    }
    if ($newid <= 0 || $newid > $not) {
        die("Calculated id is wrong: $newid startid $id inc $inc\n");
    }
    return ($newid);
}

sub inc
{
    my($self) = shift();
    if (@_ != 2) {
        die("Moveconfig->inc: wrong args\n");
    }
    my($id, $inc) = @_;
    my($not) = $self->get_not();

    my($newid) = $id + $inc;
    if ($newid > $not ) {
        $newid = $newid - $not;
    }
    if ($newid <= 0 || $newid > $not) {
        die("Calculated id is wrong: $newid startid $id inc $inc\n");
    }
    return ($newid);
}

sub runupdate
{
    my($self) = shift();
    if (@_ != 0) {
        die("Moveconfig->runupdate: wrong args\n");
    }
    my($i);
    my($tbl);
    my($rel);
    my($not) = $self->get_not();
    my($nor) = $self->get_nor();
    my($tbls) = $self->get_tables();
    my($rels) = $self->get_relays();

#    push(@Place::log, "Round $main::round");
#    push(@Table::log, "Round $main::round");
    for ($i = 1; $i <= $not; $i++) {
        $tbl = $tbls->gettable($i);
        $tbl->move();
    }
    for ($i = 1; $i <= $nor; $i++) {
        $rel = $rels->getrelay($i);
        $rel->move()
    }

    for ($i = 1; $i <= $not; $i++) {
        $tbl = $tbls->gettable($i);
        $tbl->update();
    }
    for ($i = 1; $i <= $nor; $i++) {
        $rel = $rels->getrelay($i);
        $rel->update();
    }
}

sub printtables
{
    my($self) = shift();
    my($outfh) = $self->{outfh};
    my($round) = $self->{round};
    my($epair) = $self->{epair};

    if (@_ != 0) {
        die("Moveconfig->printtables: wrong args\n");
    }
    my($i, $tbl);

    my($bds) = $self->get_boards();
    my($tbls) = $self->get_tables();
    my($rels) = $self->get_relays();
    my($not) = $self->get_not();
    my($nor) = $self->get_nor();
    my($bpr) = $self->get_bpr();
    my($maxplay) = $self->get_maxplay();
    my($bd);
    my($rndctl) = $self->{rndctl};

    my($ctltables) = [];
    my($ctlrelays) = [];
    push(@$rndctl, { tables => $ctltables, relays => $ctlrelays});

    $outfh->print("Round: $round\n") if $outfh;
    for ($i = 1; $i <= $not; $i++) {
        $tbl = $tbls->gettable($i);

        if (!defined($tbl->{share})) {
            if (!defined($tbl->{boards})) {
                die("Table $i boards not set\n");
            }
        }
        if (!defined($tbl->{ns})) {
            die("Table $i ns pair not set\n");
        }
        if (!defined($tbl->{ew})) {
            die("Table $i ew pair not set\n");
        }

        my($bno) = $tbl->determineboard($tbls);

        if ($bno) {
            $bd = $bds->getboard($bno);
        } else {
            $bd = undef();
        }

        # Skip this if we don't have any boards.
        my($bdis);
        my($bset);
        if (!defined($bd)) {
            $bdis = "-";
            $bset = 0;
        } else {
            $bdis = $bd->boards($bpr);
            $bset = $bd->{num};
        }

        # We need to generate the same data by round.
        # Each round has a structure hash that contains two array
        # refs, tables and relays. Each element in the array contains
        # the n/s pair number, the e/w pair number and the board set number.
        $ctltables->[$i - 1] =
          {
           ns => $tbl->{ns},
           ew => $tbl->{ew},
           set => $bset,
          };

        # Collect details about the pair position plays
        my($ns, $ew);
        $ns = $tbl->{ns};
        $ew = $tbl->{ew};
        my($pairs) = $self->{pairs};

        if (exists($pairs->{$ns})) {
            $pairs->{$ns}->[0]++;
        } else {
            $pairs->{$ns} = [ 1, 0 ];
        }

        if (exists($pairs->{$ew})) {
            $pairs->{$ew}->[1]++;
        } else {
            $pairs->{$ew} = [ 0, 1 ];
        }
        my($ops) = $self->{ops};
        $ops->{$ns}->{$ew}++;
        $ops->{$ew}->{$ns}++;

        if ($ops->{$ns}->{$ew} > $maxplay) {
            die("pair $ns has played $ew more than $maxplay\n");
        }

        if ($ops->{$ew}->{$ns} > $maxplay) {
            die("pair $ew has played $ns more than $maxplay\n");
        }


        # Do we have an excluded pair, if so remove it.
        if ($epair) {
            next if $epair == $tbl->{ns};
            next if $epair == $tbl->{ew};
        }
        $outfh->print("$tbl->{ns} v $tbl->{ew} $bdis\n") if $outfh;
        $tbl->settraveller($round);
    }

    my($rel);
    for ($i = 1; $i <= $nor; $i++) {
        $rel = $rels->getrelay($i);
        $bd = $bds->getboard($rel->{boards});

        $ctlrelays->[$i - 1] =
          {
           ns => 0,
           ew => 0,
           set => $bd->{num},
          };
    }
}

sub printtravs
{
    my($self) = shift();
    if (@_ != 0) {
        die("Moveconfig->printtravs: wrong args\n");
    }
    my($outfh) = $self->{outfh};
    my($i, $bd);
    my($keys);
    my($trav);
    my($key);
    my($bds) = $self->get_boards();
    my($nos) = $self->get_nos();
    my($bpr) = $self->get_bpr();
    my($travs) = $self->{trav};

    for ($i = 1; $i <= $nos; $i++) {
        $bd = $bds->getboard($i);
        print("Boards: ", $bd->boards($bpr), "\n") if $outfh;
        $trav = $travs->{$i};
        $keys = $trav->get_array();
#        @keys = sort( { $a <=> $b } keys(%$eles));
        foreach $key (@$keys) {
            print("$key->{n} v $key->{e}\n") if $outfh;
        }
    }
}

# Return the range of pairs in use in a format
# suitable for the setup file.
sub get_range
{
    my($self) = shift();
    my($travs) = $self->{trav};
    my($nos) = $self->{nos};
    my($i);
    my($pairs) = {};
    my($trav);
    my($value);

    for ($i = 1; $i <= $nos; $i++) {
        $trav = $travs->{$i};
        foreach $value (@{$trav->get_array()}) {
            $pairs->{$value->{n}} = 1;
            $pairs->{$value->{e}} = 1;
        }
    }
    # return all the keys
    my(@pairs) = sort({$a <=> $b} keys(%$pairs));
    # Determine the range.
    my($r) = 0;
    my(@r, $lp, $p);
    foreach $p (@pairs) {
        if (!$r) {
            $r = $p;
            $lp = $p;
        } else {
            if ($p > ($lp + 1)) {
                # end of range.
                push(@r, "$r-$lp");
                $r = $p;
                $lp = $p;
                next;
            }
        }
        $lp = $p;
    }
    if ($r) {
        push(@r, "$r-$lp");
    }
    return join(",", @r);
}


sub set_excludepair
{
    my($self) = shift();
    my($epair) = @_;
    $self->{epair} = $epair;
}

sub get_moves
{
    my($self) = shift();
    my($sfr, $arr) = @_;
    my($moves) = [];
    my($nos) = $self->{nos};
    my($travs) = $self->{trav};
    my($i);

    for ($i = 1; $i <= $nos; $i++) {
        my($trav) = $travs->{$i};
        my($value);
        my(@lp);
        my($ta) = $trav->get_array();
        # See if we want to skip the first round.
        if (defined($sfr) && $sfr) {
            shift(@$ta);
        }
        foreach $value (@$ta) {
            push(@lp, $value->{n});
            push(@lp, $value->{e});
        }
        push(@$moves, join(",", @lp));
    }
    return ($moves);
}



# Return the data without using strings, so we can use it without parsing
sub get_jmoves
{
    my($self) = shift();
    my($moves) = [];
    my($nos) = $self->{nos};
    my($travs) = $self->{trav};
    my($i);

    for ($i = 1; $i <= $nos; $i++) {
        my($trav) = $travs->{$i};
        my($value);
        my($lp);
        my($ta) = $trav->get_array();
        foreach $value (@$ta) {
            push(@$lp, [ $value->{n} + 0, $value->{e} + 0, $value->{rnd} ]);
        }
        push(@$moves, $lp);
    }
    return ($moves);
}
# Change all the ew numbers in round ctl array into the normal
# style, i.e starting from 1.
sub fixew_display
{
    my($self) = shift();
    my($nor) = $self->get_rounds();
    my($not) = $self->get_not();
    my($r, $t);
    my($fudge);
    if ($not <= 10) {
        $fudge = 10;
    } else {
        $fudge = 20;
    }
    for ($r = 1; $r <= $nor; $r++) {
        my($ctl) = $self->get_ctltbl($r);
        for ($t = 1; $t <= $not; $t++) {
            my($ent) = $ctl->[$t - 1];
            if ($ent->{ew} < $fudge) {
                die("Bad fudge $fudge $ent->{ew}\n");
            }
            $ent->{ew} -= $fudge;
        }
    }
}

sub set_fixew
{
    my($self) = shift();
    my($fixew) = @_;
    $self->{fixew} = $fixew;
}

sub get_fixew
{
    my($self) = shift();
    return ($self->{fixew});
}


1;
