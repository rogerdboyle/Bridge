use strict;
use warnings;

use Tk::Pane;

###################
package Listclient;
###################

use Setup;
use Scorepositions;
use Sql;

sub main
{
    my($conf) = @_;
    my($mw) = $conf->get("mw");

    $mw->title("List of all events");
    my($ysize) = $mw->screenheight();
    $ysize -= 100;

    my($tf) = $mw->Frame();
    my($row) = 0;
    $tf->pack(-side => "top");
    $conf->set("tf", $tf);

    my($fr) = $tf->Scrolled('Frame', -scrollbars => "oe",
                           -height => $ysize, -sticky => "nw");
    $fr->pack(-side => "top");

    my($but) = $fr->Button(-text => "Cancel",
                           -command => [ \&cancel_list, $conf ]);
    $but->grid(-row => $row, -column => 0, -columnspan => 3);

    $row++;
    my($lab) = $fr->Label(-text => "Event");
    $lab->pack(-side => "top");
    $lab->grid(-row => $row, -column => 0, -sticky => "ew");

    $lab = $fr->Label(-text => "Tables");
    $lab->grid(-row => $row, -column => 1);

    $lab = $fr->Label(-text => "Remove");
    $lab->grid(-row => $row, -column => 2);
    $row++;

    # Get the list of all the folders in the result folder
    my($res) = [ sort({$b cmp $a } @{Sql->keys(Sql::SETUP)}) ];
    my($dir);

    foreach $dir (@$res) {
        my($l) = $dir;
        $l =~ s:.*/::;
        my($disdate);
        my(@y) = $l =~ m/^(\d\d\d\d)(\d\d)(\d\d.*)/;
        $disdate = "$y[0]-$y[1]-$y[2]";
        my($but) = $fr->Button(-text => $disdate,
                              -command => [ \&select_session, $conf, $l ]);
        $but->grid(-row => $row, -column => 0, -sticky => "ew");


        # Now the number of tables.
        # load the result file.
        my($sp) = Scorepositions->new();
        eval {
            $sp->load($l);
        };
        my($tables) = 0;
        if ($@) {
            # error
            $tables = "N/A";
        } else {
            # no error opening the file
            my($array) = $sp->{array};
            my($item);
            foreach $item (@$array) {
                $tables += scalar(@$item);
            }
            $tables /= 2;
        }
        $lab = $fr->Label(-text => $tables);
        $lab->grid(-row => $row, -column => 1);

        $but = $fr->Button(-text => "X",
                           -command => [ \&remove_setup, $conf, $l ]);
        $but->grid(-row => $row, -column => 2);
        if ($tables =~ m/\d/) {
            # We have digit in the tables, so don't
            # let him delete setup file.
            $but->configure(-state => "disable");
        }
        $row++;
    }
}

sub remove_setup
{
    my($conf, $label) = @_;
    Setup->remove($label);
    main::backtomain($conf);
}

sub cancel_list
{
    my($conf) = @_;

    main::backtomain($conf);
}

sub select_session
{
    my($conf, $dir) = @_;
    my($tf) = $conf->get("tf");
    $conf->set("tf", undef);
    $tf->destroy();
    my($datestr, $suffix);
    if ($dir =~ m/_/) {
        ($datestr, $suffix) = $dir =~ m/(\d\d\d\d\d\d\d\d)_(.*)/;
    } else {
        $datestr = $dir;
        $suffix = "";
    }
    $conf->set("datestr", $datestr);
    $conf->set("suffix", $suffix);
    main::runsetup($conf);
}
1;
