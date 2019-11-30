
# Copyright (c) 2011 Paul Haffenden. All rights reserved.
# $Id: Bridgemate.pm 1644 2016-11-10 11:42:45Z phaff $

###################
package Bridgemate;
###################

use strict;
use warnings;

use DBI;
use Win32;
use File::Copy qw(cp);

use lib "../lib";
use Setup;
use Pairmap;
use Single;
use Board;
use Result;
use Trs;

our($driver) = "Microsoft Access Driver (*.mdb)";

sub new
{
    my($class) = shift();
    my($dir) = @_;
    my($self) = {};
    my($single);
    my($setup);

    $self->{dir} = $dir;

    $setup = Setup->new();
    $setup->load($dir);
    $self->{setup} = $setup;

    $single = Single->new();
    my($ok) = $single->load("contact.csv");
    if ($ok) {
        die($ok, "\n");
    }
    $self->{single} = $single;
    $self->{tplayers} = 0;
    my($not) = scalar(@{$setup->tables()});
    my($rndctl) = $setup->bmate();
    my($nor) = scalar(@$rndctl);
    my($epair) = $setup->missing_pair();
    my($bpr) = $setup->bpr();
    my($tents) = 0;
    my($rndno);
    my($t);

    for ($rndno = 1; $rndno <= $nor; $rndno++) {
        for ($t = 1; $t <= $not; $t++) {
            my($ct) = $rndctl->[$rndno - 1]->[$t - 1];
            my($ns, $ew);
            $ns = $ct->[0];
            $ew = $ct->[1];
            if ($ns != $epair && $ew != $epair) {
                # We count each entry that does not use
                # the missing pair
                $tents += $bpr;
            }
        }
    }
    my($tplayers) = $not * 4; # Total number players
    if ($epair) {
        $tplayers -= 2;
    }

    $self->{tents} = $tents;
    $self->{tplayers} = $tplayers;

    # Open the pairs and trs files.
    my($trs, $pairmap);

    if (!defined($Trs::rev)) {
        my($rev) = $Travclient::rev =~ m/(\d+)/;
        $Trs::rev = $rev;
    }
    $trs = Trs->new();
    $trs->load($dir, 1);
    $pairmap = Pairmap->new();

    $self->{trs} = $trs;
    $self->{pairmap} = $pairmap;

    $self->{sents} = $trs->count(); # Number of seen results;
    $self->{splayers} = $pairmap->count(); # Number of seen players;

    bless($self, $class);
    return $self;
}

sub save
{
    my($self) = shift();
    my($dir) = $self->{dir};

    $self->{trs}->save($dir);
    $self->{pairmap}->save($dir);
}


sub createdb
{
    my($self) = shift();
    my($dir) = $self->{dir};
    my($setup) = $self->{setup};
    my($single) = $self->{single};
    my($compname) = Win32::NodeName();
    my($compid, $sectid);
    my($ok);

    # Create the bridgemate file in our main directory.
    my($fullname) = $dir . ".bws";
    # Copy the default db.
    cp("../Default.bws", $fullname);

    my($dbh) = $self->connectdb($fullname);
    if (!ref($dbh)) {
        unlink($fullname);
        return("Failed to connect " . $dbh->errstr());
    }
    $ok = fix_playernumbers($dbh);
    if ($ok) {
        unlink($fullname);
        return ($ok);
    }
    $compid = setup_clients($dbh, $compname);
    if (!defined($compid)) {
        unlink($fullname);
        return ("Failed to setup the Clients tables with my computer name");
    }
    $sectid = setup_section($dbh, $compid, $setup);
    if (!defined($sectid)) {
        unlink($fullname);
        return ("Failed to setup the Section table");
    }

    $ok = setup_tables($dbh, $compid, $sectid, $setup);
    if (!defined($ok)) {
        unlink($fullname);
        return ("Failed to setup the tables");
    }
    $ok = $self->setup_rounddata($dbh, $sectid, $setup);
    if (!defined($ok)) {
        unlink($fullname);
        return ("Failed to setup the rounddata");
    }

    $ok = $self->setup_playernumbers($dbh, $sectid, $setup);
    if (!defined($ok)) {
        unlink($fullname);
        return ("Failed to setup the playernumbers");
    }

    $ok = setup_playernames($dbh, $single);
    if (!defined($ok)) {
        unlink($fullname);
        return ("Failed to setup the playernames");
    }
    return ("");
}

sub single
{
    my($self) = shift();

    return $self->{single};
}


sub connectdb
{
    my($self) = shift();
    my($fullname) = @_;
    my($ds) = "dbi:ODBC:driver=$driver";
    $ds .= ";dbq=$fullname;ExtendedAnsiSQL=1;";
    my($dbh) = DBI->connect($ds, undef, undef, {PrintError => 0});
    if (!defined($dbh)) {
        return undef();
    }
    $self->{dbh} = $dbh;
    return $dbh;
}

# Plain private function.
sub fix_playernumbers
{
    my($dbh) = @_;
    if (!$dbh->do("DROP TABLE [PlayerNumbers]")) {
        return ("The drop failed " . $dbh->errstr);
    }
    my($ent) =
 [
  "PlayerNumbers",
  "Section INTEGER",
  "Table INTEGER",
  "Direction CHAR(2)",
  "Number CHAR(16)",
  "Name CHAR(18)",
  "Updated YESNO DEFAULT false",
  "TimeLog DATETIME",
  "Processed YESNO DEFAULT false",
 ];
    return (create_table($dbh, $ent));
}


sub create_table
{
    my($dbh, $ent) = @_;
    my($name) = shift(@$ent);
    my($sql);
    my($x);
    # If the fields are reserved words....
    foreach $x (@$ent) {
        $x =~ s/^(\S+)/[$1]/;
    }
    $sql = "CREATE TABLE [$name] (" . join(", ", @$ent) . ")";
    if (!$dbh->do($sql)) {
        return ("The create table has failed " . $dbh->errstr);
    }
    return ("");
}

# Insert our computer name into the clients table
sub setup_clients
{
    my($dbh, $name) = @_;

    $dbh->do(qq/UPDATE [Clients] SET Computer = '$name' WHERE ID = 1/) or
      die("Failed to update $name into Clients ", $dbh->errstr, "\n");

    my($sth) = $dbh->prepare(q/SELECT * FROM [Clients]/);
    $sth->execute();
    my($row);
    while ($row = $sth->fetchrow_arrayref()) {
        $row->[1] =~ s/\s*$//;
        if ($row->[1] eq $name) {
            return $row->[0];
        }
    }
    return undef;
}


sub setup_section
{
    my($dbh, $compid, $setup) = @_;
    my($sectid) = 1;  # Only ever have one section
    my($letter) = "A";
    my($not) = scalar(@{$setup->tables()});
    my($mp) = $setup->missing_pair();

    $dbh->do("INSERT INTO [Section] (ID, Letter, Tables, MissingPair) " .
             "VALUES($sectid, '$letter', $not, $mp)") or
      return (undef);
    return ($sectid);
}

sub setup_tables
{
    my($dbh, $compid, $sectid, $setup) = @_;

    my($not) = scalar(@{$setup->tables()});
    my($t);

    for ($t = 1; $t <= $not; $t++) {
        my($sql) = qq/INSERT INTO [Tables] ([Section], [Table], ComputerID) VALUES($sectid, $t, $compid)/;
        $dbh->do($sql) or
          return (undef);
    }
    return 1;
}

sub setup_rounddata
{
    my($self) = shift();
    my($dbh, $sectid, $setup) = @_;

    my($not) = scalar(@{$setup->tables()});
    my($rndctl) = $setup->bmate();
    my($bpr) = $setup->bpr();
    my($t);
    my($rndno);
    my($nor) = scalar(@$rndctl);
    my($epair) = $setup->missing_pair();

    for ($rndno = 1; $rndno <= $nor; $rndno++) {
        for ($t = 1; $t <= $not; $t++) {
            my($ct) = $rndctl->[$rndno - 1]->[$t - 1];
            my($ns, $ew, $low, $high);
            $ns = $ct->[0];
            $ew = $ct->[1];
            $low = (($ct->[2] - 1) * $bpr) + 1;
            $high = $low + $bpr - 1;
            my($sql) = qq/INSERT INTO RoundData ([Section], [Table], Round, NSPair, EWPair, LowBoard, HighBoard) / .
              qq/VALUES($sectid, $t, $rndno, $ns, $ew, $low, $high)/;
            $dbh->do($sql) or
              return (undef);
        }
    }
    return 1;
}

sub setup_playernumbers
{
    my($self) = shift();
    my($dbh, $sectid, $setup) = @_;

    # The spec says that the table should be left empty.
    # so just return 'ok' here
    #return 1;


    my($not) = scalar(@{$setup->tables()});
    my($t);
    my($dir);
    my($epair) = $setup->missing_pair();
    for ($t = 1; $t <= $not; $t++) {
        foreach $dir ("N", "S", "E", "W") {
            my($sql) = "INSERT INTO PlayerNumbers ([Section], [Table], Direction, Processed) " .
              "VALUES($sectid, $t, '$dir', true)";
            $dbh->do($sql) or
              return (undef);
        }
    }
    my($tplayers) = $not * 4; # Total number players
    if ($epair) {
        $tplayers -= 2;
    }
    print("Setting up $tplayers\n");

    return 1;
}

sub setup_playernames
{
    my($dbh, $single) = @_;
    my($ents) = [ values(%{$single->{map}}) ];
    my($ent);

    my($tbldata) =
 [
  "PlayerNames",
  "ID LONG",
  "Name CHAR(18)",
 ];

    if (create_table($dbh, $tbldata)) {
        return undef;
    }

    foreach $ent (@$ents) {
        my($sql);
        my($name) = $ent->cname() . " " . $ent->sname();
        $sql = "INSERT INTO PlayerNames (ID, Name) " .
          "VALUES($ent->id(), '$name')";
        $dbh->do($sql) or return (undef);
    }
    return (1);
}

sub get_latest
{
    my($self) = shift();
    my($trs);
    my($pairmap);
    my($dbh) = $self->{dbh};
    my($sth);
    my($row);
    my(@ids);
    my($id);
    my($instr);
    my($boards);
    my($fh) = $self->{fh};

    $trs = $self->{trs};
    $pairmap = $self->{pairmap};

    $sth = $dbh->prepare(q/SELECT * FROM [ReceivedData] WHERE Processed = false/) or die("Prepare failed\n");
    $sth->execute() or die("Execute failed\n");
    while ($row = $sth->fetchrow_arrayref()) {
        push(@ids, $row->[0]);
        $instr = convert_bm_kbs($row, $fh);
        my(@vul) = Board->vul($instr->[0]);
        my($err);
        my($res) = Result->new($instr->[1], @vul, \$err);
        if (!defined($res)) {
            die("Failed to convert $err ", join(" ", $row), "\n");
        }
        my($bno) = $instr->[0];
        $trs->add_result($bno, $res);
    }
    foreach $id (@ids) {
        my($trys) = 5;
        for (;;) {
            my($x);
            $x = $dbh->do(qq/UPDATE [ReceivedData] SET Processed = true WHERE ID = $id/);
            if (!$x) {
                $trys--;
                if ($trys <= 0) {
                    die("Failed to update in 5 attempts\n");
                }
                print("Update failed, try again\n");
                sleep(1);
            } else {
                last;
            }
        }
    }
    # Count the number of results processed
    $self->{sents} += scalar(@ids);

    # Now do the player table.
    my($tlookup) = $self->{setup}->tables();

    @ids = ();
    $sth = $dbh->prepare(q/SELECT * FROM [PlayerNumbers] WHERE Processed = false/) or die("Prepare failed\n");
    $sth->execute() or die("Execute failed\n");
    while ($row = $sth->fetchrow_arrayref()) {
        push(@ids, [ $row->[0], $row->[1], $row->[2] ]);

        $self->updatepairs($row, $tlookup, $pairmap);

    }
    foreach $id (@ids) {
        my($trys) = 5;
        for (;;) {
            my($x);
            $fh->print("The id is ($id->[0] $id->[1] $id->[2])\n");
            $x = $dbh->do(qq/UPDATE [PlayerNumbers] SET Processed = true WHERE [Section] = $id->[0] AND [Table] = $id->[1] AND [Direction] = '$id->[2]'/);
            if (!$x) {
                $fh->print("Failed ", $dbh->errstr, "\n");
                $trys--;
                if ($trys <= 0) {
                    die("Failed to update in 5 attempts\n");
                }
                $fh->print("Update failed, try again\n");
                sleep(1);
            } else {
                last;
            }
        }
    }
    $self->{splayers} += scalar(@ids);
}

# Convert a result row from a BridgeMate ReceivedData entry and
# convert it into a form suitable for kbs. Return undef on
# an error, or a board number and string on success.
sub convert_bm_kbs
{
    my($row, $fh) = @_;
    my($ID, $section, $table, $round, $board, $pairns,
       $pairew, $declarer, $ns_ew, $con, $result,
       $leadcard, $remarks) = @$row;

    my($str);

    trim($con);
    trim($leadcard);
    trim($declarer);
    trim($remarks);

    $fh->printf("Round %2d Board: %2d NS %2d EW %2d",
                $round, $board, $pairns, $pairew);

    if ($remarks eq "Wrong direction") {
        $fh->print("Wrong dir\n");
        $str = "$pairew $pairns ";
    } else {
        $str = "$pairns $pairew ";
    }

    # See if we have a NotPlayed.
    if ($remarks eq "Not played") {
        $str .= "#";
    } elsif ($remarks eq "Arb") {
        $str .= "A"; # just give them an 50% average.
    } elsif ($remarks =~ m/(\d\d)%-(\d\d)%/) {
        my($n, $e);
        $n = $1;
        $e = $2;
        $str .= "A" . con($n) . con($e);
    } elsif ($con eq "PASS") {
        $str .= "P";
    } else {
        $con =~ s/x/*/g;
        $con =~ s/NT/N/;
        $str .= "$con";
        if ($result !~ m/=/) {
            if ($result < 0) {
                $str .= $result;
            } else {
                $result =~ s/\+//;
                $str .= $result;
            }
        }
        $str .= " " . substr($ns_ew, 0, 1) . " " . leadcon($leadcard);
    }
    return ( [ $board, $str ] );
}

sub con
{
    my($pre) = @_;
    if ($pre == 40) {
        return ("-");
    }
    if ($pre == 50) {
        return ("=");
    }
    if ($pre == 60) {
        return ("+");
    }
    # The I don't know default.
    return ("=");
}

sub leadcon
{
    my($card) = @_;
    my($rank) = "";
    my($len) = length($card);

    if ($len == 0) {
        return "";
    }
    my($suit) = substr($card, 0, 1);
    if (length($card) > 1) {
        $rank = substr($card, 1);
        if ($rank =~ m/10/) {
            return "T$suit";
        }
        return "$rank$suit";
    } else {
        return "x$suit";
    }
}

sub trim
{
    $_[0] =~ s/\s+//g;
}

use Win32::Process qw(STILL_ACTIVE NORMAL_PRIORITY_CLASS);
sub start_process
{
    my($self) = shift();
    my($obj);

    Win32::Process::Create($obj, "C:/BMTest/BMTest.exe",
                           "BMTest",
                           0,
                           NORMAL_PRIORITY_CLASS,
                           ".");
    $self->{obj} = $obj;
}

# Is the database present?
sub havedb
{
    my($self) = shift();
    my($fullname) = $self->{dir} . ".bws";

    print("I have a fullname of $fullname\n");
    my($dbh) = $self->connectdb($fullname);
    if (ref($dbh)) {
        return 1;
    }
    return 0;
}

sub haveprog
{
    my($self) = shift();
    if ($self->{obj}) {
        my($ec) = 0;
        Win32::Process::GetExitCode($self->{obj}, $ec);
        print("I have an exit code of $ec\n");
        if ($ec != STILL_ACTIVE) {
            $self->{obj} = undef;
            return 0;
        }
        return 1;
    }
    return 0;
}

sub stop_process
{
    my($self) = @_;
    my($exit) = 0;
    if ($self->{obj}) {
        $self->{obj}->Kill($exit);
        $self->{obj} = undef;
    }
}

sub setid
{
    my($self) = shift();
    my($id) = @_;
    $self->{id} = $id;
}

sub setfh
{
    my($self) = shift();
    my($fh) = @_;
    $self->{fh} = $fh;
}

sub getfh
{
    my($self) = shift();
    return $self->{fh};
}

sub getid
{
    my($self) = shift();
    return ($self->{id});
}

sub frames
{
    my($self) = shift();
    my($frames) = @_;
    if (defined($frames)) {
        $self->{frames} = $frames;
    }
    return $self->{frames};
}

sub DESTROY
{
    my($self) = shift();
    my($exit) = 0;

    print("Bridgemate object destroyed\n");
    if (defined($self->{obj})) {
        print("Doing kill of the process\n");
        $self->{obj}->Kill($exit);
    }
}


sub updatepairs
{
    my($self) = shift();
    my($row, $tlookup, $pairmap) = @_;
    my($tbl) = $row->[1];
    my($dir) = $row->[2];
    my($number) = $row->[3];
    trim($dir);
    trim($number);

    # lookup any existing pair mapping
    my($tind);
    if ($dir eq "N" || $dir eq "S") {
        $tind = 0;
    } else {
        $tind = 1;
    }
    my($sessionpair) = $tlookup->[ $tbl - 1 ]->[$tind];
    my(@p);
    if (!exists($pairmap->{$sessionpair})) {
        @p = (0, $number);
    } else {
        @p = Pairmap->break($pairmap->{$sessionpair});
        $p[0] = $number;
    }
    print("I am adding as $sessionpair @p\n");
    $pairmap->addpair($sessionpair, @p);
}

sub playerprogress
{
    my($self) = shift();
    return int( 100 * $self->{splayers} / $self->{tplayers});
}


sub resultprogress
{
    my($self) = shift();
    return int( 100 * $self->{sents} / $self->{tents});
}

1;
