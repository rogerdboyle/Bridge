#
# An Table object.
#

# $Id: Table.pm 1130 2013-08-15 07:16:47Z mint $

####################
package Move::Table;
####################

use strict;
use warnings;

use IO::Handle;
use Move::Place;
use Move::Trav;

our @ISA = qw(Move::Place);
our(@log);

sub new
{
    my($class) = shift();
    if (@_ != 2) {
        die("Table->new: Wrong args\n");
    }
    my($conf, $num) = @_;

    my($self) = $class->SUPER::new($conf, $num);

    $self->{ns} = undef();
    $self->{ew} = undef();

    # The temps while we do the move.
    $self->{ns_next} = undef();
    $self->{ew_next} = undef();

    # These are the functions that do the movement for this table
    $self->{ns_code} = undef();
    $self->{ew_code} = undef();


    $self->{share} = undef();
    $self->{share_next} = undef();
    $self->{share_code} = undef();

    bless($self, $class);
    return ($self);
}

sub setns()
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setns: Wrong args\n");
    }
    my($ns) = @_;

    $self->{ns} = $ns;
}

sub setew()
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setew: Wrong args\n");
    }
    my($ew) = @_;

    $self->{ew} = $ew;
}

sub setns_next()
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setns_next: Wrong args\n");
    }
    my($ns) = @_;

    $self->{ns_next} = $ns;
}

sub setew_next()
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setew_next: Wrong args\n");
    }
    my($ew) = @_;

    $self->{ew_next} = $ew;
}

sub setns_code
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setns_code: Wrong args\n");
    }
    my($code) = @_;

    $self->{ns_code} = $code;
}

sub setew_code
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setew_code: Wrong args\n");
    }
    my($code) = @_;

    $self->{ew_code} = $code;
}



sub setshare
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setshare: Wrong args\n");
    }
    my($share) = @_;
    $self->{share} = $share;
}

sub setshare_code
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setshare_code: Wrong args\n");
    }
    my($code) = @_;
    $self->{share_code} = $code;
}


sub setshare_next
{
    my($self) = shift();
    if (@_ != 1) {
        die("Table->setshare_next: Wrong args\n");
    }
    my($code) = @_;
    $self->{share_next} = $code;
}


# Move all the table objects based on the code
# variables
sub move
{
    my($tbl) = shift();
    if (@_ != 0) {
        die("Table->move: Wrong args\n");
    }

    $tbl->SUPER::move();
    $tbl->pairmove($tbl->{ns}, $tbl->{ns_code});
    $tbl->pairmove($tbl->{ew}, $tbl->{ew_code});
    $tbl->sharemove();
}


sub sharemove
{
    my($self) = shift();


    if (defined($self->{share_code})) {
        my($code) = $self->{share_code};
        my($ent);
        my($conf) = $self->{conf};

        if (@$code == 1) {
            $ent = $code->[0];
        } else {
            $ent = $code->[$conf->{round} - 2];
        }
        $self->setshare_next($ent);
    }
}

sub pairmove
{
    my($tbl) = shift();
    if (@_ != 2) {
        die("Table->pairmove: Wrong args\n");
    }
    my($pair, $code) = @_;

    my($ntbl);
    my($entry);
    my($id);
    my($fromid);
    my($inc, $wherepair, $whereid);
    my($conf) = $tbl->{conf};
    my($tbls) = $conf->get_tables();

    $fromid = $tbl->{num};
    if (@$code == 1) {
        $entry = $code->[0];
    } else {
        $entry = $code->[$conf->{round} - 2];
    }
    $wherepair = substr($entry, 0, 1);
    $whereid = substr($entry, 1, 1);
    $inc = length($entry) - 2;
    if ($inc > 0) {
        $inc = substr($entry, 2, $inc);
    } else {
        $inc = 1;
    }

    if ($whereid eq "-") {
        $id = $conf->dec($fromid, $inc);
    } elsif ($whereid eq "+") {
        $id = $conf->inc($fromid, $inc);
    } elsif ($whereid eq "=") {
        if (length($whereid) > 1) {
            die("More than one '=' in entry\n");
        }
        $id = $fromid;
    } else {
        # Must be a table digit.
        $id = substr($entry, 1);
    }
    $ntbl = $tbls->gettable($id);
    if ($wherepair eq "E") {
        if(defined($ntbl->{setew_next})) {
            STDERR->print("East already set $pair $fromid -> $id\n");
            die(join("\n", @log), "\n");
        } else {
            push(@log, "East $pair $fromid -> $id");
        }
        $ntbl->setew_next($pair);
    } elsif ($wherepair eq "N") {
        if(defined($ntbl->{setns_next})) {
            STDERR->print("North already set $pair $fromid -> $id\n");
            die(join("\n", @log), "\n");
        } else {
            push(@log, "North $pair $fromid -> $id");
        }
        $ntbl->setns_next($pair);
    } else {
        die("Illegal destination ($wherepair)");
    }
}

sub update
{
    my($self) = shift();
    if (@_ != 0) {
        die("Table->update: Wrong args\n");
    }

    $self->SUPER::update();

    $self->{ns} = $self->{ns_next};
    $self->{ew} = $self->{ew_next};
    $self->{share} = $self->{share_next};
    $self->{ns_next} = undef();
    $self->{ew_next} = undef();
    $self->{share_next} = undef();
}

sub settraveller
{
    my($self) = shift();
    my($round) = @_;
    if (@_ != 1) {
        die("Table->settraveller: Wrong args\n");
    }


    my($n) = $self->{ns};
    my($e) = $self->{ew};
    my($trav);
    my($ele);
    my($conf) = $self->{conf};
    my($travs) = $conf->{trav};

    my($bno) = $self->determineboard($conf->get_tables());
    # We have to jump through this hoop because the
    # boards maybe being shared.
    # $board is normally just the board session number (1-8 say)
    # but if it is shared, then it might be "T1", so we
    # call getboard to perform this possible translation.
    # It can also return undef, indicating that are no boards
    # for this table for this round.
    my($bds) = $conf->get_boards();
    my($bd) = $bds->getboard($bno);
    if (!defined($bd)) {
        return;
    }
    my($b) = $bd->{num};

    if (exists($travs->{$b})) {
        $trav = $travs->{$b};
    } else {
        $trav = Move::Trav->new();
        $travs->{$b} = $trav;
    }
    my($errstr);
    $ele = { n => $n, e => $e, rnd => $round};
    $errstr = $trav->canadd($ele);
    if ($errstr) {
        die("$errstr\n");
    }
    $trav->add($ele);
}


sub determineboard
{
    my($self) = shift();
    my($tbls) = @_;




    if ($self->{share}) {
        my($tbl) = $tbls->gettable($self->{share});
        return $tbl->{boards};
    }
    return $self->{boards};
}


sub setns_dir
{
    my($self) = shift();
    my($arg) = @_;
    $self->{nsdir} = $arg;
}

sub setew_dir
{
    my($self) = shift();
    my($arg) = @_;
    $self->{ewdir} = $arg;
}
sub getns_dir
{
    my($self) = shift();
    if (exists($self->{nsdir})) {
        return $self->{nsdir};
    }
    return "";
}
sub getew_dir
{
    my($self) = shift();
    if (exists($self->{ewdir})) {
        return $self->{ewdir};
    }
    return "";
}
1;
