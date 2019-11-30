
# $Id: Playereditclient.pm 1694 2017-01-07 14:56:15Z phaff $
# Copyright (c) 2010 Paul Haffenden. All rights reserved.
#########################
package Playereditclient;
#########################


use strict;
use warnings;
use Tk;
use Tk::Pane;
use Tk::Font;
use Tk::Dialog;

use Conf;
use lib "lib";
use Confobj;
use Single;

sub main
{
    my($mw, $goodbye) = @_;
    my($ret);

    my($confconfig) =
      {
       mw => undef,
       fr => undef,
       single => undef,
       cname => undef,
       sname => undef,
       email => undef,
       phone => undef,
       refnum => undef,
       noemail => undef,
       notactive => undef,
       tl => undef,
       buttons => undef,
       maxrows => undef,
      };

    my($confobj) = Confobj->new($confconfig);

    my($single) = Single->new();
    $ret = $single->load("contact.csv");
    if ($ret) {
        die("Failed to load contact.csv $ret\n");
    }
    $confobj->set("single", $single);
    $confobj->set("mw", $mw);
    $mw->title("Player editor");
    paintusersscreen($confobj, $goodbye);
}

sub paintusersscreen
{
    my($conf, $goodbye) = @_;
    my($mw, $single);

    $mw = $conf->get("mw");
    $single = $conf->get("single");


    my($maxrow);
    my($lineheight);
    my($frameheight);
    {
        use integer;
        # Calculate the max number of rows.
        # Find out how many bit we have to play with.
        my($fh) = $mw->screenheight();
        my($scrollheight) = 100; # leave space for menu bars etc
        $frameheight = $fh - $scrollheight;

        # Create a button, and find out how big it is.
        my($but) = $mw->Button(-text => "An example");
        my($border) = $but->cget("-borderwidth");
        my($pady) = $but->cget("-pady");
        my($hl) = $but->cget("-highlightthickness");
        $pady = $but->pixels($pady);
        my($linespace) = $but->Font()->metrics("-linespace");
        # The button height is
        my($lineheight) = $linespace + (2 * $border) + (2 * $pady) + ($hl * 2);
        print("linespace $linespace border $border pady $pady hl $hl\n");
        $lineheight += 4;
        $maxrow = $frameheight / $lineheight;
        $maxrow = $maxrow - 1;
        print("A button's height is $lineheight and maxrow is $maxrow scrollheight $scrollheight real frameheight $fh frameheight $frameheight\n");
    }

    my($fr);
    my($screenwidth) = $mw->screenwidth();
    $fr = $mw->Scrolled('Frame', -scrollbars => 'os',
                        -width => $screenwidth,
                        -height => $frameheight,
                       );

    $fr->pack(-side => "top");
    $conf->set("fr", $fr);

    my(@all) = $single->sorted(1);

    my($but, $row, $col, $s);
    my($buttons) = [];
    $row = 0;
    $col = 0;

    $conf->set("maxrows", $maxrow);

    $but = $fr->Button(
                       -text => "Add a new player",
                       -command => [ \&editplayer, $conf, 0, ],
                      );
    $but->grid(
               -column => $col,
               -row => $row,
               -sticky => "nsew",
              );
    $buttons->[$row]->[$col] = $but;

    $but->OnDestroy([\&goodbye]);
    $row++;

    foreach $s (@all) {
        $but = $fr->Button(
                           -text => $single->name($s->id()),
                           -command => [ \&editplayer, $conf, $s->id()],
                          );
        $but->grid(
                   -column => $col,
                   -row => $row,
                   -sticky => "nsew",

                  );
        $buttons->[$row]->[$col] = $but;
        if ($row >= $maxrow) {
            $row = 0;
            $col++;
        } else {
            $row++;
        }
    }
    # If $col is still 0, then we may have to add some extra
    # blank buttons.
    if ($col == 0) {
        while ($row <= $maxrow) {
            $but = $fr->Button(
                               -text => "Blank",
                               -state => "disabled",
                              );
            $but->grid(
                       -column => $col,
                       -row => $row,
                       -sticky => "nsew",

                      );
            $buttons->[$row]->[$col] = $but;
            $row++;
        }
    }

    $conf->set("buttons", $buttons);

    # Finally add the "Done" button.
    $but = $fr->Button(
                       -text => "DONE",
                       -command => $goodbye,
                      );


    $but->grid(
               -row => $maxrow + 1,
               -column => 4,
               -sticky => "nsew",
              );
    $buttons->[$maxrow + 1]->[4] = $but;
}

sub goodbye
{
}
sub editplayer
{
    my($conf, $id) = @_;

    my($tl);
    $tl = $conf->get("tl");
    # Don't allow anymore windows to be created.
    if ($tl) {
        return;
    }

    my($mw, $single);
    $mw = $conf->get("mw");
    $single = $conf->get("single");
    my($e, $l, $c);

    # Pop up a new window.
    $tl = $mw->Toplevel();
    $tl->title("Player Details");
    $conf->set("tl", $tl);
    my($cname, $sname, $email, $phone, $refnum, $noemail, $notactive);

    $cname = $conf->getref("cname");
    $sname = $conf->getref("sname");
    $email = $conf->getref("email");
    $phone = $conf->getref("phone");
    $refnum = $conf->getref("refnum");
    $noemail = $conf->getref("noemail");
    $notactive = $conf->getref("notactive");

    if ($id) {
        my($d) = $single->entry($id);
        if (!defined($d)) {
            die("Have no entry for $d in player database\n");
        }
        $$cname = $d->cname();
        $$sname = $d->sname();
        $$email = $d->email();
        $$phone = $d->phone();
        $$refnum = $d->refnum();
        if ($d->noemail()) {
            $$noemail = 1;
        } else {
            $$noemail = 0;
        }
        if ($d->notactive()) {
            $$notactive = 1;
        } else {
            $$notactive = 0;
        }
    } else {
        $$cname = "";
        $$sname = "";
        $$email = "";
        $$phone = "";
        $$refnum = "";
        $$noemail = 0;
        $$notactive = 0;
    }

    $l = $tl->Label(-text => "Christian name:");
    $l->grid(-row => 0, -column => 0);
    $e = $tl->Entry(-textvariable => $cname, -width => 30);
    $e->grid(-row => 0, -column => 1);
    $e->focus();
    $e->icursor('end');

    $l = $tl->Label(-text => "Surname name:");
    $l->grid(-row => 1, -column => 0);
    $e = $tl->Entry(-textvariable => $sname, -width => 30);
    $e->grid(-row => 1, -column => 1);

    $l = $tl->Label(-text => "email:");
    $l->grid(-row => 2, -column => 0);
    $e = $tl->Entry(-textvariable => $email, -width => 30);
    $e->grid(-row => 2, -column => 1);

    $l = $tl->Label(-text => "phone:");
    $l->grid(-row => 3, -column => 0);
    $e = $tl->Entry(-textvariable => $phone, -width => 30);
    $e->grid(-row => 3, -column => 1);

    $l = $tl->Label(-text => "Ebu #:");
    $l->grid(-row => 4, -column => 0);
    $e = $tl->Entry(-textvariable => $refnum, -width => 30);
    $e->grid(-row => 4, -column => 1);

    $l = $tl->Label(-text => "no result email:");
    $l->grid(-row => 5, -column => 0);
    $c = $tl->Checkbutton(-variable => $noemail);
    $c->grid(-row => 5, -column => 1);

    $l = $tl->Label(-text => "inactive:");
    $l->grid(-row => 6, -column => 0);
    $c = $tl->Checkbutton(-variable => $notactive);
    $c->grid(-row => 6, -column => 1);

    # Now add a yea or nay button.
    my($but);
    $but = $tl->Button(
                           -text => "Save",
                           -command => [ \&quiteditwindow, $tl, $conf, 1, $id],
                          );
    $but->grid(-row => 7, -column => 1);

    $but = $tl->Button(
                           -text => "Cancel",
                           -command => [ \&quiteditwindow, $tl, $conf, 0],
                          );
    $but->grid(-row => 7, -column => 0);
}

sub quiteditwindow
{
    my($tl, $conf, $do, $id) = @_;

    my($added) = 0;
    if ($do && $id == 0) {
        $added = 1;
    }
    if ($do) {
        my($single) = $conf->get("single");
        my($d);
        if ($id) {
            $d = $single->entry($id);

            if (!defined($d)) {
                die("No entry for $id in player database\n");
            }
        } else {
            # Add the new entry into the map.
            $d = SingleEnt->new();
        }
        $d->cname($conf->get("cname"));
        $d->sname($conf->get("sname"));
        $d->email($conf->get("email"));
        $d->phone($conf->get("phone"));
        $d->refnum($conf->get("refnum"));

        # Check for commas in these fields
        if ($d->cname() =~ m/,/) {
            my($diag) = $tl->Dialog(
                                    -text =>
                                    "The christian name may not include a comma",
                                    -buttons => [ "Ok" ]
                                   );
            $diag->Show();
            return;
        }

        if ($d->sname() =~ m/,/) {
            my($diag) = $tl->Dialog(
                                    -text =>
                                    "The surname name may not include a comma",
                                    -buttons => [ "Ok" ]
                                   );
            $diag->Show();
            return;
        }

        if ($d->email() =~ m/,/) {
            my($diag) = $tl->Dialog(
                                    -text =>
                                    "The email field may not include a comma",
                                    -buttons => [ "Ok" ]
                                   );
            $diag->Show();
            return;
        }

        if ($d->phone() =~ m/,/) {
            my($diag) = $tl->Dialog(
                                    -text =>
                                    "The phone field may not include a comma",
                                    -buttons => [ "Ok" ]
                                   );
            $diag->Show();
            return;
        }
        if ($d->refnum() =~ m/,/) {
            my($diag) = $tl->Dialog(
                                    -text =>
                                    "The Ebu number field may not include a comma",
                                    -buttons => [ "Ok" ]
                                   );
            $diag->Show();
            return;
        }

        $d->noemail($conf->get("noemail"));
        $d->notactive($conf->get("notactive"));
        if (!$id) {
            $id = $single->{top} + 1;
            $single->{top} = $id;
            $single->{map}->{$id} = $d;
            $d->id($id);
        }
        $single->savetofile();
    }
    $conf->set("tl", undef);
    $tl->destroy();
    add_new_user_button($conf, $id, $added);
}

sub add_new_user_button
{
    my($conf, $id, $added) = @_;

    my($fr, $single, $buts, $maxrow);

    $fr = $conf->get("fr");
    $single = $conf->get("single");
    $buts = $conf->get("buttons");
    $maxrow = $conf->get("maxrows");

    my(@all);

    @all = $single->sorted(1);
    my($row, $col, $s);

    $row = 1;
    $col = 0;
    my($but);
    foreach $s (@all) {
        if (exists($buts->[$row]->[$col])) {
            $but = $buts->[$row]->[$col];
            my($butid);
            $butid = $but->cget("-command");
            if (defined($butid)) {
                $butid = $butid->[2];
            } else {
                $butid = 0;
            }
            if (($butid != $s->id()) || (!$added)) {
                if ($butid) {
                    $but->configure(
                                    -text => $single->name($s->id()),
                                    -command =>
                                    [ \&editplayer, $conf, $s->id()],
                                   );
                } else {
                    $but->configure(
                                    -text => $single->name($s->id()),
                                    -command =>
                                    [ \&editplayer, $conf, $s->id()],
                                    -state => "active",
                                   );
                }
            }
        } else {
            $but = $fr->Button(
                               -text => $single->name($s->id()),
                               -command => [ \&editplayer, $conf, $s->id()],
                              );
            $but->grid(
                       -column => $col,
                       -row => $row,
                       -sticky => "nsew",
                      );
            $buts->[$row]->[$col] = $but;
        }
        if ($row >= $maxrow) {
            $row = 0;
            $col++;
        } else {
            $row++;
        }
    }
}


1;
