
# Copyright (c) 2011 Paul Haffenden. All rights reserved.
# $Id: Scoreclient.pm 1332 2014-08-09 13:18:52Z root $

####################
package Scoreclient;
####################

use strict;
use warnings;

use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Encode;
use Conf;
use Math::BigRat;

use lib "lib";
use Board;
use Pair;
use Pairmap;
use Pbn;
use Single;
use Masterpoints;
use Scorepositions;
use Sdate;
use Trs;
use Setup;
use Pairusage;

our($ofh);
our($tfh);
our($rev) = <<'EOF';
$Rev: 1332 $
EOF

our($out) = 1;  # Write the text results output to stdout.


# Write our style sheet here
our($stylesheet) = <<'EOF';
<style type="text/css">
body {
        font-family: "Verdana";
        background: #cccccc;
        text-align:center;
}

h1 {
        color: blue;
        text-align: center;
}

h2 {
        text-align: center;
}

table.center {
        margin-left: auto;
        margin-right: auto;
}

.copy {
        font-size: 0.60em;
        text-align: center;
}

caption {
        margin-left: auto;
        margin-right: auto;
}

span.redsuit {
        color: red;
        font-weight: normal;
        font-style: normal;
        font-size: 1.2em;
}
span.blacksuit {
        color: black;
        font-weight: normal;
        font-style: normal;
        font-size: 1.2em;
}

tr.row0 {
        color: black;
        background: #FCF6CF;
}
tr.row1 {
        color: black;
        background: #FEFEF2;
}

td.pts {
       color: black;
       background: #FCF6CF;
}

</style>
EOF

our($usagemsg) = <<EOF;
score.pl [--anon|-a] [--short | -s] [--bridgewebs | -b] [--nohtml | -h] [--text|-t] [--consise|-c] YYYYMMDD

Where YYYYMMDD is the name of the result directory
The options are:

--anon|-a
  Don't output any names, just pair numbers.

--short|-s
  output the results in short format, the contract, declarer  and card led
  details are not included in the results, and the individual scorecards
  are not generate.

--bridgewebs|-b
  output a file that uses the scoring format that is compatible with the
  BridgeWebs system.

--nohtml|-h
  don't generate the html output file.

--text|-t
  don't generate a text header file.

--concise|-c
  short text output, for newspaper reporting.

--nomp|-m
  Don't display the Masterpoints/Wilsons in the ranking

By default the score.pl program generates the following files in the
result directory:

tr.txt - the result table in text format

tr.htm - just the result table in html format.

trYYYYMMDD.htm - the results in html format, includes matrix, travellers
and pairs scorecards.
score.txt - the result table in perl 'Dumper' format.
bw_YYYYMMDD.csv - the results in bridgewebs format
EOF

our($short);

sub main
{
    my($fh);
    my($data);
    my($x);
    my($VAR1);
    my($bn);
    my($t);
    my($filerev);
    my($single);
    my($pm);
    my($trs);
    my($setup);
    my($bw);
    my($nohtml);
    my($anon);
    my($ebu);
    my($text);
    my($textoutput);
    # Where we store the output going to the html table.
    my($tblstr);
    my($textopt);
    my($concise);
    my($nomp) = 0; # Don't display the master points.
    my($stdout) = @_;

    if (!defined($stdout)) {
        $stdout = "STDOUT";
    }

    # Reset and discard all pair info.
    Pair::init();

    if (!GetOptions
        (
         'short|s' => \$short,
         'bridgewebs|b' => \$bw,
         'ebu|e' => \$ebu,
         'nohtml|h' => \$nohtml,
         'anon|a' => \$anon,
         'text|t' => \$textopt,
         'concise|c' => \$concise,
         'nomp|m' => \$nomp,
        )) {
        die("Failed to parse\n$usagemsg\n");
    }
    if ($textopt) {
        $text = 0;
    } else {
        $text = 1;
    }
    if (!defined($ARGV[0])) {
        die("Must specify a results' directory\n$usagemsg\n");
    }
    my($datestr);
    $datestr = simpledate($ARGV[0]);
    if (!defined($datestr)) {
        die("Unable to parse the folder argument ($ARGV[0]) as a date\n");
    }

    $trs = Trs->new();
    $trs->load($ARGV[0]);
    if (!defined($Trs::rev)) {
        die("The traveller file is empty!\n");
    }
    $filerev = $Trs::rev;

    $setup = Setup->new();
    $setup->load($ARGV[0]);
    if (!defined($setup->bpr())) {
        die("The boards per round field is not set in the setup.txt file\n");
    }
    $bn = $setup->nob();

    $single = Single->new();
    my($ret, $rea);
    $ret = $single->load("contact.csv");
    if ($ret) {
        die($ret, "\n");
    }
    $pm = Pairmap->new();
    if (!$pm->load($ARGV[0])) {
        die("Failed to load the pairmap file ",
            "$ARGV[0]\n");
    }

    my($pbn);
    my($pbnfile) = "$Conf::resdir/$ARGV[0]/tr.pbn";
    if (-e $pbnfile) {
        $pbn = Pbn->new();
        ($ret, $rea) = $pbn->load($pbnfile);
        if (!$ret) {
            $stdout->print("Failed to load pbn file ($rea)\n");
            undef($pbn);
        }
    }

    if (!$nohtml) {
        $ofh = IO::File->new();
        if (!$ofh->open(\$tblstr, ">")) {
            die("Failed to open the html data stream $!\n");
        }
    }
    $tfh = IO::File->new();
    if (!$tfh->open(\$textoutput, ">")) {
        $stdout->print("Error\n");
        die("Failed to open the text stream header file $!\n");
    }
    if ($ofh) {
        $ofh->print(<<EOF);
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html>
<title>
$Conf::Club Results
</title>
$stylesheet
<body>
<h1>
$Conf::Club Results
</h1>
<h2>
$datestr
</h2>
EOF
    }
format head =
@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$_[0]
.

format dash =
------------------------------------------------------------------------------
.

format header =
|Pos| Name                                          |Pair| Score|   %  | WP  |
.

format line =
|@<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<|@##.##| @#.##| @<<<|
$_[0], $_[1], $_[2], $_[3], $_[4], $_[5], $_[6], $_[7]
.



    $tfh->print("\n\n");
    writeformat($tfh, "head", "$Conf::Club Results");
    writeformat($tfh, "head", "$datestr");
    $tfh->print("\n\n");

    # The main results.
    my($travs) = $trs->boards();

    # We have to use the Neuberg score adjustments,
    # and to do that we require the session score.
    # Put all this in a separate function.

    my($pu) = Pairusage->new();

    scoretrav($travs, $pu);

    # The Pairusage object will determine the number
    # of winners.
    $pu->process($setup->bpr());
    my($winners) = $pu->numberofwinners();

    my(@pairgroups);
    my(@pairs);
    my($pos);
    my($pn);

    @pairgroups = Pair->pairlist($pu);


    my($sp) = Scorepositions->new();
    my($spent);
    my($doew) = 0;
    my($points_not_integer) = 0;
    my($unmodpoints_not_integer) = 0;

#    print("Minimum boards played: ", $pu->minboardsplayed(), "\n");

    my(@totalmpawards) = Masterpoints::mppoints(
                           $pu->minboardsplayed(),
                           scalar(Pair->pairs()),
                           ($winners == 2));

    $sp->{maxmp} = $totalmpawards[0];

    foreach my $pg (@pairgroups) {
        @pairs = @$pg;

        # Now normalise the score for those pairs that didn't play
        # the same number of boards
        my($maxpts);
        $maxpts = 0;
        foreach $pn (@pairs) {
            #print("$pn->{pn} Pts/Total: ", round($pn->{pts}),
            #"/$pn->{tpts}\n");
            if ($pn->{tpts} > $maxpts) {
                $maxpts = $pn->{tpts};
            }
        }
        foreach $pn (@pairs) {
            $pn->{unmodpts} = $pn->{pts};
            $pn->{unmodtpts} = $pn->{tpts};
            if ($pn->{tpts} < $maxpts) {
                $pn->{pts} = ($pn->{pts} * $maxpts) / $pn->{tpts};
                $pn->{tpts} = $maxpts;
            }
        }
        # Now recalculate the percentages
        foreach $pn (@pairs) {
            if ($pn->{tpts} == 0) {
                $pn->{per} = Math::BigRat->new(0);
            } else {
                $pn->{per} = ($pn->{pts} * 100) / $pn->{tpts};
            }
            if (!$pn->{pts}->is_int()) {
                $points_not_integer = 1;
            }
            if (!$pn->{unmodpts}->is_int()) {
                $unmodpoints_not_integer = 1;
            }
            $pn->{mp} = 0;
            # Always round the percentage.
            round($pn->{per});
        }
        # Sort them on percentage total;
        @pairs = sort({$b->{per} cmp $a->{per} } @pairs);

        # construct the position number.
        $pos = 1;

        # Construct an array to ease master point calculation.
        my($mp);
        $mp = [];
        for ($pn = 0; $pn < @pairs; $pn++) {
            if (($pn > 0) &&
              (($pairs[$pn]->{per} == $pairs[$pn - 1]->{per}))) {
                    # add a trailing "="
                    if ($pairs[$pn - 1]->{pos} !~ m/=/) {
                        $pairs[$pn - 1]->{pos} .= "=";
                    }
                    $pairs[$pn]->{pos} = $pairs[$pn - 1]->{pos};
                    push(@{$mp->[-1]}, $pn);
            } else {
                $pairs[$pn]->{pos} = $pos;
                push(@$mp, [ $pn ])
            }
            $pos++;
        }

        my($ind) = 0;
        my(@mpawards) = @totalmpawards;

        while (@mpawards) {
            my($num);
            my($tot);
            my($i);
            my($n);
            # Number of pairs that have this award.
            $num = scalar(@{$mp->[$ind]});
            $i = $num;
            $tot = 0;
            while ($i-- > 0) {
                $n = shift(@mpawards);
                if (defined($n)) {
                    $tot += $n;
                }
            }
            $n = int($tot / $num);
            # The minimum number of master points awarded is 6.
            # enforce this here.
            if ($n < 6) {
                $n = 6;
            }
            foreach $pn (@{$mp->[$ind]}) {
                $pairs[$pn]->{mp} = $n;
            }
            $ind++;
        }

# The output of the results start here.......

        # Print out the main results
        if ($ofh) {
            table();
        }
        if ($winners == 2) {
            if ($doew == 0) {
                writeformat($tfh, "head", "Results for North/South pairs");
                if ($ofh) {
                    caption("Results for North/South pairs");
                }
            } else {
                writeformat($tfh, "head", "Results for East/West pairs");
                if ($ofh) {
                    caption("Results for East/West pairs");
                }
            }
        } else {
            writeformat($tfh, "head", "Results");
            if ($ofh) {
                caption("Results");
            }
        }
        writeformat($tfh, "dash");
        writeformat($tfh, "header");
        writeformat($tfh, "dash");
        if ($ofh) {
            tablerow();
            tableent("Pos");
            tableent("Name");
            tableent("Pair");
            tableent("Points");
            tableent("%");
            if (!$nomp) {
                tableent("WP");
            }
            tablerowend();
        }
        foreach $pn (@pairs) {
            my($fpn);
            my($mpoh);
            my($mpot);
            my($mpo);
            my($fpnumber);
            $fpnumber = $pm->{$pn->{pn}};
            if ($anon) {
                $fpn = "Pair $pn->{pn}";
            } elsif (!$fpnumber) {
                $fpn = "Unknown pair $pn->{pn}";
            } else {
                $fpn = $single->fullname($fpnumber);
            }
            # Master points
            $mpo = $pn->{mp};
            if (!$mpo) {
                $mpoh = "&nbsp;";
                $mpot = "";
            } else {
                $mpoh = $mpo;
                $mpot = $mpo;
            }
            if ($ofh) {
                my($ptsout);

                if ($points_not_integer) {
                    $ptsout = $pn->{pts};
                    round($ptsout);
                } else {
                    $ptsout = $pn->{pts}->as_int;
                }

                tablerow();
                tableent($pn->{pos});
                my($ampfpn) = $fpn;
                $ampfpn =~ s/&/\&amp;/g;
                tableent(qq/<a href="#$pn->{pn}">/ . $ampfpn  .
                         "</a>");
                tableent($pn->{pn});

                tableent($ptsout);
                tableent($pn->{per});
                if (!$nomp) {
                    tableent($mpoh);
                }
                tablerowend();
            }
            # The 'format' lines don't like non-ascii characters.
            # Here we change any such beasts into a plain underscore.
            my($ascii) = "";
            foreach my $ch (split('', $fpn)) {
                if (ord($ch) < 0x7f) {
                    $ascii .= $ch;
                } else {
                    $ascii .= "_";
                }
            }
            writeformat($tfh, "line",
                        $pn->{pos},
                        $ascii,
                        $pn->{pn},
                        sprintf("%2.2f", $pn->{pts}),
                        sprintf("%2.2f", $pn->{per}),
                        $mpot);
            my($ptsout) = $pn->{pts};
            if ($points_not_integer) {
                round($ptsout);
            } else {
                $ptsout = $ptsout->as_int() . "";
            }
            $spent = {
                      pos => $pn->{pos},
                      pair => $fpnumber,
                      matchpair => $pn->{pn},
                      master => $mpo,
                      percent => sprintf("%2.2f", $pn->{per}),
                      score => $ptsout,
                     };
            $sp->addentry($doew, $spent);
        }
        if ($ofh) {
            tableend();
        }
        writeformat($tfh, "dash");
        $tfh->print("\n\n");
        if ($winners == 2) {
            $doew = 1;
        }
    }
    $sp->save($ARGV[0]);
    # If we don't want a text file, write it in htnl.
    if (!$nohtml) {
        $tfh = IO::File->new();
        if (!$tfh->open("tr.htm", ">:encoding(utf8)")) {
            die("Failed to open the html header result file ",
                "tr.htm $!\n");
        }
        # duplicate what we have already written to the main header file.
        # However, turn off the links and the blue colour.
        my($hstr) = $tblstr;
        $hstr =~ s/^\s*color:\s*blue\s*;\s*$//m;
        $hstr =~ s/<a href=.*">//g;
        $hstr =~ s:</a>::g;
        $tfh->print($hstr);
        $tfh->print("</body>\n");
        $tfh->print("</html>\n");
        $tfh->close();
    }
#### end of position table
    my($rowcnt) = 0;
    if ($ofh) {
        $ofh->print("<h1>Results by Board</h1>\n");
        table();
        tablerow();
        tableent("Pair", qq/rowspan="2"/);
        tableent("Board Number", qq/colspan="$bn" align="center"/);
        tableent("Total", qq/rowspan="2"/);
        tablerowend();

        tablerow($rowcnt++);
        for ($t = 1; $t <= $bn;$t++) {
            tableent($t);
        }
        tablerowend();
    }


    @pairs = ();
    # Covert into full list, it may have been split
    foreach my $pg (@pairgroups) {
        push(@pairs,@$pg)
    }

    # sort in ascending order by pair number
    @pairs = sort ({ $a->{pn} <=> $b->{pn}} @pairs);
    my($pair);

    if ($ofh) {
        for $pair (@pairs) {
            tablerow($rowcnt++);
            $pn = $pair->{pn};
            tableent($pn);
            for($t = 1; $t <= $bn; $t++) {
                my($resa);
                my($pts);
                my($r);

                $resa = $trs->boards()->[$t - 1];
                foreach $r (@$resa) {
                    if ($r->{n} == $pn) {
                        $pts = $r->{nsp};
                        last;
                    } elsif ($r->{e} == $pn) {
                        $pts = $r->{ewp};
                        last;
                    }

                }
                if (!defined($pts)) {
                    $pts = "XX";
                } else {
                    $pts = roundif($pts);
                }
                tableent($pts);
            }
            {
                my($ptsout);
                if ($unmodpoints_not_integer) {
                    $ptsout = $pair->{unmodpts};
                    round($ptsout);
                } else {
                    $ptsout = $pair->{unmodpts}->as_int();
                }
                tableent($ptsout);
            }
            tablerowend();
        }
        tableend();

    # This is all the traveller data
    # Start the main table to force two columns
        $ofh->print("<h1>Travellers</h1>\n");


        for($t = 1; $t <= $bn; $t++) {
            my(@res);
            my($r);
            # Outside table, but if we have an odd number of table,
            # place the last table by itself.
            if ($t % 2) {
                # This is an odd entry, start a new outer table.
                if ($bn != $t) {
                    tableq();
                    tablerow();
                    tabledata();
                }
            } else {
                tabledata();
            }

            # inside table(s)
            # generate a traveller table.
            generatetravtable($trs, $t, $pm, $single, $short, $anon);

            if ($pbn) {
                generatepbndata($pbn, $t);
            }
            # if it an even boardnumber, then
            # we want end the outer table,
            # end the row, and complete the table
            if (($t % 2) == 0) {
                tabledataend();
                tablerowend();
                tableend();
            } else {
                # we are an odd number,
                # so close the outer table entry
                # unless we are doing the last odd
                # table
                if ($t != $bn) {
                    tabledataend();
                }
            }
        }

        if (!$short) {
            # The personal scorecards.
            foreach $pair (@pairs) {
                my($names);
                my($gid);
                my($pn);

                $pn = $pair->{pn};
                $gid = $pm->{$pn};
                if ($anon) {
                    $names = "Pair $pn";
                } elsif (!$gid) {
                    $names = "Unknown pair $pn";
                } else {
                    $names = $single->fullname($gid);
                }
                if ($ofh) {
                    $ofh->print("<hr>\n");
                    $ofh->print(qq:<p><a name="$pn"> </a></p>\n:);
                }
                table();
                caption("$names ($pn)");
                tablerow();
                tableent("Board");
                tableent("Vul");
                tableent("As");
                tableent("Versus");
                tableent("Con");
                tableent("By");
                tableent("Lead");
                tableent("Tricks");
                tableent("Score");
                tableent("MP+");
                tableent("MP-");
                tablerowend();

                my($lastname) = "";
                my(@col);
                my($col) = 1;

                for ($t = 1; $t <= $bn; $t++) {
                    my($as) = "";
                    my($op);
                    my($opname);
                    my($r);
                    my($x);

                    foreach $x (@{$trs->boards()->[$t - 1]}) {
                        if ($pn == $x->n()) {
                            $op = $x->e();
                            last;
                        } elsif ($pn == $x->e()) {
                            $op = $x->n();
                            last;
                        }
                    }
                    if ($op) {
                        if ($anon) {
                            $opname = "Pair $op";
                        } elsif (!$pm->{$op}) {
                            $opname = "Unknown pair $op";
                        } else {
                            $opname = $single->fullname($pm->{$op}) . " ($op)";
                        }
                    } else {
                        $opname = "";
                    }
                    if ($opname ne $lastname) {
                        $col++;
                    }
                    $lastname = $opname;
                    $col[$t] = $col;
                }

                $lastname = "";
                for ($t = 1; $t <= $bn; $t++) {
                    my($as) = "";
                    my($op);
                    my($opname);
                    my($r);
                    my($x);

                    tablerow($col[$t]);
                    tableent($t);
                    tableent(Board->vulstr($t));
                    foreach $x (@{$trs->boards()->[$t - 1]}) {
                        if ($pn == $x->n()) {
                            $as = "NS";
                            $op = $x->e();
                            $r = $x;
                            last;
                        } elsif ($pn == $x->e()) {
                            $as = "EW";
                            $op = $x->n();
                            $r = $x;
                            last;
                        }
                    }
                    if (!$as) {
                        tableent("");
                        tableent("");
                        tableent("");
                        tableent("");
                        tableent("");
                        tableent("");
                        tableent("");
                        tableent("");
                        tableent("");
                        tablerowend();
                        next;
                    }
                    tableent($as);

                    if ($op) {
                        if ($anon) {
                            $opname = "Pair $op";
                        } elsif (!$pm->{$op}) {
                            $opname = "Unknown pair $op";
                        } else {
                            $opname = $single->fullname($pm->{$op}) . " ($op)";
                        }
                        if ($opname eq $lastname) {
                            $opname = '"';
                        } else {
                            $lastname = $opname;
                        }
                    } else {
                        $lastname = "";
                        $opname = "";
                    }
                    tableent($opname, 'align="center"');

                    my($contxt);

                    if ($op) {
                        if ($r->{special}) {
                            if ($r->{special} eq "P") {
                                tableent("Pass");
                            } else {
                                tableent($r->{special});
                            }
                            tableent("-");
                            tableent("-");
                            tableent("-");
                        } else {
                            if ($r->score()) {
                                my($suit);
                                $suit = suit($r->{score}->{suit});
                                $contxt = $r->{score}->{level} .
                                  $suit .
                                    $r->{score}->{doublestr};
                                if ($r->{score}->{contricks}) {
                                    $contxt .= $r->{score}->{contricks};
                                }
                                tableent($contxt);
                                tableent($r->{by});
                                if (!$r->{lead}) {
                                    tableent("-");
                                } else {
                                    my($rank , $s);
                                    ($rank, $s) = $r->{lead} =~ m/(.)(.)/;
                                    $rank =~ s/X/x/;
                                    $s = suit($s);
                                    tableent("$rank$s");
                                }
                                tableent($r->{score}->{tricks});
                            } else {
                                # contract
                                tableent("-");
                                # by
                                tableent("-");
                                # lead
                                tableent("-");
                                # tricks
                                tableent("-");
                            }
                        }
                        if ($r->{special} eq "A") {
                            tableent("-");
                        } else {
                            if ($as eq "EW") {
                                tableent($r->{points} * -1);
                            } else {
                                tableent($r->{points});
                            }
                        }
                        if ($as eq "EW") {
                            my($ptsout);
                            $ptsout = roundif($r->{ewp});
                            tableent($ptsout);

                            $ptsout = roundif($r->{nsp});
                            tableent($ptsout);
                        } else {
                            my($ptsout);
                            $ptsout = roundif($r->{nsp});
                            tableent($ptsout);

                            $ptsout = roundif($r->{ewp});
                            tableent($ptsout);
                        }
                    }
                    tablerowend();
                }
                tableend();
            }
        }
    }
    # The end of the html file.
    ($filerev) = $filerev =~ m/(\d+)/;
    ($rev) = $rev =~ m/(\d+)/;
    if ($ofh) {
        $ofh->print(<<EOF);
<div class="copy">
&copy; 2010 $Conf::Copyholder<br>
trav.pl: $filerev<br>
score.pl: $rev
</div>
EOF
        $ofh->print("</body>\n");
        $ofh->print("</html>\n");
        $ofh->close();
        # We have written the table data to a string, $tblstr.
        # Do the real io now.
        if (!$ofh->open("tr$ARGV[0].htm", ">:encoding(utf8)")) {
            die("Failed to open the output file ",
                "tr$ARGV[0].htm $!\n");
        }
        $ofh->print($tblstr);
        $ofh->close();
    }
    $tfh->close();
    if ($out) {
        $stdout->print($textoutput);
    }
    if ($text) {
        if (!$tfh->open("tr.txt", ">:raw")) {
            die("Failed to output text file (tr.txt) $!\n");
        }
        $tfh->print($textoutput);
        $tfh->close();
    }
    if ($bw) {
        generatebridgewebsfile($ARGV[0], $sp, $trs->boards(), $single, $anon, $nomp);
    }

    if ($ebu) {
        eval "require Usebio;";
        if (!$@) {
            # only attemnpt a score if the module loaded
            my($ebuobj) = Usebio->new(1);
            $ebuobj->generate($ARGV[0], $sp, $trs, $single, $anon);
        }
    }
    if ($concise) {
        concise_output($ARGV[0], $sp, $single);
    }
}

sub suit
{
    my($s) = @_;
    my($suit);

    if ($s eq "S") {
        $suit = qq:<span class="blacksuit">&#9824;</span>:;
    } elsif ($s eq "H") {
        $suit = qq:<span class="redsuit">&#9829;</span>:;
    } elsif ($s eq "D") {
        $suit = qq:<span class="redsuit">&#9830;</span>:;
    } elsif ($s eq "C") {
        $suit = qq:<span class="blacksuit">&#9827;</span>:;
    } else {
        $suit = "NT";
    }
    return ($suit);
}
sub table
{
    my($barg) = @_;

    if (!defined($barg)) {
        $barg = 1;
    }
    $ofh->print(qq/<table border="$barg" frame="box" class="center">\n/);
}

sub tableq
{
    $ofh->print(qq/<table class="center">\n/);

}
sub tablerow
{
    my($alt) = @_;
    if ($alt) {
        $alt = int($alt % 2);
        $ofh->print(qq:<tr class="row$alt">:);
    } else {
        $ofh->print("<tr>\n");
    }
}
sub tableent
{
    my($msg, $attr) = @_;
    if (!defined($msg)) {
        die("Passed null value in tableent\n");
    }
    if (!defined($attr)) {
        $attr = "";
    }
    $ofh->print("<td $attr>$msg</td>\n");
}
sub tablerowend
{
    $ofh->print("</tr>\n");
}
sub tableend
{
    $ofh->print("</table>\n");
}
sub caption
{
    my($msg, $vul) = @_;

    if (!defined($vul)) {
        $vul = "";
    }
    $ofh->print("<caption>$msg $vul</caption>\n");
}

sub tabledata
{
    my($width) = @_;
    if (!defined($width)) {
        $ofh->print("<td>\n");
    } else {
        $ofh->print(qq/<td width=33% align="left">\n/);
    }
}
sub tabledataend
{
    $ofh->print("</td>\n");
}

sub writeformat
{
    my($fh) = shift();
    my($format) = shift();

    $fh->format_name($format);
    write($fh);
}


sub scoretrav
{
    my($travs, $pu) = @_;
    my($trav);

    my($M) = Math::BigRat->new(0);
    # First calculate the board that has been played the
    # most, and use that to set $M, used for Neuberg adjustments.
    foreach $trav (@$travs) {
        if (!defined($trav)) {
            $trav = [];
        }
        my($ents) = scalar(@$trav);
        if ($ents > $M) {
            $M = $ents;
        }
    }
    # First rescore each traveller.
    foreach $trav (@$travs) {
        # This will apply any required Neuberg adjustmants.
        rescore($trav, $M);
    }

    foreach $trav (@$travs) {
        my($r, $tot);
        $tot = ($M - 1) * 2;
        foreach $r (@$trav) {
            my($ns, $ew);
            my($np, $ep);
            $ns = $r->{n};
            $ew = $r->{e};
            $pu->set($ns, $ew);
            $np = Pair->getpair($ns);
            $ep = Pair->getpair($ew);

            if (substr($r->{special}, 0, 1) ne "A") {
                $np->add($r->{nsp});
                $np->addtot($tot);
                $ep->add($r->{ewp});
                $ep->addtot($tot);
            }
        }
    }
    # Now we have all the raw scores, minus any director awarded ones.
    # Calculate the session score for each pair.
    my(@pairs, $pn);
    @pairs = Pair->pairs();
    foreach $pn (@pairs) {
        if ($pn->{tpts} >  0) {
            $pn->{per} = ($pn->{pts} * 100) / $pn->{tpts};
        } else {
            $pn->{per} = Math::BigRat->new(0);
        }
    }

    # Now march down the travellers again, looking for awarded scores.
    foreach $trav (@$travs) {
        my($r, $avg, $tot);
        $avg = Math::BigRat->new($M - 1);
        $tot = $avg * 2;
        foreach $r (@$trav) {
            my($ns, $ew);
            my($np, $ep);
            my($p);
            if (substr($r->{special}, 0, 1) eq "A") {
                my($astr);
                my($fac);

                $ns = $r->{n};
                $ew = $r->{e};
                $np = Pair->getpair($ns);
                $ep = Pair->getpair($ew);
                if ($r->{special} eq "A") {
                    $astr = [ "=", "=" ];
                } else {
                    $astr = [ substr($r->{special}, 1, 1),
                                     substr($r->{special}, 2, 1) ];
                }
                foreach $p ([$np, "nsp", $astr->[0]], [$ep, "ewp", $astr->[1]]){
                    my($new);
                    if ($p->[2] eq "=") {
                        $p->[0]->add($avg);
                        $p->[0]->addtot($tot);
                        $r->{$p->[1]} = $avg;
                    } elsif ($p->[2] eq "+") {

                        # An average plus.
                        # First check the session score,
                        # if it is higher than 60%, use it instead
                        if ($p->[0]->{per} > 60) {
                            $fac = $p->[0]->{per};
                        } else {
                            $fac = 60;
                        }
                        $new = ($tot * $fac) / 100;
                        $p->[0]->add($new);
                        $p->[0]->addtot($tot);
                        $r->{$p->[1]} = $new;
                    } elsif ($p->[2] eq "-") {
                        # An average minus
                        # First check the session score,
                        # if it is less  than 40%, use it instead
                        if ($p->[0]->{per} < 40) {
                            $fac = $p->[0]->{per};
                        } else {
                            $fac = 40;
                        }
                        $new = ($tot * $fac) / 100;
                        $p->[0]->add($new);
                        $p->[0]->addtot($tot);
                        # Now we have totalled it, round.
                        $r->{$p->[1]} = $new;
                    } else {
                        die("Unknown average specified $p->[2]\n");
                    }
                }
            }
        }
    }
}

sub rescore
{
    my($trav, $M) = @_;
    my($r);
    my($out, $in);
    # The Neuberg variables.
    my($S); # Number of times board actually played

    # First clear all the existing points.

    foreach $r (@$trav) {
        $r->{nsp} = Math::BigRat->new(0);
        $r->{ewp} = Math::BigRat->new(0);
    }
    $S = Math::BigRat->new(0);
    # Every other scoring program uses a frequency chart.
    # So I'll do it too......

    # The frequency hash
    my($freq) = {};
    foreach $r (@$trav) {
        if (substr($r->{special}, 0, 1) eq "A") {
            # Skip any specials.
            next;
        }
        $S++;
        if (!exists($freq->{$r->{points}})) {
            $freq->{$r->{points}} = 1;
        } else {
            $freq->{$r->{points}}++;
        }
    }
    my($fkeys) = [ keys(%$freq) ];
    $fkeys = [ sort({$b <=> $a} @$fkeys) ];

    # Use the freq hash to store the number of
    # points we should allocate to each NS pair.

    # Most points to allocate
    my($totpts) = ($S - 1) * 2;
    my($pts) = $totpts;
    foreach my $key (@$fkeys) {
        my($num) = $freq->{$key};
        # We overwrite the count here!
        $freq->{$key} = $pts - ($num - 1);
        $pts -= 2 * $num;
    }

    # Now allocate the points.
    foreach $r (@$trav) {
        if (substr($r->{special}, 0, 1) eq "A") {
            # Skip any specials.
            next;
        }
        $r->{nsp} = $freq->{$r->{points}};
        $r->{ewp} = $totpts - $freq->{$r->{points}};
    }
    if ($S < $M) {
        # We must apply Neuberg
        for $r (@$trav) {
            next if substr($r->{special}, 0, 1) eq "A"; # Can't do this yet
            $r->{nsp} = neuberg($M, $S, $r->{nsp});
            $r->{ewp} = neuberg($M, $S, $r->{ewp});
        }
    }
}


sub neuberg
{
    # M = total entries to adjuect to
    # S = Actual entries provided
    # P = origianl scfore (from S entries)
    my($M, $S, $P) = @_;

    if (defined($Conf::noneuberg) && $Conf::noneuberg) {
        return ($P + $M - $S);
    } else {
        return ( (($P * $M) + ($M - $S)) / $S);
    }
}

sub round
{
    my($str);
    $str = sprintf("%.2f", $_[0]);
    $_[0] = $str;
}

sub roundif
{
    my($in) = @_;

    if (!defined($in)) {
        die("roundif is not defined ", caller(), "\n");
    }
    if ($in->is_int) {
        return $in->as_int();
    } else {
      round($in);
      return $in;
  }
}

sub generatepbndata
{
    my($pbn, $bno) = @_;

    # We create a 3x3 table, without a border.
    if (!$pbn->validboard($bno)) {
        return;
    }

    table(0);
    tablerow();
    nohandprint();
    handprint($pbn, $bno, PBN_NORTH, "North");
    nohandprint();
    tablerowend();

    tablerow();
    handprint($pbn, $bno, PBN_WEST, "West");
    nohandprint();
    handprint($pbn, $bno, PBN_EAST, "East");
    tablerowend();

    tablerow();
    nohandprint();
    handprint($pbn, $bno, PBN_SOUTH, "South");
    nohandprint();
    tablerowend();
    tableend();
}

sub nohandprint
{
    tabledata(1);
    $ofh->print("&nbsp;");
    tabledataend();
}

sub handprint
{
    my($pbn, $bno, $hand, $lab) = @_;
    my($i);
    tabledata(1);
    $ofh->print($lab, "<br>\n");
    $ofh->print(suit("S"), $pbn->getstr($bno, $hand, PBN_SPADES), "<br>\n");
    $ofh->print(suit("H"), $pbn->getstr($bno, $hand, PBN_HEARTS), "<br>\n");
    $ofh->print(suit("D"), $pbn->getstr($bno, $hand, PBN_DIAMONDS), "<br>\n");
    $ofh->print(suit("C"), $pbn->getstr($bno, $hand, PBN_CLUBS), "<br>\n");
    tabledataend();
}

sub generatetravtable
{
    my($trs, $t, $pairs, $single, $short, $anon) = @_;
    my($r);
    my($attr) = qq/class="pts"/;

    table();
    caption("Board $t", Board->vulstr($t));
    tablerow();

    # Allow a short table format.
    if ($short) {
        tableent("NS");
        tableent("EW");
        tableent("Score+", $attr);
        tableent("Score-", $attr);
        tableent("NSP");
        tableent("EWP");
    } else {
        tableent("NS");
        tableent("EW");
        tableent("CON");
        tableent("By");
        tableent("Lead");
        tableent("Tricks");
        tableent("Score");
        tableent("NSP");
        tableent("EWP");
    }
    tablerowend();




    foreach $r (@{$trs->boards()->[$t - 1]}) {
        my($contxt);
        tablerow();

        my($tname);

        if (exists($pairs->{$r->{n}})) {
            if ($anon) {
                $tname = "Pair $r->{n}";
            } else {
                $tname = $single->fullname($pairs->{$r->{n}});
            }
            tableent($r->{n}, qq/title="$tname"/);
        } else {
            tableent($r->{n});
        }

        if (exists($pairs->{$r->{e}})) {
            if ($anon) {
                $tname = "Pair $r->{e}";
            } else {
                $tname = $single->fullname($pairs->{$r->{e}});
            }
            tableent($r->{e}, qq/title="$tname"/);
        } else {
            tableent($r->{e});
        }

        if ($short) {
            if ($r->{special} && $r->{special} ne "P") {
                my($one, $two);
                if (length($r->{special}) == 1) {
                    $one = "A";
                    $two = "A";
                } else {
                    $one = "A" . substr($r->{special}, 1, 1);
                    $two = "A" . substr($r->{special}, 2, 1);
                }
                tableent($one, $attr);
                tableent($two, $attr);
            } else {
                my($pts) = $r->{points};
                if ($pts == 0) {
                    tableent(0, $attr);
                    tableent(0, $attr);
                } elsif ($pts > 0) {
                    tableent($pts, $attr);
                    tableent("&nbsp;", $attr);
                } else {
                    tableent("&nbsp;", $attr);
                    tableent($pts * -1, $attr);
                }
            }
        } else {
            if ($r->{special}) {
                if ($r->{special} eq "P") {
                    tableent("Pass");
                } else {
                    tableent($r->{special});
                }
                tableent("-");
                tableent("-");
                tableent("-");
            } else {
                if ($r->score()) {
                    my($suit);
                    $suit = suit($r->{score}->{suit});
                    $contxt = $r->{score}->{level} .
                      $suit .
                        $r->{score}->{doublestr};
                    if ($r->{score}->{contricks}) {
                        $contxt .= $r->{score}->{contricks};
                    }
                    tableent($contxt);
                    tableent($r->{by});
                    if (!$r->{lead}) {
                        tableent("-");
                    } else {
                        my($rank , $s);
                        ($rank, $s) = $r->{lead} =~ m/(.)(.)/;
                        $rank =~ s/X/x/;
                        $s = suit($s);
                        tableent("$rank$s");
                    }
                    tableent($r->{score}->{tricks});
                } else {
                    # contract
                    tableent("-");
                    # by
                    tableent("-");
                    # lead
                    tableent("-");
                    # tricks
                    tableent("-");
                }
            }
            if ($r->{special} eq "A") {
                tableent("-");
            } else {
                tableent($r->{points});
            }
        }
        {
            my($ptsout);
            $ptsout = roundif($r->{nsp});
            tableent($ptsout);
            $ptsout = roundif($r->{ewp});
            tableent($ptsout);
        }
        tablerowend();
    }
    tableend();
}

our($preamble) = <<EOF;
#Version;std1
#Title;Duplicate Pairs;
EOF



sub generatebridgewebsfile
{
    my($dir, $sp, $travs, $single, $anon, $nomp) = @_;
    my(@datestr) = splitdate($dir);
    my($fh);
    my($fname);
    my($datestr);

    $fh = IO::File->new();
    $datestr = join("", @datestr);
    $fname = "bw_$dir.csv";
    if (!$fh->open($fname, ">")) {
        die("Failed to open the output file $fname $!\n");
    }
    $fh->print($preamble);
    $fh->print("#source;Knave Bridge Scorer (Open Source). Revision:$rev\n");
    $fh->print("#Date;$datestr[2]/$datestr[1]/$datestr[0]\n");
    $fh->print("#Boards;", scalar(@$travs), "\n");
    $fh->print("#Winners;", scalar(@{$sp->{array}}), "\n");

    # Offload the dumping of the scores to another subroutine.
    doscores($fh, $sp, $single, $travs, $anon, $nomp);
    doboards($fh, $travs);
}

sub doboards
{
    my($fh, $travs) = @_;
    my($t, $bn);
    my($v);
    $fh->print("#Travellers\n");
    if ($short) {
        $fh->print("NS;EW;NSScore;EWScore;NSPts;EWPts\n");
    } else {
        $fh->print("NS;EW;NSScore;EWScore;NSPts;EWPts;Contract",
                   ";Tricks;Declarer;Lead\n");
    }
    my(@vals);
    $bn = scalar(@$travs);

    for ($t = 1; $t <= $bn; $t++) {
        @vals = sort( { $a->n() <=> $b->n() } @{$travs->[$t - 1]});
        $fh->print("#Board;$t\n");
        foreach $v (@vals) {
            my(@outa);
            push(@outa, $v->n(), $v->e());
            my($sp) = $v->special();
            # handle averages
            if ($sp && substr($sp, 0, 1) eq "A") {
                push(@outa, Result->averagestring($sp));
            } else {
                if ($v->points() < 0) {
                    push(@outa, "", $v->points() * -1);
                } else {
                    push(@outa, $v->points(), "");
                }
            }
            my($ptsout);
            $ptsout = roundif($v->nsp());
            push(@outa, $ptsout);
            $ptsout = roundif($v->ewp());
            push(@outa, $ptsout);
            if (!$short) {
                my($simplecontract);
                $simplecontract = $v->contxt();
                # If it has any decoration, remove it.
                $simplecontract =~ s/[+-]\d+//;
                push(@outa, $simplecontract, $v->tricks(), $v->by(), $v->lead());
            }
            $fh->print(join(";", @outa), "\n");
        }
    }
}


sub doscores
{
    my($fh, $sp, $single, $travs, $anon, $nomp) = @_;
    my($scores);
    my($sl);
    # Populate this array.
    my(@outa);
    my($t);
    my($bn) = scalar(@$travs);

    foreach $scores (@{$sp->{array}}) {
        $fh->print("#Scores\n");
        $fh->print("Position;Pair;Name1;Name2;Score;Tops;Percent;");
        if (!$nomp) {
            $fh->print("Mpts;");
        }
        $fh->print("Boards\n");
        foreach $sl (@$scores) {
            @outa = ();
            push(@outa,
                 $sl->{pos},
                 $sl->{matchpair});

            if (defined($sl->{pair})) {
                if ($anon) {
                    push(@outa, "Pair", $sl->{matchpair});
                } else {
                    push(@outa,
                         $single->name1($sl->{pair}),
                         $single->name2($sl->{pair}));
                }
            } else {
                push(@outa, "Unknown", "Unknown");
            }

            my($pn) = $sl->{matchpair};
            my($pair) = Pair->getpair($pn);
            my($ptsout);
            $ptsout = roundif($pair->{unmodpts});
            push(@outa, $ptsout);
            push(@outa, $pair->{unmodtpts});

            push(@outa, $sl->{percent});
            if (!$nomp) {
                push(@outa, $pair->{mp});
            }

            for ($t = 1; $t <= $bn; $t++) {
                my($e);
                my($found) = 0;
                foreach $e (@{$travs->[$t - 1]}) {
                    if ($e->{n} == $pn) {
                        $ptsout = roundif($e->{nsp});
                        push(@outa, $ptsout);
                        $found = 1;
                        last;
                    }
                    if ($e->{e} == $pn) {
                        $ptsout = roundif($e->{ewp});
                        push(@outa, $ptsout);
                        $found = 1;
                        last;
                    }
                }
                if (!$found) {
                    push(@outa, "X");
                }
            }
            $fh->print(join(";",@outa), "\n");
        }
    }
}

#
# Doesn't work yet.... wait until we need it.
#
sub concise_output
{
    my($date, $sp, $single) = @_;
    my($datestr);
    my($tfh) = IO::File->new();
    my($name);

    if (!$tfh->open("news.txt", ">")) {
        die("Failed to open news.txt $!\n");
    }
    $datestr = simpledate($date);
    $tfh->print("\n\n$Conf::Club Results\n$datestr\n\n");
    my($out, $in);
    my($pos) = 1;
    my($lastpos);
    foreach $out (@{$sp->{array}}) {
        foreach $in (@$out) {
            $name = $single->fullname($in->{pair});
            if (defined($lastpos) && ($in->{matchper} == $lastpos->{matchper})) {
                if (!exists($lastpos->{pos})) {
                    $lastpos->{pos} .= "=";
                    $lastpos->{joint} = 1;
                }
                $in->{pos} = $lastpos->{pos};
            } else {
                $in->{pos} = $pos;
                $lastpos = $in;
            }
            $pos++;
            print("$name\n");
            if ($pos > 2) {
                last;
            }
        }
    }
}
1;
