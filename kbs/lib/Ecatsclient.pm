
# $Id: Ecatsclient.pm 869 2012-03-01 17:34:19Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

# Given a result directory, generate the ecats results files,
# C.TXT, R.TXT, P.TXT, E.TXT, in the directory "ecats".

####################
package Ecatsclient;
####################

use strict;
use warnings;
use IO::File;
use integer;

use Getopt::Std;
use lib "lib";
use Conf;
use Sdate;
use Setup;
use Single;
use Pairmap;
use Trs;
use Pairusage;

our($ecatsdir) = "ecats";
our($dir);
our($session);
our($eventname);

sub main
{
    my($opts) = {};
    # Get the results directory
    if (!defined($ARGV[0])) {
        die("Must specify a results' directory\n");
    }
    if (!getopts("e:s:", $opts)) {
        die("Bad options\n");
    }
    if (!exists($opts->{s})) {
        usage("No session specified");
    } else {
        $session = $opts->{s};
    }

    if (!exists($opts->{e})) {
        usage("No eventname specified");
    } else {
        $eventname = $opts->{e};
    }

    $dir = $ARGV[0];
    if (!-d $ecatsdir) {
        if (!mkdir($ecatsdir)) {
            die("The ecats directory does not exist, and I ",
                "failed to create it\n");
        }
    }

    my($setup, $bpr);
    $setup = Setup->new();
    $setup->load($dir);

    $bpr = $setup->bpr();

###############################
    # The R.TXT file first, this so we can determine the number
    # of winners.
    my($fh) = IO::File->new();
    if (!$fh->open("$ecatsdir/R.TXT", ">:crlf")) {
        die("Failed to open the $ecatsdir/R.TXT file $!\n");
    }
    my($trs) = Trs->new();
    # Load the travellers.
    $trs->load($dir);
    my($pu) = Pairusage->new();
    # $pu tracks the pair usage, for ns and ew
    rtxt($fh, $trs, $pu);
    $fh->close();
    # Calculate the pair usage info
    $pu->process($bpr);
###############################
    # Now fthe C.TXT file.
    my($datestr);
    $datestr = simpledate($ARGV[0]);
    if (!defined($datestr)) {
        die("Unable to parse the folder argument ($ARGV[0]) as a date\n");
    }
    $fh = IO::File->new();
    if (!$fh->open("$ecatsdir/C.TXT", ">:crlf")) {
        die("Failed to open the $ecatsdir/C.TXT file $!\n");
    }
    ctxt($fh, $dir, $setup, $pu);
    $fh->close();
###############################
    # The P.TXT file.
    # Load up the player database.
    my($single) = Single->new();
    if ($single->load("contact.csv")) {
        die("Failed to load the players database\n");
    }
    my($pm) = Pairmap->new();
    if (!$pm->load($dir)) {
        die("Failed to load the pairmap file results/$dir/pairmap.db\n");
    }
    $fh->close();
    if (!$fh->open("$ecatsdir/P.TXT", ">:crlf")) {
        die("Failed to open the $ecatsdir/P.TXT file $!\n");
    }
    ptxt($fh, $pm, $single, $pu);
    $fh->close();

#################################
    # Creat the end, E.TXT file.
    # Does it need the trailing newline?
    if (!$fh->open("$ecatsdir/E.TXT", ">:crlf")) {
        die("Failed to open the $ecatsdir/E.TXT file $!\n");
    }
    $fh->print("End");
    $fh->close();
}

sub usage
{
    my($msg) = @_;

    die("$msg", <<EOF);

ecats.pl -s session -e eventname resultfolder
EOF
}


sub ctxt
{
    my($fh, $date, $setup, $pu) = @_;
    my(@data);

    # spare0
    $data[0] = 1;
    if ($pu->numberofwinners() == 2) {
        $data[1] = qq/"true"/;
    } else {
        $data[1] = qq/"false"/;
    }
    $data[2] = $setup->nob();
    $data[3] = $setup->bpr();
    $data[4] = qq/"false"/;
    $data[5] = qq/"$Ecats::clubname"/;
    $data[6] = qq/"$Ecats::town"/;
    $data[7] = qq/"$Ecats::county"/;
    $data[8] = qq/"$Ecats::country"/;
    $data[9] = qq/"$Ecats::contactname"/;
    $data[10] = qq/"$Ecats::contactphone"/;
    $data[11] = qq/"$Ecats::contactfax"/;
    $data[12] = qq/"$Ecats::contactemail"/;
    $data[13] = qq/"false"/;
    # Session
    $data[14] = $session;
    $data[15] = qq/"$Ecats::programversion"/;
    my($year, $mon, $day) = $date =~ m/^(....)(..)(..)/;
    $data[16] = qq:"$day/$mon/$year":;
    $data[17] = qq/"$eventname"/;
    # club's ebu number.
    $data[18] = qq/"$Ecats::clubebunumber"/;

    $fh->print("\t", join("\t", @data), "\n");
}

# These are the indexes into the output array.
use constant BOARDNO => 3;
use constant NSPAIR  => 4;
use constant EWPAIR  => 5;
use constant NSSCORE => 6;
use constant EWSCORE => 7;
use constant ADJUST  => 14;

sub rtxt
{
    my($fh, $trs, $pu) = @_;

    my(@data);

    # We setup the fixed fields in the data array before
    # we enter the loops.
    # spare
    $data[0] = 0;
    # spare
    $data[1] = qq/""/;
    # spare
    $data[2] = qq/""/;

    # spare
    $data[8] = 0;
    # Contract
    $data[9] = qq/""/;
    # tricks
    $data[10] = qq/""/;
    # bid by
    $data[11] = qq/""/;
    # ns match points
    $data[12] = 0;
    # ew match points
    $data[13] = 0;
    # session
    $data[15] = $session;
    # spare
    $data[16] = 0;
    # spare
    $data[17] = 0;
    my($bn, $res); # this is the boardnumber and result hash
    my($r);
    my($travs) = $trs->boards();
    for ($bn = 1; $bn <= scalar(@$travs); $bn++) {
        $res = $travs->[$bn - 1];
        if (!defined($res)) {
            next;
        }
        foreach $r (@$res) {
            # and then each individual result for that traveller
            $data[BOARDNO] = $bn;
            $data[NSPAIR]  = $r->n();
            $pu->set($r->n(), $r->e());
            $data[EWPAIR]  = $r->e();

            my($special) = $r->special();
            if ($special) {
                $data[NSSCORE] = 0;
                $data[EWSCORE] = 0;

                my($adj);
                if ($special eq "P") {
                    $adj = "";
                } elsif ($special eq "A") {
                    $adj = "A5050";
                } else {
                    $adj = "A";
                    foreach my $i (1, 2) {
                        my($s) = substr($special, $i, 1);
                        if ($s eq "=") {
                            $adj .= "50";
                        } elsif ($s eq "-" ) {
                            $adj .= "40";
                        } elsif ($s eq "+") {
                            $adj .= "60";
                        } else {
                            die("Bad adjust string ($special) ",
                                "for board $bn\n");
                        }
                    }
                }
                $data[ADJUST] = qq/"$adj"/;
            } else {
                my($score) = $r->{points};
                $data[ADJUST] = qq/""/;
                if ($score < 0) {
                    $score = abs($score);
                    $data[EWSCORE] = $score;
                    $data[NSSCORE] = 0;
                } else {
                    $data[NSSCORE] = $score;
                    $data[EWSCORE] = 0;
                }
            }
            $fh->print("\t", join("\t", @data), "\n");
        }
    }
}

sub ptxt
{
    my($fh, $pm, $single, $pu) = @_;
    my(@data);

    # setup the fixed invariant fields.
    $data[0] = 0;
    $data[1] = 0;
    my($pn, $gn); # pair number and global number.
    while (($pn, $gn) = each(%$pm)) {
        $data[2] = $pn;   # pair number
        $data[3] = qq/"/ . $single->fullname($gn) . qq/"/;
        $data[4] = qq/"/ . $single->name1($gn) . qq/"/;
        $data[5] = qq/"/ . $single->name2($gn) . qq/"/;

        if ($pu->numberofwinners() == 1) {
            $data[6] = qq/""/;
        } elsif ($pu->playedns($pn)) {
            $data[6] = qq/"NS"/;
        } else {
            $data[6] = qq/"EW"/;
        }
        $data[7] = qq/"/ . $single->refnum1($gn) . qq/"/;
        $data[8] = qq/"/ . $single->refnum2($gn) . qq/"/;
        $fh->print("\t", join("\t", @data), "\n");
    }
}

1;
