# Convert Scorebridge files downloaded from Bridgewebs
# into KBS Score format.

# $Id$
# Copyright (c) 2012 Paul Haffenden. All rights reserved.
#
#####################
package Sb2kbsclient;
#####################

use strict;
use warnings;
use Text::CSV;
use Data::Dumper;
use Getopt::Std;
use IO::File;

use Pairmap;
use Masterpoints;
use Scorebridge;
use Scorepositions;
use Trs;
use Single;
use Sql;
use Alias;

use constant START => 0;
use constant CONFIGLINE => 1;
use constant SCORESTART => 2;
use constant SCORELINE => 3;
use constant LOOKTRAV => 4;
use constant INTRAV => 5;

sub main
{
    # do each input file one at a time
    my($arg);
    my($alias);
    my($opts) = {};

    getopts("t:", $opts);

    Sql->GetHandle($Conf::Dbname);

    foreach $arg (@ARGV) {
        my($single) = Single->new();
        my($ret) = $single->load("contact.csv");
        if ($ret) {
            die($ret, "\n");
        }
        $alias = Alias->new();
        $alias->load("aliases", $single);
        processfile($single, $alias, $arg, $opts->{t});
    }
}

sub processfile
{
    my($single, $alias, $fname, $winners) = @_;
    my($startgood) = "Tables, NTotal, ETotal, Pairs, Is 2 Winners, Min Details, ScoreMethod, Color";
    my($scorestart) = "Score Lines Count,Green Point, Is Handicapped, V3";
    my($teams) = "Teams Entered as Imps, Teams Boards, Boards Per Set";
    my($foundgood) = 0;
    my($secret_ind) = 1;
    my($refind) = \$secret_ind;

    STDERR->print("**************$fname*******************\n");

    my($csv) = Text::CSV->new(
     {
      binary => 1, sep_char => ",",
      quote_char => '"',
      escape_char => '"'
     });
    my($line);
    my($fh) = IO::File->new();
    my($ttot, $ntot, $etot);
    my($data);
    my($key) = $fname;
    $key =~ s:.*/::;
    ($data) = Scorebridge->load($key);

    if (!defined($data)) {
        die("I can't get the key $fname\n");
    }
    if (!$fh->open(\$data, "<")) {
        die("Failed to open data string $!\n");
    }
    my($count);
    my($ind);
    my($maxmp) = 0;
    my($sp) = Scorepositions->new();
    $ind = 0;
    my($pos) = 1;
    my($lastent) = undef;
    my($nob) = 0;
    my($nob_seen) = 0;
    my($travcount);
    my($travs) = [];
    my($win2);

    while ($line = $csv->getline($fh)) {
        if ($foundgood == START) {
            if ($line->[0] eq $startgood) {
                $foundgood = CONFIGLINE;
            }
            next;
        }
        if ($foundgood == CONFIGLINE) {
            $ttot = $line->[0];
            $ntot = $line->[1];
            $etot = $line->[2];
            $win2 = $line->[4];

            $foundgood = SCORESTART;
            next;
        }
        if ($foundgood == SCORESTART) {
            if ($line->[0] eq $teams) {
                $nob = $line->[2];
                next;
            }

            if ($line->[0] eq $scorestart) {
                $foundgood = SCORELINE;
                $count = 0;
            }
            next;
        }
        if ($foundgood == SCORELINE) {
            if (($count % 2) == 0) {
                if ($line->[6] > $maxmp) {
                    $maxmp = $line->[6];
                }
                #                  first pair, name, second pair, cname, sname
                my($names) = $line->[11] . "&" . $line->[12];
                my($pn) = $single->checknames_alias_update($alias, $names, $refind);

                my($setpos);
                my($ent) =
                  {
                   matchpair => $line->[0],
                   pair => $pn,
                   percent => ($line->[3] / 100) . "",
                   master => $line->[6],
                   score => $line->[8],
                   pos => 0,
                  };
                # Fudge the ew pair numbers in a two winer
                # movement.
                if ($win2 && $line->[7] eq "E") {
                    $ent->{matchpair} -= $ntot;
                }
                if (defined($lastent) && ($lastent->{percent} == $ent->{percent})) {
                    if ($lastent->{pos} =~ m/=/) {
                        # We already have the '='
                        $setpos = $lastent->{pos}
                    } else {
                        $setpos = $lastent->{pos} . "=";
                    }
                    $lastent->{pos} = $setpos;
                    $ent->{pos} = $setpos;
                } else {
                    $ent->{pos} = $pos;
                }
                $pos++;
                $lastent = $ent;
                $sp->addentry($ind, $ent);
            }
            $count++;
            if ($win2 && ($count == ($ntot * 2))) {
                $ind = 1;
                $pos = 1;
                $lastent = undef;
            }
            if ($count >= (($ntot + $etot) * 2)) {
                $foundgood = LOOKTRAV;
            }
            next;
        }
        if ($foundgood == LOOKTRAV) {
            if ($line->[0] =~ /^Score Lines then -/) {
                $foundgood = INTRAV;
                $travcount = 0;
                next;
            }
        }
        if ($foundgood == INTRAV) {
            if ($travcount == 0) {
                $travcount = $line->[0];
                if ($travcount == 0) {
                    $nob_seen++;
                }
                if ($nob_seen >= $nob) {
                    last;
                }
                next;
            }
            push(@{$travs->[$nob_seen]}, [ $line->[1], $line->[2], $line->[3] ]);
            $travcount--;
            if ($travcount == 0) {
                $nob_seen++;
            }
            if ($nob_seen >= $nob) {
                last;
            }
            next;
        }
    }
    # Fix up the match pairs.
    $sp->pair_refactor($travs);


    # We now have all scoreposition data and travvellers loaded.
    # See if we have any masterpoints allocated.
    if (!$sp->havemasters()) {
        print("I am calculating the masterpoints\n");
        $sp->domasters($travs);
    }


    my($dir); # work out my name for the results.
    $fname =~ s:.*/::;

    $dir = $fname;
    $sp->{maxmp} = $maxmp;

    $sp->save($dir);
    $single->savetofile();

    if (defined($winners) && ($winners > 0)) {
        # Load up the revision number.
        $Trs::rev = 850;
        # Don't write the traveller details out yet.
        my($trs) = Trs->new();
        $nob = 1;
        my($ent);
        foreach $ent (@$travs) {
            my($it);
            foreach $it (@$ent) {
                my($res) = SimpleR->new($it->[0], $it->[1], $it->[2]);
                $trs->add_result($nob, $res);
            }
            $nob++;
        }
        $trs->{editor} = 1;
        $trs->save($dir);
        do_pairmap($dir, $sp);
    }
}


sub do_pairmap
{
    my($dir, $sp) = @_;
    my($pm) = Pairmap->new();
    my($outer, $inner);

    my($base_ew);
    my($diff_ew);


    # We need to adjust the ew pair numbers.
    # sb use unique numbers, but keeps them sequential.
    if (scalar(@{$sp->{array}}) == 2) {
        # Two winner
        my($c0, $c1);
        my($max);
        $c0 = scalar(@{$sp->{array}->[0]});
        $c1 = scalar(@{$sp->{array}->[1]});
        $max = $c0;
        if ($c1 > $max) {
            $max = $c1;
        }
        if ($max > 10) {
            $diff_ew = 20;
        } else {
            $diff_ew = 10;
        }
        $base_ew = $c0 + 1;
    }


    foreach $outer (@{$sp->{array}}) {
        foreach $inner (@$outer) {

            my($ip) = $inner->{matchpair};
            if (defined($base_ew) && ($ip >= $base_ew)) {
                $ip = $ip - $base_ew + $diff_ew;
            }
            $pm->add($ip, $inner->{pair});
        }
    }
    $pm->save($dir);
}


################
package SimpleR;
################

# Create a simple result.
sub new
{
    my($class) = shift();
    my($n, $e, $score) = @_;

    my($self) = {
                 n => $n,
                 e => $e,
                 instr => "$n $e $score"
                };
    bless($self, $class);
    return $self;
}

sub n
{
    my($self) = shift;
    return $self->{n};
}
sub e
{
    my($self) = shift;
    return $self->{e};
}

sub instr
{
    my($self) = shift;
    return $self->{instr};
}

1;
