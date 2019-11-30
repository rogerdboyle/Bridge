
# Copyright (c) 2007 Paul Haffenden. All rights reserved.
# $Id: Bsetupclient.pm 1471 2015-10-09 05:45:56Z phaff $

#####################
package Bsetupclient;
#####################

use strict;
use warnings;

# Configure and setup the result data.

use Getopt::Long qw(:config no_ignore_case);
use IO::File;
use Data::Dumper;

use lib "lib";
use Conf;
use Sdate;
use Setup;
use Move::Moveconfig;


our($usage) = <<EOF;

usage:
bsetup { --boards(-b) number_of_boards --boardsperround(-r) boards_per_rounds
      --pairs(-p) pairranges |
      --setup(-s) setupfile
      --exclude(-e) pairno
      --rounds(-R) roundlimit
      --display(-d)
      --skipfirstround(-k) }
YYYYMMDD

where:
number_of_boards - the number of boards played in the session
pairranges       - the pair numbers used on the travellers, a
                   comma separated list of lowpair-highpair elements.
boards_per_round - the number of boards played per round.
setup            - the name of a setup file.
exclude          - which pair to ignore in the setup file for half-tables.
display          - display the setup file data.
roundlimit       - set a lower number of rounds than that specified in the
                   setup file.
skip             - discard the first round from the travellers
YYYYMMDD         - is the day of the event.

The script will create a new directory called YYYYMMDD and
create a setup.txt file that records the setup parameters.
EOF

sub usage
{
    my($msg) = @_;
    STDERR->print($msg, "\n", $usage);
    exit(1);
}

sub main
{
    my($pr);
    my($nob); # number of boards
    my($dir);
    my($parsecheck);
    my($fname);
    my($fh);
    my($setup);
    my($bpr); # number of rounds
    my($sup); # setup/movement file
    my($display);
    my($epair) = 0;
    my($roundslimit);
    my($mc);
    my($sfr) = 0;


    if (!GetOptions(
      'boards|b=i' => \$nob,
      'boardsperround|r=i' => \$bpr,
      'pairs|p=s' => \$pr,
      'setup|s=s' => \$sup,
      'display|d' => \$display,
      'rounds|R=i' => \$roundslimit,
      'exclude|e=i' => \$epair,
      'skip|k' => \$sfr)) {
        usage("Bad or missing option(s)");
    }

    # A display file has been specified.
    if ($sup) {
        my($fh) = IO::File->new();
        $mc = Move::Moveconfig->new();

        if (!$fh->open($sup, "<")) {
            die("Failed to open the movement file $sup\n");
        }
        $mc->load($fh);
        if ($display) {
            $mc->setoutput("STDOUT");
        }
        if ($epair) {
            $mc->set_excludepair($epair);
        }
        if ($bpr) {
            $mc->set_bpr($bpr);
        }
        $mc->generate($roundslimit);
        if ($display) {
            exit(0);
        }
    } else {
        if (!defined($nob)) {
            usage("Missing --boards argument");
        }

        if (!defined($bpr)) {
            usage("Missing --boardsperround argument");
        }

        if (!defined($pr)) {
            usage("Missing --pairs argument");
        }
    }
    if (!defined($ARGV[0])) {
        usage("Missing date argument");
    } else {
        $parsecheck = simpledate($ARGV[0]);
        if (defined($parsecheck)) {
            $dir = $ARGV[0];
        } else {
            usage("The date argument does not parse");
        }
    }
    if (!$sup) {
        # Check that we have an integral number of boards
        # played per round
        if ($nob % $bpr) {
            usage("The boards per round do not divide into the " .
                  "number of boards exactly");
        }
    }
    $setup = Setup->new();
    if ($sup) {
        my($moves);
        $setup->nob($mc->get_nos() * $mc->get_bpr());
        $setup->bpr($mc->get_bpr());
        $setup->range($mc->get_range());
        $moves = $mc->get_moves($sfr);
        $setup->moves($moves);
        # We have to list which pair starts at which table.
        my($tables) = [];
        my($ct);
        # Get round 1 table info
        $ct = $mc->get_ctltbl(1);
        my($t);
        foreach $t (@$ct) {
            my($topush) = [];
            foreach my $p ($t->{ns}, $t->{ew}) {
                if ($p == $epair) {
                    push(@$topush, 0);
                } else {
                    push(@$topush, $p + 0);
                }
            }
            push(@$tables, $topush);
        }
        $setup->tables($tables);

        # Sadly the tables and moves infomation
        # is not enough for bridgemates control,
        # so we add an extra field here, based on
        # rndctl from the $mc item. It is an array,
        # one entry for each round, which is an array
        # ref to a list of tables. Each table entry is
        # an array ref with three entries, ns, ew, and set.
        # We leave the missing pair intact and pass it
        # separately
        my($bmate) = [];
        my($rndctl) = $mc->{rndctl};
        my($rnd);
        my($not) = $mc->get_not();

        if ($sfr) {
            # If we are skipping the first round, discard it here
            # WARNING this has not been tested........
            shift(@$rndctl);
        }
        foreach $rnd (@$rndctl) {
            my($tbls) = [];
            my($t);
            for ($t = 1; $t <= $not; $t++) {
                my($tblinfo) = [];
                my($ct) = $rnd->{tables}->[$t - 1];
                push(@$tblinfo, $ct->{ns} + 0, $ct->{ew} + 0, $ct->{set});
                push(@$tbls, $tblinfo);
            }
            push(@$bmate, $tbls);
        }
        $setup->bmate($bmate);
        $setup->missing_pair($epair);
        $setup->winners($mc->get_winners());
    } else {
        $setup->nob($nob);
        $setup->range($pr);
        $setup->bpr($bpr);
    }
    $setup->save($dir);
    # remove the old email file.
    unlink("email.txt");
}

1;
