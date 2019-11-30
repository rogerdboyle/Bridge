#
# $Id: Inactiveclient.pm 1650 2016-11-11 15:39:39Z phaff $
# Generate a list of inactive players.
# (6 months is the hardcode value).

#######################
package Inactiveclient;
#######################

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;

use Conf;
use lib "lib";
use Scorepositions;
use Sdate;
use Sql;
use Single;

sub usage
{
    my($msg) = @_;

    my($usemsg) = <<EOF;
inactive.pl YYYYMMDD
EOF

    die($msg, "\n", $usemsg);
}

sub main
{
    my($last);
    my($single);
    my($ret);
    my($datestr);
    # inactive months
    my($inmons) = 6;

    my($fh) = @_;

    if (!defined($fh)) {
        $fh = "STDOUT";
    }

    if (!defined($ARGV[0])) {
        die("Must specify a date argument, YYYYMMDD\n");
    }
    ($last) = $ARGV[0] =~ m/^(\d\d\d\d\d\d\d\d)/;
    if (!defined($last)) {
        die("The argument is not in the right format ($ARGV[0]) YYYYMMDD\n");
    }

    $datestr = simpledate($ARGV[0]);
    if (!defined($datestr)) {
        die("Unable to parse the folder argument ($ARGV[0]) as a date\n");
    }

    Sql->GetHandle($Conf::Dbname);

    my($edate) = $last + 0;
    my($sdate);
    my($year, $mon, $day) = $last =~ m/(\d\d\d\d)(\d\d)(\d\d)/;

    if ($inmons >= $mon) {
        $mon = $mon + 12 - $inmons;
        $year--;
    } else {
        $mon -= $inmons;
    }
    $sdate = $year * 10000 + $mon * 100 + $day;
    $single = Single->new();
    $ret = $single->load("contact.csv");
    if ($ret) {
        die("Loading the player database file contact.csv ",
            "has failed ($ret)\n");
    }
    if ($fh eq "STDOUT") {
        $fh->print("Start $sdate end date $edate\n");
    }
    my($files) = Sql->keys(Sql::SCORE);
    my($file);
    my(@sps);
    my($sp);
    my($lowdate) = $edate;
    my($lowdatestr);

    foreach $file (@$files) {
        # basename it
        $file =~ s:^.*/::;
        my($dateext);
        ($dateext) = $file =~ m/^(\d\d\d\d\d\d\d\d)/;
        if (!defined($dateext)) {
            $fh->print("Bad format, excluding ($file)\n");
        }
        if ($dateext <= $sdate) {
            next;
        }
        if ($dateext > $edate) {
            next;
        }
        if ($dateext < $lowdate) {
            $lowdate = $dateext;
        }

        $sp = Scorepositions->new();
        $sp->load($file);
        $sp->{filename} = $file;
        push(@sps, $sp);
    }
    my($players) = {};
    my($outer, $pent);

    foreach $sp (@sps) {
        # We have two loops, the outer for the n/s and e/w
        # pairs, and the inner of each participent.
        foreach $outer (@{$sp->{array}}) {
            foreach $pent (@$outer) {
                if (!defined($pent->{pair})) {
                    # anonymous scoring can have the pair set to
                    # undef.
                    next;
                }
                my(@p) = $single->break($pent->{pair});
                my($p);
                foreach $p (@p) {
                    if (!exists($players->{$p})) {
                        $players->{$p} = 1;
                    } else {
                        $players->{$p}++;
                    }
                }
            }
        }
    }
    # Sort on id number.
    my(@all) = sort({$a->id() <=> $b->id()} $single->sorted());
    my($p);

    my($done) = 0;
    foreach $p (@all) {
        if (!exists($players->{$p->id()})) {
            $fh->print($p->id(), " ", $p->cname(), " ",  $p->sname(), "\n");
            $p->notactive(1);
            $done = 1;
        }
    }
    # Only write if we have updated something.
    if ($done) {
        $single->savetofile();
    }
}
1;
