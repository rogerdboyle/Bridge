
# $Id: Place.pm 712 2011-05-24 09:26:35Z paulh $

####################
package Move::Place;
####################

use strict;
use warnings;
use IO::Handle;

our(@log);

sub new
{
    my($class) = shift();

    if (@_ != 2) {
        die("Place->new: wrong args\n");
    }
    my($conf, $num) = @_;

    my($self) = {};
    $self->{num} = $num;
    $self->{conf} = $conf;
    $self->{boards} = undef();
    $self->{boards_next} = undef();
    $self->{boards_code} = undef();

    bless($self, $class);
    return ($self);
}

sub setboards
{
    my($self) = shift();
    if (@_ != 1) {
        die("Place->setboards: wrong args\n");
    }
    my($boards) = @_;
    $self->{boards} = $boards;
}

sub setboards_next
{
    my($self) = shift();
    if (@_ != 1) {
        die("Place->setboards_next: wrong args\n");
    }
    my($boards) = @_;

    $self->{boards_next} = $boards;
}


sub setboards_code
{
    my($self) = shift();
    if (@_ != 1) {
        die("Place->setboards_code: wrong args\n");
    }
    my($code) = @_;

    $self->{boards_code} = $code
}

sub move
{
    my($self) = @_;
    $self->moveboards($self->{boards}, $self->{boards_code});
}

sub moveboards
{
    my($self) = shift();
    if (@_ != 2) {
        die("Place->moveboards: wrong args\n");
    }
    my($b, $code) = @_;
    my($where);
    my($whereid);
    my($id);
    my($fromid);
    my($obj);
    my($entry);
    my($inc);
    my($type) = ref($self);
    my($conf) = $self->{conf};
    my($tbl) = $conf->get_tables();
    my($rel) = $conf->get_relays();


    # If we don't have any boards, don't move them.
    die(caller()) if !defined($b);
    if ($b == 0) {
        $self->setboards_next($b);
        return;
    }
    if (@$code == 1) {
        $entry = $code->[0];
    } else {
        $entry = $code->[$conf->{round} - 2];
    }
    $where = substr($entry, 0, 1);
    $whereid = substr($entry, 1, 1);

    $inc = length($entry) - 2;
    if ($inc > 0) {
        $inc = substr($entry, 2, $inc);
    } else {
        $inc = 1;
    }

    $fromid = $self->{num};

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

    if ($where eq "T") {
        $obj = $tbl->gettable($id);
    } elsif ($where eq "R") {
        $obj = $rel->getrelay($id);
    } else {
        die("Unknown where type for boards ($where)\n");
    }
    my($totype) = ref($obj);
    if (defined($obj->{boards_next})) {
        STDERR->print("Boards already set $type $fromid -> $totype $id\n");
        die(join("\n", @log), "\n");
    } else {
        push(@log, "Boards already set $type $fromid -> $totype $id");
    }
    $obj->setboards_next($b);
}

sub update
{
    my($self) = shift();
    if (@_ != 0) {
        die("Place->update: wrong args\n");
    }
    $self->{boards} = $self->{boards_next};
    $self->{boards_next} = undef();
}

1;
