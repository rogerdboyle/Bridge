#!/usr/bin/perl

# Copyright (c) 2009 Paul Haffenden. All rights reserved.
# $Id: isetup.pl 1046 2013-02-22 19:35:35Z phaff $

use strict;
use warnings;

# Setup the result directory based on the beam data.

use File::Copy;
use IO::File;
use IO::Dir;
use Getopt::Std;

use Conf;

use Biff;
use Pairmap;
use Sdate;
use Setup;
use Move::Moveconfig;


our($usage) = <<EOF;

usage:
isetup [-e] YYYYMMDD

where:
-e               - don't create the traveller file.
YYYYMMDD         - is the day of the event.
EOF

sub usage
{
    my($msg) = @_;
    STDERR->print($msg, "\n", $usage);
    exit(1);
}

sub main
{
    my($dir);
    my($opts) = {};
    my($exclude) = 0;

    getopts("e", $opts);
    if ($opts->{e}) {
        $exclude = 1;
    }
    if (!defined($ARGV[0])) {
        die("No result directory specified\n");
    } else {
        my($parsecheck);
        $parsecheck = simpledate($ARGV[0]);
        if (defined($parsecheck)) {
            $dir = $ARGV[0];
        } else {
            usage("The date argument does not parse");
        }
    }

    my($dirsearch) = IO::Dir->new();

    if (!$dirsearch->open($Conf::biffdir)) {
        die("Unable to open the directory specified by $Conf::biffdir in the ",
            "configuration file $!\n");
    }
    my($bifffiles) = [];
    my($f);
    while ($f = $dirsearch->read()) {
        next if $f eq "." || $f eq "..";
        my($biff) = Biff->new();
        $biff->load("$Conf::biffdir/$f");
        push(@$bifffiles, $biff);
    }
    $dirsearch->close();


    # Check that all the biff files contain the same movement
    # number, before we look it up.
    my($biff);
    my($moveid);
    my($mpair);
    foreach $biff (@$bifffiles) {
        my($move);
        $move = int($biff->{moveid} / 10000);
        if (defined($moveid)) {
            if ($moveid != $move) {
                die("The biff file $biff->{fname} does not contain the ",
                    "expected moveid of $moveid but $move\n");
            }
        } else {
            $moveid = $move;
        }
    }
    # Find the missing pair, if any.
    $mpair = $moveid % 100;
    $moveid = int($moveid / 100);
    print("The moveid is $moveid The missing pair is $mpair\n");
    # Now try to find the movement file with an Id of $moveid.
    my($mc);
    if ($moveid) {
        if (!$dirsearch->open($Conf::movesdir)) {
            die("Unable to open the directory containing the movements $!\n");
        }
        while ($f = $dirsearch->read()) {
            next if $f eq "." || $f eq ".." || $f eq ".svn";
            $mc = Move::Moveconfig->new();
            my($fh) = IO::File->new();
            if (!$fh->open("$Conf::movesdir/$f", "<")) {
                die("Unable to open the moves file $Conf::movesdir/$f $!\n");
            }
            $mc->load($fh);
            $fh->close();
            if ($mc->{id} == $moveid) {
                # Bingo
                if ($mpair) {
                    $mc->set_excludepair($mpair);
                }
                $mc->generate();
                last;
            }
            undef($mc);
        }
        $dirsearch->close();
        if (!defined($mc)) {
            die("Unable to find a matching movement file for $moveid\n");
        }
    }
    if (!-d "$Conf::resdir/$dir") {
        if (!mkdir("$Conf::resdir/$dir")) {
            die("Failed to create the result directory ($Conf::resdir/$dir) $!\n");
        }
    }

    ## Can only set this up if we have a movement specified.
    if ($moveid) {
        my($setup) = Setup->new();
        $setup->nob($mc->get_nos() * $mc->get_bpr());
        $setup->bpr($mc->get_bpr());
        $setup->range($mc->get_range());
        $setup->moves($mc->get_moves());
        $setup->save($dir);
    }

    if (!$exclude) {
        # Create the traveller data file. (and by mistake the pairmap0
        my($trname) = "$Conf::resdir/$dir/tr.db";
        my($fh) = IO::File->new();
        if (!$fh->open($trname, ">")) {
            die("Failed to open the traveller data file $trname $!\n");
        }
        {
            my($rev) = getrevision();
            $fh->print("rev=$rev\n");
        }
        my($pm) = Pairmap->new();
        Biff::merge($fh, $bifffiles, $mc, $pm);
        $fh->close();
        # Write the pairmap
        $pm->save($dir);
        # Copy the raw biff files into the result directory.
        foreach $biff (@$bifffiles) {
            if (!copy($biff->{fname}, "$Conf::resdir/$dir")) {
                die("The copy from $biff->{fname} to ",
                    "$Conf::resdir/$dir failed $!\n");
            }
        }
    }
}

sub getrevision
{
    my($x) = join("", qx(svn info .));

    ($x) = $x =~ m/Revision: (\d+)/m;
    return($x);
}


main();
exit(0);
