# Generate all the competition result's data.
# $Id: Compclient.pm 1684 2017-01-07 13:32:18Z phaff $
# Copyright (c) 2011 Paul Haffenden. All rights reserved.
#
# These are all generated using the date parameters to
# limit the sessions used.
# We generate:
# 1) The pair with the most master points
# 2) The player with the most master points
# 3) The pair with the best 'qual' percentage results
# 4) The player with the best 'qual' percentage results
# 5) The pair with the most sessions
# 6) The player with the most sessions.
# 7) The pair with the most 3/2/1 points (Known as tto)
# 8) The player with the most 3/2/1 points
#
# These are only generated if the -g flag is specified
# and uses all the scoring sessions
#
# 9) The analysis data for the javascript page
# 10) All the players that have scored over 70%
# 11) The player with decayed master points.
# 12) The player with decayed 'Ruff' points.
# 13) The graph of half-tables by year.

###################
package Compclient;
###################
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use IO::File;
use Encode;
use Math::BigRat;
use Data::Dumper;


use Conf;
use lib "lib";
use Rscan;
use Single;
use Sdate;
use Webtool;
use Pairmap;
use JSON;
use Webhtml;

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

td, th {
        border: 2px solid;
}

table.center {
        margin-left: auto;
        margin-right: auto;
        box-shadow: 15px 15px 15px #888;
        -webkit-box-shadow: 15px 15px 15px #888;
        border-collapse: collapse;
}

.copy {
        font-size: 0.60em;
        text-align: center;
}

caption {
        margin-left: auto;
        margin-right: auto;
}

tr.high {
        background: green;
}

.sm {
        font-size: small;
}
</style>
EOF

our($nicestylesheet) = <<'EOF';
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

td, th {
        border: 2px solid;
}

td.name {
        font-family: "Forte MT";
}


td.center {
        text-align: center;
}

table.center {
        margin-left: auto;
        margin-right: auto;
        box-shadow: 15px 15px 15px #888;
        -webkit-box-shadow: 15px 15px 15px #888;
        border-collapse: collapse;
}

.copy {
        font-size: 0.60em;
        text-align: center;
}

caption {
        margin-left: auto;
        margin-right: auto;
}
</style>
EOF


our(@ranknames) = qw(
  Septi
  Octo
  Novem
  Decem
  Knave
  Queen
  Roi
  Ace
);

sub usage
{
    my($msg) = @_;
    my($us) = <<EOF;
comp.pl [--qualify|q qual] [--startofyear|y] [--startofmonth|m] [--startdate date] [--global|g] [--decayby|d days|sess ] [--startmon sm] enddate

qual - number of plays to qualify (default 10)

$msg
EOF
    die($us);
}


sub checkhead
{
    my($key, $default) = @_;
    my($ret) = $default;
    if (exists($Conf::Comprename{$key})) {
        $ret = $Conf::Comprename{$key};
    }
    return $ret;
}


# Convert any html characters in place.
sub _tohtml
{
    $_[0] =~ s/&/&amp;/g;
    $_[0] =~ s/</&lt;/g;
    $_[0] =~ s/>/&gt;/g;
}

sub main
{
    my($single);
    my($datestr);
    my($opts) = {};
    # options
    my($year) = '';
    my($month);
    my($qual) = 10;
    my($global) = 0;

    my($startdate) = '';
    my($enddate) = '';
    my($ret);
    my($scan);
    my($mobj);
    my($decayby) = "";
    my($ofh) = @_;
    my($suffix) = "";
    my($startmon) = 1;

    if (!defined($ofh)) {
        $ofh = "STDOUT";
    }

    if (scalar(@ARGV) < 2) {
        my($needdate) = 0;
        if (scalar(@ARGV) == 0) {
            $needdate = 1;
        }
        # only 1 or 0 arguments were supplied.
        # see if the arguments are present in the
        # config file.
        if (defined($Conf::compargs[0])) {
            push(@ARGV, @Conf::compargs);
        } else {
            usage("The compargs variable is not set in the configuration file and you have not supplied any arguments");
        }
        # If we didn't supply any arguments, then use the
        # date of the last entry in the 'score' table.
        if ($needdate) {
            my($k);
            my($ret);
            Sql->GetHandle($Conf::Dbname);
            $k = Sql->keys(Sql::SCORE);
            if (scalar(@$k) == 0) {
                usage("No existing score entries so can't determine last date");
            }
            $ret = [ sort({$a cmp $b} @$k) ];
            print("Date selected: $ret->[-1]\n");
            push(@ARGV, $ret->[-1]);
        }
    }

    if (!GetOptions
        (
         'qualify|q=i' => \$qual,
         'startofyear|y' => \$year,
         'startofmonth|m' => \$month,
         'startdate|s=s' => \$startdate,
         'global|g' => \$global,
         'decayby|d=s' => \$decayby,
         'suffix|x=s' => \$suffix,
         'startmon=i' => \$startmon,
        )) {
        usage("Bad option");
    }
    if (!defined($ARGV[0])) {
        usage("Must be called with an end date\n");
    }

    my($startopt) = 0;
    $startopt++ if $year;
    $startopt++ if $month;
    $startopt++ if $startdate;

    if ($startopt > 1) {
        usage("Can only specify one of --startyear, --startmonth " .
              "or --startdate");
    }

    ($enddate) = $ARGV[0] =~ m/^(\d\d\d\d\d\d\d\d)/;
    if (!defined($enddate)) {
        die("The argument is not in the right format ($ARGV[0]) YYYYMMDD\n");
    }
    $datestr = simpledate($ARGV[0]);
    if (!defined($datestr)) {
        die("Unable to parse the folder argument ($ARGV[0]) as a date\n");
    }

    my($edate) = $enddate + 0;
    my($sdate);

    if ($startdate) {
        my($check) = simpledate($startdate);
        if (!defined($check)) {
            die("I can't parse the date specified with the --startdate ",
                "option\n");
        }
        $sdate = $startdate;
    } elsif ($year) {
        $sdate = int($edate / 10000);
        $sdate = int($sdate * 10000);
    } elsif ($month) {
        $sdate = int($edate / 100);
        $sdate = int($sdate * 100);
    } else {
        $sdate = int($edate - 10000);
    }

    $single = Single->new();
    $ret = $single->load("contact.csv");
    if ($ret) {
        die("Loading the player database file contact.csv ",
            "has failed ($ret)\n");
    }

    if (!-d $Conf::compdir) {
        if (!mkdir($Conf::compdir, 0777)) {
            die("I can't create the competiton directory ($Conf::compdir) $!\n");
        }
    }
    my($decaylookup) = {};
    # list of all the 'valid' result files.
    my($allfiles) = [];
    # Do a lite scan to get all the sessions.
    my($lobj) = Litescan->new($decaylookup, $allfiles);
    $scan = Rscan->new($Conf::resdir, 2000, $edate, $lobj);
    $scan->scan();
    my($key);
    my($weight) = 0;
    foreach $key (sort { $b <=> $a } keys(%$decaylookup)) {
        $decaylookup->{$key} = $weight;
        $weight++;
    }

    $mobj = Onescan->new($sdate, $edate, $global, $single, $decayby, $decaylookup, $allfiles);
    $scan = Rscan->new($Conf::resdir, 2000, $edate, $mobj);
    # This does the actual scan of all the files.
    $scan->scan();



    my($startofyear) = substr($edate, 0, 4) . "0101";
    my($newplayers) = scalar(grep({$_ >= $startofyear} values(%{$mobj->{firstplayed}})));


    $ofh->print("Number of sessions           : $mobj->{session_count}\n",
          "Number of player sessions    : $mobj->{session_players}\n",
          "Number of unique players     : ",
          scalar(keys(%{$mobj->{player}})),
          "\n",
          "Number of certificates issued: $mobj->{certs_issued}\n",
          "New players this year        : $newplayers\n");

    # get all the accumulators.
    my($pairacc) = [ values(%{$mobj->{pairs}}) ];
    my($playacc) = [ values(%{$mobj->{player}}) ];
    my($data);
    my($head); # The header for the page.

    # Part 1. pair with most master points.
    $data = [ sort {$b->master() <=> $a->master() }
              grep {$_->master() > 0} @$pairacc ];
    $head = checkhead("wpair", "$Conf::Club Wilson Point Pair Summary");
    genhtml($head,
            "$Conf::compdir/wpair$suffix.htm",
            1,
            $mobj->{lowdate},
            $edate,
            "master",
            undef,
            $data,
            $single);

    # Part 2. player with most master points.
    $data = [ sort {$b->master() <=> $a->master() }
              grep { $_->master() > 0 } @$playacc ];
    $head = checkhead("wplay", "$Conf::Club Wilson Point Player Summary");
    genhtml($head,
            "$Conf::compdir/wplay$suffix.htm",
            0,
            $mobj->{lowdate},
            $edate,
            "master",
            undef,
            $data,
            $single);


    # Part 3. pair with best $qual percentage
    $data = [ sort( { ($b->isqual() <=> $a->isqual())
                      || ($b->get_ave_percent() <=> $a->get_ave_percent()) }
                    grep {($_->get_ave_percent($qual) > 40) && ($_->plays() > 1 )} @$pairacc) ];

    $head = checkhead("ppair", "$Conf::Club Match Percentage (Best $qual) Pair Summary");
    genhtml($head,
            "$Conf::compdir/ppair$suffix.htm",
            1,
            $mobj->{lowdate},
            $edate,
            "ave_percent",
            $qual,
            $data,
            $single);

    # Part 4. player with best $qual percentage
    $data = [ sort( { ($b->isqual() <=> $a->isqual())
                      || ($b->get_ave_percent() <=> $a->get_ave_percent()) }
                    grep {($_->get_ave_percent($qual) > 40) && ($_->plays() > 1 )} @$playacc) ];

    $head = checkhead("pplay", "$Conf::Club Match Percentage (Best $qual) Player Summary");
    genhtml($head,
            "$Conf::compdir/pplay$suffix.htm",
            0,
            $mobj->{lowdate},
            $edate,
            "ave_percent",
            $qual,
            $data,
            $single);

    # Part 5. pair with most sessions
    $data = [ sort {$b->plays() <=> $a->plays()} @$pairacc ];
    $head = checkhead("spair", "$Conf::Club Pair Sessions Summary");
    genhtml($head,
            "$Conf::compdir/spair$suffix.htm",
            1,
            $mobj->{lowdate},
            $edate,
            "plays",
            undef,
            $data,
            $single);

    # Part 6. player with most sessions
    $data = [ sort {$b->plays() <=> $a->plays()} @$playacc ];
    $head = checkhead("splay", "$Conf::Club Player Sessions Summary");
    genhtml($head,
            "$Conf::compdir/splay$suffix.htm",
            0,
            $mobj->{lowdate},
            $edate,
            "plays",
            undef,
            $data,
            $single);


    # Part 7. Three-two-one pairs.
    $data =  [ sort {$b->tto() <=> $a->tto() }  grep { $_->tto() > 0 } @$pairacc ];
    $head = checkhead("tpair", "$Conf::Club Pair Three/Two/One");
    genhtml($head,
            "$Conf::compdir/tpair$suffix.htm",
            1,
            $mobj->{lowdate},
            $edate,
            "tto",
            undef,
            $data,
            $single);

    # Part 8. Three-two-one player.
    $data = [ sort {$b->tto() <=> $a->tto() } grep { $_->tto() > 0 } @$playacc ];
    $head = checkhead("tplay", "$Conf::Club Player Three/Two/One");
    genhtml($head,
            "$Conf::compdir/tplay$suffix.htm",
            0,
            $mobj->{lowdate},
            $edate,
            "tto",
            undef,
            $data,
            $single);





    if ($global) {
        # part 9, the analysis file.
        my($web);
        $web = Webtool->new();
        $web->generate($single, "$Conf::compdir/analysis.htm", $mobj->{ysis}, $mobj->{ysispairs});

        # part 10. The seventy percenters.
        doseventy(simpledate($edate), $single, $mobj->{seventy});

        # part 11. Decay.
        # This now generates two files, one with master points and the
        # other with 'ruffs'
        decay(simpledate($edate), $single, $mobj->{decay}, $decayby);

        # part 12. graph of average sessions.
        graph(simpledate($edate), $startmon, $mobj->{ymind});

        # part 12. graph plot for players
        howyoudoing(simpledate($edate), $single, $decaylookup, $mobj->{how});

        # part 13. graph of year numbers.
        yeartots(simpledate($edate), $mobj->{yeartots});

        # Part 14. page of all sessions.
        allsessiontots(simpledate($edate), $single, $mobj->{all});

        # Part 15.
        sitouts(simpledate($edate), $mobj->{ht});

        # Part 17.
        firstplayed(simpledate($edate), $single, $mobj->{firstplayed}, $mobj->{all}->{pmap});

        # The beamish/ treasure's trophy
        beamish(simpledate($edate), $single, $mobj->{beamish}, $suffix);

        # The improver's cup
        improvers(simpledate($edate), $edate, $single, $mobj->{imp});
    }
}

# Not currently used, will need to add arguments to preamble.
sub allsessiontots
{
    my($edate, $single, $all) = @_;
    my($listall) = 0; # Changes the print to sort on name and include all players
    my($fh) = IO::File->new();
    my($wh) = Webhtml->new();
    my($defname) = "allsessions";
    my($title) = checkhead($defname, "$Conf::Club - All time session count");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                 $stylesheet,
                                 [],
                                 {});
    my($postamble) = $wh->postamble();

    if (!$fh->open("$Conf::compdir/$defname.htm", ">")) {
        die("Failed to open the $defname.htm file $!\n");
    }
    my(@res);
    my($pid, $count);
    my($ent);

    while (($pid, $count) = each(%{$all->{pmap}})) {

        $ent = $single->entry($pid);
        next if $ent->png();
        if (!defined($ent->cname()) || !defined($ent->sname())) {
            print("Warning: $pid has aname part missing!\n");
        }
        push(@res, [$ent->cname() . " " . $ent->sname(), $pid, $count, 0, 0, $ent->sname() . " " . $ent->cname(), $pid]);
    }
    if ($listall) {
        @res = sort({$a->[5] cmp $b->[5]} @res);
    } else {
        @res = sort({$b->[2] <=> $a->[2]} @res);
        @res = grep({$_->[2] > 50} @res);
    }
    my($total) = $all->{sessions};
    my($lastpos);
    my($pos) = 1;


    foreach $ent (@res) {
        if (!$listall) {
            if (defined($lastpos) && ($ent->[2] == $lastpos->[2])) {
                if (!$lastpos->[4]) {
                    $lastpos->[3] .= "=";
                    $lastpos->[4] = 1;
                }
                $ent->[3] = $lastpos->[3];
            } else {
                $ent->[3] = $pos;
                $lastpos = $ent;
            }
        } else {
            $ent->[3] = $ent->[6];
        }
        $pos++;
    }

    $fh->print($preamble);
    $fh->print('<table class="center">', "\n");
    $fh->print("<tr><th>Position</th><th>Name</th><th>Plays</th><th>Percentage</th></tr>\n");
    foreach $ent (@res) {
        my($per) = sprintf("%.2f", 100 * $ent->[2] / $total);
        $fh->print("<tr><td>$ent->[3]</td><td>$ent->[0]</td><td>$ent->[2]</td><td>$per%</td></tr>\n");
    }
    $fh->print("</table>\n");

    $fh->print($postamble);
    $fh->close();
}

sub yeartots
{
    my($edate, $ctl) = @_;
    my($wh) = Webhtml->new();
    my($defname) = "yearcompare";
    my($title) = checkhead($defname, "$Conf::Club yearly session totals");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  "",
                                  [ qw(JQUERY FLOT TOOL) ],
                                  {});
    my($webcontents) = <<'EOF';
<p>From ##date##</p>
<div id="placeholder" style="width:800px;height:400px"></div>
<script type="text/javascript">
var pjh = (function() {
   var data;
   var options;
   var tooltip;

   // The function calls start here..
   var startup = function() {
     options["tooltipOpts"]["content"] = pjh.tooltip;
     $.plot($("#placeholder"), data, options);
   };

   var set = function(indata, inoptions, intooltip) {
     data = indata;
     options = inoptions;
     tooltip = intooltip;
   };

   var dotooltip = function(label, x, y) {
       var obj = tooltip[label];
       return "Number of players: " + obj.count + "<br>" +
               "Number of sessions: " + obj.sess + "<br>" +
               "Average : " + obj.ave;
   };

   var ret = {
     "startup" : startup,
     "set" : set,
     "tooltip" : dotooltip,
   };
   return ret;
})();
EOF

    my($webpostamble) = <<'EOF';
    $(document).ready(pjh.startup);
</script>
EOF
    my($postamble) = $wh->postamble();

    my($fh) = IO::File->new();
    if (!$fh->open("$Conf::compdir/$defname.htm", ">")) {
        die("Can't create the $defname.htm file $!\n");
    }
    $webcontents =~ s/##date##/$edate/og;
    $fh->print($preamble, $webcontents);

    my($data) = [];
    my($options) = {};
    my($tooldata) = {};
    my($it);

    $options->{xaxis} = {ticks => [], tickLength => 0};
    $options->{legend} = { show => 0};
    $options->{tooltip} = 1;
    $options->{tooltipOpts} = {defaultTheme => 1};
    $options->{grid} = {hoverable => 1};
    my($ticks) = $options->{xaxis}->{ticks};
    my($ind) = 0;
    my($lowest);
    foreach $it (@$ctl) {
        push(@$data, {bars => {show => 1},
                      label => $it->{year},
                      data =>
                      [ [$it->{year}, $it->{counter}]
                      ]});

        if (!defined($lowest) || ($it->{counter} < $lowest)) {
            $lowest = $it->{counter};
        }
        push(@$ticks, [ $it->{year} + 0.5 , $it->{year}]);
        $tooldata->{$it->{year}} =
          {
           sess => $it->{sessions},
           count => $it->{counter},
           ave => sprintf("%.2f",
                          (($it->{sessions} == 0) ? Math::BigRat->new(0) :($it->{counter} / $it->{sessions}) / 4)) . " Tables",
          };
        $ind++;
    }
    $lowest = int(($lowest - 15) / 10) * 10;
    if ($lowest > 40) {
        $options->{yaxis} = {min => $lowest};
    }

    $fh->print("pjh.set(", to_json($data), ",", to_json($options), ",",
               to_json($tooldata), ")\n");
    $fh->print($webpostamble, $postamble);
    $fh->close();
}

sub genhtml
{
    my($title, $filename, $pairs, $sdate, $edate, $sortkey,
       $qual, $data, $single) = @_;
    my($fh) = IO::File->new();
    my($lowdatestr);
    my($datestr) = simpledate($edate);
    if ($sdate == 0) {
        $lowdatestr = $datestr;
    } else {
        $lowdatestr = simpledate($sdate);
    }
    if (!$fh->open($filename, ">:utf8")) {
        die("Failed to create the html output file $filename $!\n");
    }
    my($wh) = Webhtml->new();
    $fh->print($wh->preamble($title, $title, $stylesheet, [], {}));
    $fh->print(<<EOF);
<h2>
$lowdatestr to $datestr
</h2>
<table class="center">
<tr>
<th>Pos</th>
<th>Name</th>
EOF

    if ($sortkey eq "tto") {
        $fh->print(<<EOF);
<th>Win<br>Place<br>Show Points</th>
<th>Plays</th>
EOF
    } elsif (!defined($qual)) {
        $fh->print(<<EOF);
<th>Wilson<br>Points</th>
<th>Plays</th>
</tr>
EOF
    } else {
        $fh->print(<<EOF);
<th>Match<br>Percentage</th>
<th>Qualified</th>
<th>Percentage<br>to improve</th>
<th>Plays</th>
</tr>
EOF
    }

    my($lastpos);
    my($pos) = 1;

    foreach my $p (@$data) {
        if (defined($lastpos) && ($p->valbykey($sortkey) == $lastpos->valbykey($sortkey))) {
            if (!exists($lastpos->{joint})) {
                $lastpos->{pos} .= "=";
                $lastpos->{joint} = 1;
            }
            $p->{pos} = $lastpos->{pos};
        } else {
            $p->{pos} = $pos;
            $lastpos = $p;
        }
        $pos++;
    }

    foreach my $p (@$data) {
        my($name);
        if ($pairs) {
            $name = $single->fullname($p->key());
        } else {
            $name = $single->name($p->key());
        }
        _tohtml($name);
        if ($sortkey eq "tto") {
            $fh->print("<tr>\n",
                       "<td align=\"left\">", $p->{pos}, "</td>\n",
                       "<td>$name</td>\n",
                       "<td>", sprintf("%0.2f", $p->tto()), "</td>\n",
                       "<td>", $p->plays(), "</td>\n",
                       "</tr>\n");
        } elsif (!defined($qual)) {
            $fh->print("<tr>\n",
                       "<td align=\"left\">", $p->{pos}, "</td>\n",
                       "<td>$name</td>\n",
                       "<td>", $p->master(), "</td>\n",
                       "<td>", $p->plays(), "</td>\n",
                       "</tr>\n");
        } else {
            $fh->print("<tr>\n",
                       "<td align=\"left\">$p->{pos}</td>\n",
                       "<td>$name</td>\n",
                       "<td>", $p->get_ave_percent(), "</td>\n",
                       "<td>", $p->isqual() ? "Yes" : "No", "</td>\n",
                       "<td>", $p->tobeat(), "</td>\n",
                       "<td>", $p->plays(), "</td>\n",
                       "</tr>\n");
        }
    }
    $fh->print(<<EOF);
</table>
EOF
    $fh->print($wh->postamble());
    $fh->close();
    # Remove those entries we inserted
    foreach my $p (@$data) {
        delete($p->{joint});
        delete($p->{pos});
    }
}

sub doseventy
{
    my($datestr, $single, $list) = @_;
    my($ents);
    my($defname) = "seventy";
    $ents = [ sort({$b->[2] <=> $a->[2]} @$list) ];

    my($pos) = 1;
    my($p);
    my($lastpos);

    my($highdate) = 0;

    foreach $p (@$ents) {
        if ($p->[1] > $highdate) {
            $highdate = $p->[1];
        }
        if (defined($lastpos) && ($p->[2] == $lastpos->[2])) {
            if (!defined($lastpos->[4])) {
                $lastpos->[3] .= "=";
                $lastpos->[4] = 1;
            }
            $p->[3] = $lastpos->[3];
        } else {
            $p->[3] = $pos;
            $lastpos = $p;
        }
        $pos++;
    }
    my($fh, $fname);
    $fh = IO::File->new();
    $fname = "$Conf::compdir/$defname.htm";
    if (!$fh->open($fname, ">:utf8")) {
        die("Failed to open $fname $!\n");
    }
    my($title) = checkhead($defname, "$Conf::Club Over 70% Club");
    my($wh) = Webhtml->new();
    $fh->print($wh->preamble($title, $title, $stylesheet, [], {}));
    $fh->print(<<EOF);
<h2>
$datestr
</h2>
<table class="center">
<tr>
<th>Pos</th>
<th>Name</th>
<th>Percentage</th>
<th>Date</th>
EOF

    foreach $p (@$ents) {
        my($name) = $single->fullname($p->[0]);
        _tohtml($name);
        my($per) = sprintf("%.2f", $p->[2]);
        my($style);
        if ($p->[1] == $highdate) {
            $style = qq/ class="high"/;
        } else {
            $style = "";
        }
        $fh->print("<tr$style>\n",
                   "<td align=\"left\">$p->[3]</td>\n",
                   "<td>$name</td>\n",
                   "<td>$per</td>\n",
                   "<td>",
                   fixeddate($p->[1]),
                   "</td>\n",
                   "</tr>\n");
    }
    $fh->print("</table>\n");
    $fh->print($wh->postamble());

    $fh->close();
}


our(@cols) = (
     "#ffffff",
     "#ffccff",
     "#ffff00",
);

our($colind);

sub getcolour
{
    my($rank, $lastrank) = @_;

    if ($lastrank == -1) {
        $colind = 0;
    } elsif ($rank != $lastrank) {
        $colind++;
        if ($colind >= scalar(@cols)) {
            $colind = 0;
        }
    }
    return ($cols[$colind]);
}

sub decay
{
    my($datestr, $single, $decay, $decayby) = @_;

    # decay is indexed by the playernumber.
    # Each entry is an array ref of three items
    # The first is the total number of points
    # The second the number of scoring entries.
    # The third is a hash, indexed by the date that the points
    # were awarded, each entry is an array ref, te first entry
    # is the number of points awarded on this date, and the second
    # the undecayed masterpoints, the third the number of ruffs awarded
    # on this date, and the fourth the number of undecayed ruffs.
    # $decay->{16}->[2]->{20111102}->[1]
    # The fourth is the number of total ruff points.
    # The fifth is the number of ruff scoring entries.

    my($fd) = IO::File->new();
    my($defname) = "wilsondecay";
    my($fname) = "$Conf::compdir/$defname.htm";
    if (!$fd->open($fname, ">")) {
        die("Failed to open $fname $!\n");
    }

    my($rate) = " per week";
    if ($decayby) {
        if ($decay =~ m/\D/) {
            $rate = " per session";
        } else {
            $rate = " per $decayby dats";
        }
    }
    my($title) = checkhead($defname, "Wilson Points - decay rate of one point $rate");

    # Find all the date keys used by all the scoring players.
    my($datekey) = {};
    foreach my $val (values(%$decay)) {
        foreach my $key (keys(%{$val->[&Onescan::DATEHASH]})) {
            if ($val->[&Onescan::DATEHASH]->{$key}->[&Onescan::WILPOINTS] > 0) {
                $datekey->{$key} = 1;
            }
        }
    }
    my($wh) = Webhtml->new();
    $fd->print($wh->preamble($title, $title, $nicestylesheet, [], {}));
    $fd->print(<<EOF);
<h2>
From $datestr
</h2>
<table class="center">
<tr>
<th>Name</th>
<th>Wilsons</th>
<th>Scoring sessions</th>
<th>Rank</th>
EOF

    # Now add the columns for the date entries
    # The datehead gives up the key as we run aong the date entries.
    my($datehead) = [ sort( {$b <=> $a }keys(%$datekey)) ];
    foreach my $ent (@$datehead) {
        $fd->print("<th>$ent</th>\n");
    }

    # And add the trailing tr
    $fd->print("</tr>\n");

    # Lets do the players...
    my($pkeys);
    my($rankdiv);


    $pkeys = [ sort( { $decay->{$b}->[&Onescan::WILTOT] <=> $decay->{$a}->[&Onescan::WILTOT]} keys(%$decay)) ];

    if (scalar(@$pkeys)) {
        # Look at the top points scored
        $rankdiv = $decay->{$pkeys->[0]}->[&Onescan::WILTOT] / scalar(@ranknames);
    }

    my($lastrank) = -1;

    foreach my $i (@$pkeys) {
        my($ent);
        my($rankind);
        my($colour);

        next if $decay->{$i}->[&Onescan::WILTOT] < 1;
        $rankind = int(($decay->{$i}->[&Onescan::WILTOT] - 1 ) / $rankdiv);
        $colour = getcolour($rankind, $lastrank);
        $lastrank = $rankind;

        $ent = $ranknames[ $rankind ];
        my($playername) = $single->name($i);
        _tohtml($playername);
        $fd->print(qq/<tr bgcolor="$colour">/);
        $fd->print("<td>",
                   $playername,
                   "</td><td>",
                   $decay->{$i}->[&Onescan::WILTOT],
                   "</td><td class=\"center\">",
                   $decay->{$i}->[&Onescan::WILENTRIES],
                   "</td><td class=\"name\">",
                  $ent,
                  "</td>");
        # Loop through all the datekeys.
        foreach my $dent (@$datehead) {
            if (exists($decay->{$i}->[&Onescan::DATEHASH]->{$dent}) && ($decay->{$i}->[&Onescan::DATEHASH]->{$dent}->[&Onescan::WILPOINTS] > 0)) {
                my($e) = $decay->{$i}->[&Onescan::DATEHASH]->{$dent};
                $fd->print(qq!<td title="$playername $dent">$e->[&Onescan::WILPOINTS]/$e->[&Onescan::WILUNDECAY]</td>\n!);
            } else {
                $fd->print("<td>&nbsp;</td>\n");
            }
        }
        $fd->print("</tr>\n");
    }
    $fd->print(<<EOF);
</table>
EOF
    $fd->print($wh->postamble());
    $fd->close();


    # The ruff decay bit

    $datekey = {};
    foreach my $val (values(%$decay)) {
        foreach my $key (keys(%{$val->[&Onescan::DATEHASH]})) {
            if ($val->[&Onescan::DATEHASH]->{$key}->[&Onescan::RUFFPOINTS] > 0) {
                $datekey->{$key} = 1;
            }
        }
    }
    $datehead = [ sort( {$b <=> $a }keys(%$datekey)) ];

    $fd = IO::File->new();
    $defname = "ruffdecay";
    $fname = "$Conf::compdir/$defname.htm";
    if (!$fd->open($fname, ">")) {
        die("Failed to open $fname $!\n");
    }

    $title = checkhead($defname, "Ruff Points - decay rate of one point $rate");
    $fd->print($wh->preamble($title, $title, $nicestylesheet, [], {}));
    $fd->print(<<EOF);
<h2>
From $datestr
</h2>
<table class="center">
<tr>
<th>Name</th>
<th>Ruff<br>Points</th>
<th>Scoring sessions</th>
<th>Rank</th>
EOF

    # Now add the columns for the date entries
    # The datehead gives up the key as we run aong the date entries.
    foreach my $ent (@$datehead) {
        $fd->print("<th>$ent</th>\n");
    }

    # And add the trailing tr
    $fd->print("</tr>\n");

    # Lets do the players...
    $pkeys = [ sort( { $decay->{$b}->[&Onescan::RUFFTOT] <=> $decay->{$a}->[&Onescan::RUFFTOT]} keys(%$decay)) ];

    if (scalar(@$pkeys)) {
        # Look at the top points scored
        $rankdiv = $decay->{$pkeys->[0]}->[&Onescan::RUFFTOT] / scalar(@ranknames);
    }

    $lastrank = -1;

    foreach my $i (@$pkeys) {
        my($ent);
        my($rankind);
        my($colour);

        next if $decay->{$i}->[&Onescan::RUFFTOT] < 1;
        $rankind = int(($decay->{$i}->[&Onescan::RUFFTOT] - 1 ) / $rankdiv);
        $colour = getcolour($rankind, $lastrank);
        $lastrank = $rankind;

        $ent = $ranknames[ $rankind ];
        my($playername) = $single->name($i);
        _tohtml($playername);
        $fd->print(qq/<tr bgcolor="$colour">/);
        $fd->print("<td>",
                   $playername,
                   "</td><td>",
                   $decay->{$i}->[&Onescan::RUFFTOT],
                   "</td><td class=\"center\">",
                   $decay->{$i}->[&Onescan::RUFFENTRIES],
                   "</td><td class=\"name\">",
                  $ent,
                  "</td>");
        # Loop through all the datekeys.
        foreach my $dent (@$datehead) {
            if (exists($decay->{$i}->[&Onescan::DATEHASH]->{$dent}) && ($decay->{$i}->[&Onescan::DATEHASH]->{$dent}->[&Onescan::RUFFPOINTS] > 0)) {
                my($e) = $decay->{$i}->[&Onescan::DATEHASH]->{$dent};
                $fd->print(qq!<td title="$playername $dent">$e->[&Onescan::RUFFPOINTS]/$e->[&Onescan::RUFFUNDECAY]</td>\n!);
            } else {
                $fd->print("<td>&nbsp;</td>\n");
            }
        }
        $fd->print("</tr>\n");
    }
    $fd->print(<<EOF);
</table>
EOF
    $fd->print($wh->postamble());
    $fd->close();
}


sub getkeyyear
{
    my($year, $mon, $startmon) = @_;
    if (!defined($startmon)) {
        $startmon = 1;
    }
    if ($mon < $startmon) {
        $year--;
    }
    $mon = $mon - $startmon + 1;
    if ($mon <= 0) {
        $mon += 12;
    }
    return ($year, $mon);
}

# Use the jQuery flot package to plot a nice graph of the average
# number of players per month
sub graph
{
    my($date, $startmon, $data) = @_;
    my($low, $high);
    my($ind_by_year) = {};
    my($key, $val);
    my($keyyear);
    my($keymon);
    my($wh) = Webhtml->new();
    my($defname) = "graph";
    my($title) = checkhead($defname, "$Conf::Club players per session averaged by month");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  "",
                                  [ qw(JQUERY FLOT MONGRAPH) ],
                                  {});
    my($webpreamble) = <<EOF;
<p>From ##date##</p>
<div id="placeholder" style="width:800px;height:400px"></div>
<div id="choices"></div>
<script type="text/javascript">
EOF
    my($webpostamble) = <<'EOF';
    pjh.startup();
</script>
EOF

    my($fh) = IO::File->new();
    if (!$fh->open("$Conf::compdir/$defname.htm", ">")) {
        die("Can't create the $defname.htm file $!\n");
    }
    $webpreamble =~ s/##date##/$date/og;
    $fh->print($preamble, $webpreamble);

    $low = 300000;
    $high = 0;

    while (($key, $val) = each(%$data)) {
        my($year, $mon) = $key =~ m/(\d\d\d\d)(\d\d)/;
        ($keyyear, $keymon) = getkeyyear($year, $mon, $startmon);
        if ($keyyear < $low) {
            $low = $keyyear;
        }
        if ($keyyear > $high) {
            $high = $keyyear;
        }
        my($sum) = 0;
        foreach my $x (@$val) {
            $sum += $x;
        }
        $val = sprintf("%.2f", $sum / scalar(@$val));
        $ind_by_year->{$keyyear}->[$keymon - 1] = $val;
    }
    my($year);
    my($varnum) = 1;
    my($allvar) = [];
    my($options) = {
          xaxis => {
            show => 1,
            ticks =>  [ [1, "Jan"], [2, "Feb"], [3, "Mar"], [4,"Apr"], [5,"May"], [6,"Jun"], [7,"Jul"], [8,"Aug"], [9,"Sep"], [10,"Oct"], [11, "Nov"], [12,"Dec"] ]
          },
          legend => {
            show => 1,
            container => "#legendtable",
            noColumns => 10,
          }
    };
    #
    # Rotate the mon ticks.
    {
        my($rot) = $startmon - 1;
        my($arr) = $options->{xaxis}->{ticks};
        while ($rot > 0) {
            my($front) = shift(@$arr);
            push(@$arr, $front);
            $rot--;
        }
        # number the indexes.
        for ($rot = 1; $rot <= 12; $rot++) {
            $arr->[$rot - 1]->[0] = $rot;
        }
    }

    for ($year = $low; $year <= $high; $year++) {
        if (!exists($ind_by_year->{$year})) {
            next;
        }
        my($mon);
        my($it) = $ind_by_year->{$year};
        my($hash) = {};
        if ($startmon > 1) {
            $hash->{label} = "$year/" . ($year + 1);
        } else {
            $hash->{label} = $year;
        }
        $hash->{points} = { show => 1 };
        $hash->{lines} = { show => 1 };
        my($hashdata) = [];
        $hash->{data} = $hashdata;
        for ($mon = 1; $mon <= 12; $mon++) {
            if (exists($it->[$mon - 1])) {
                push(@$hashdata, [ $mon, $it->[$mon -1 ] + 0 ]);
            } else {
                push(@$hashdata, [ $mon, undef ]);
            }
        }
#        $fh->print("pjh.d$varnum = ", to_json($hash), ";\n");
        push(@$allvar, $hash);
        $varnum++;
    }
    $fh->print("pjh.setdata(", to_json($allvar), ");\n");
    $fh->print("pjh.setoptions(", to_json($options), ");\n");
    $fh->print($webpostamble, $wh->postamble());
    $fh->close();
}

sub howyoudoing
{
    my($date, $single, $lookup, $how) = @_;
    my($wh) = Webhtml->new();
    my($defname) = "howyou";
    my($title) = checkhead($defname, "$Conf::Club - plot of player session percentage against time");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  "",
                                  [ qw(JQUERY FLOT)],
                                  {});
    my($webpreamble) = <<'EOF';
<div id="placeholder" style="width:800px;height:400px"></div>
<div id="legendtable"></div>
<div id="selectbox">
<select id="s0">
<option>none</option>
</select>
<select id="s1">
<option>none</option>
</select>
<select id="s2">
<option>none</option>
</select>
<select id="s3">
<option>none</option>
</select>
<select id="s4">
<option>none</option>
</select>
</div>
<script type="text/javascript">
$(function () {
  var data = {};
  var flot = [];

  tickfunc = function(args) {
    var ticktable = ##TICKDATA## ;
    var min = args["min"];
    var max = args["max"];
    var reta = [];
    var diff = max - min;
    var ind;
    var incr;
    if (diff < 1) {
      var ind = Math.floor(max);
      reta.push(ticktable[ind]);
    } else {
      if (diff <= 8) {
        incr = 1;
      } else {
        incr = Math.floor(diff / 8);
      }
      ind = min;
      while (ind <= max) {
        reta.push(ticktable[ind]);
        ind += incr;
      }
    }
    return reta;
  };
EOF

  my($code) = <<'EOF';
    var changefunc = function() {
      var pind = this.value;  // the player index from the selector
      if (pind == -1) {
        flot[this.my] = null;
      } else {
        var dind = playermap[pind].gid; // The index into the data array
        flot[this.my] = data[dind];
      }
      var toplot = [];
      for (var ind in flot) {
          if (flot[ind] != null) {
             toplot.push(flot[ind]);
           }
      }
      $.plot($("#placeholder"), toplot, options);
    };
    var selectfunc = function(index, sel) {
      var ind = 0;
      var dash = "----------------------------------";
      sel.options.length = 0;
      sel.options[ind] = new Option(dash, -1, false, false);
      ind++;
      sel.my = index;

      options["xaxis"]["ticks"] = tickfunc;

      for (var pind in playermap) {
        sel.options[ind] = new Option(playermap[pind].name, pind, false, false);
        ind++;
      }
      $(this).change(changefunc);
    };
    $("#selectbox").find('select').each(selectfunc);
EOF


    my($webpostamble) = <<'EOF';
});
</script>
EOF

    # We have to reverse the order of the lookup.
    # Find the highest.
    my($high) = 0;
    my($mylookup);
    my($pn, $data, $key, $val);

    while ((undef, $val) = each(%$lookup)) {
        if ($val > $high) {
            $high = $val;
        }
    }
    while (($key, $val) = each(%$lookup)) {
        $mylookup->{$key} = $high - $val;
    }


    my($xaxis) = [];
    while (($key, $val) = each(%$mylookup)) {
            push(@$xaxis, [ $val, $key ]);
    }
    $xaxis = [ sort({$a->[0] <=> $b->[0]} @$xaxis) ];
    $xaxis = to_json($xaxis);

    $webpreamble =~ s/##TICKDATA##/$xaxis/o;


    my($fh) = IO::File->new();


    if (!$fh->open("$Conf::compdir/$defname.htm", ">")) {
        die("Failed to open $defname.htm $!\n");
    }
    $fh->print($preamble, $webpreamble);
    my($peoplemap) = {};
    while (($pn, $data) = each(%$how)) {
        my($newa) = [];
        my($date, $per);
        while (($date, $per) = each(%$data)) {

            my($ind) = $mylookup->{$date};
            push(@$newa, [ $ind+0, $per+0 ]);
        }
        # Sort the entries by index.
        $newa = [ sort({$a->[0] <=> $b->[0]} @$newa) ];

        smooth($newa);

        my($dataa) = {};
        my($name) = $single->name($pn);
        $dataa->{label} = $name;
        $dataa->{data} = $newa;
        $dataa->{points} = {show => 1};
        $dataa->{lines} = {show => 1};
        $peoplemap->{$pn} = $name;
        $fh->print("data[$pn] = ", to_json($dataa), ";\n");
    }
    my(@plist) = $single->sorted();
    my($plist);
    my($ind) = 0;
    foreach my $pl (@plist) {
        next if $pl->png();
        push(@$plist,
             { name => $pl->sname() . " " . $pl->cname(),
               gid => $pl->id() + 0
             });
    }
    my($options) = {};
    $options->{xaxis} = {
                         show => 1
                        };
    $options->{legend} = {
                          show => 1,
                          container => "#legendtable"
                         };
    # Dump a number to people mapping structure.
    $fh->print("var playermap = ", to_json($plist), ";\n");
    $fh->print("var options = ", to_json($options), ";\n");

    $fh->print($code);
    $fh->print($webpostamble, $wh->postamble());
}


sub smooth
{
    my($in) = @_;
    my($i);

    for ($i = 0; $i < scalar(@$in); $i++) {
        my($low) = $i - 10;
        my($high) = $i + 10;
        my($ii);
        my($tot) = 0;
        my($count) = 0;
        for ($ii = $low; $ii <= $high; $ii++) {
            if (!(($ii < 0) || $ii >= scalar(@$in))) {
                $tot += $in->[$ii]->[1];
                $count++;
            }
        }
        $tot = $tot / $count;
        $in->[$i]->[2] = $tot;
    }
    foreach my $i (@$in) {
        $i->[1] = sprintf("%.2f", $i->[2]) + 0.0;
        delete($i->[2]);
    }
}

sub sitouts
{
    my($date, $ht) = @_;
    my($wh) = Webhtml->new();
    my($defname) = "sitout";
    my($title) = checkhead($defname, "$Conf::Club - Sitout count by year");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  "",
                                  [ qw(JQUERY FLOT TOOL STACK)],
                                  {});
    my($webpreamble) = <<'EOF';
<p>From ##date##</p>
<div id="placeholder" style="width:800px;height:400px"></div>
<script type="text/javascript">
var pjh = (function() {

   var g_data = null;
   var g_options = null;
   var tooltipdata = {};

   var startup = function() {
      var i;
      var j;
      var key;
      var val;
      var index = 0; 
      for (i in g_data) {
        for (j in g_data[i]) {
           key = g_data[i][j][0];
           val = g_data[i][j][1];
           if (index == 0) {
             tooltipdata[key] = [];
           }
           tooltipdata[key][index] = val;
        }
        index += 1;
       }
       plot();
   };

   var dotooltip = function(label, x, y) {
       var mybit = tooltipdata[x];
       var tot = mybit[0] + mybit[1] + mybit[2];
       return "Total Sessions: " + tot + "</br>" +
              "East/West sitouts " + mybit[1] +
              " (" + (mybit[1] / tot * 100).toFixed(0) + "%)" +
                "</br>" +
              "North/South sitouts " + mybit[0] +
              " (" + (mybit[0] / tot * 100).toFixed(0) + "%)";

   };

   var plot = function() {
       $.plot("#placeholder", g_data, g_options);
   };


   var setdata = function(d) {
       g_data = d;
   };
   var setoptions = function(o) {
       g_options = o;
   };

   return {
       "startup" : startup,
         "setdata" : setdata,
         "setoptions" : setoptions,
         "tooltip" : dotooltip
         };
  })();
pjh.setoptions(
    {
    series: {
        stack: true,
              bars: {
                  show: true,
                  barWidth: 0.6,
                  align: "center"
                  }
        },
    xaxis: {
        tickDecimals: 0
    },
    grid: {
         hoverable: true
    },
    tooltipOpts: {
         content: pjh.tooltip,
         defaultTheme: 1
    },
    tooltip: 1
    });
EOF

    $webpreamble =~ s/##date##/$date/o;
    my($json) = JSON->new();
    my($x);
    my($reta) = [];
    my($fname) = "$Conf::compdir/$defname.htm";
    my(@keys) = sort( {$a <=> $b} keys(%$ht));
    my($i);

    for ($i = 0; $i < 3; $i++) {
        my($treta) = [];
        push(@$reta, $treta);
        foreach $x (@keys) {
            push(@$treta, [ $x, $ht->{$x}->[$i]]);
        }
    }
    $json->pretty(1);

    my($fh) = IO::File->new();
    if (!$fh->open($fname, ">")) {
        die("Failed to open $fname from writing $!\n");
    }
    $fh->print($preamble, $webpreamble);
    $fh->print("pjh.setdata(", $json->encode($reta), ")\n",
               '$(document).ready(pjh.startup);', "\n");
    $fh->print("</script>");

    $fh->print("<table border=\"1\">\n",
               "<tr><th>Value</th><th>Colour</th></tr>\n",
               "<tr><td>No sitouts</td><td>Red</td></tr>\n",
               "<tr><td>E/W sitouts</td><td>Blue</td></tr>\n",
               "<tr><td>N/S sitouts</td><td>Yellow</td></tr>\n",
               "</table>\n");
    $fh->print($wh->postamble());
}


use constant QUALIFIED => 0;
use constant FEWQUALIFIED => 1;
use constant FEWSESSIONS => 2;

our($qual_reasons) = {
                      QUALIFIED, "Qualified",
                      FEWQUALIFIED, "Not enough partners",
                      FEWSESSIONS, "Not enough sessions"
};

sub beamish
{
    my($date, $single, $beamish, $suffix) = @_;
    my($wh) = Webhtml->new();
    my($fh) = IO::File->new();
    my($defname) = "beamish";
    my($title) = checkhead($defname, "$Conf::Club - Beamish Competition");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  $stylesheet,
                                  [],
                                  {});

    my($postamble) = $wh->postamble();

    if (!$fh->open("$Conf::compdir/$defname$suffix.htm", ">")) {
        die("Failed to open $Conf::compdir/$defname.htm $!\n");
    }


    # Do the result pre-processing.
    # Iterate over each player, which is the key in the beamish hash
    my($main, $others);

    my($qualsessions) = 10; # number of qualifing sessions.
    my($max)          = 6;  # Maximum sessions available from one partner
    my($minpart)      = 3;  # the minimum number of partners.

    my(@prunes);

    while (($main, $others) = each(%$beamish)) {
        # We need to go though all the other entries turning the percentage field into a rational
        my($oth, $list);
        my($winners) = [];

        # Don't print players with only one regular partner.
        next if scalar(keys(%$others)) < 2;

        # Now make a winners list containing all the results from all partners.
        while (($oth, $list) = each(%$others)) {
            my($l);
            foreach $l (@$list) {
                $l->{per} = Math::BigRat->new($l->{per});
            }
            push(@$winners, @$list);
        }


        my($part) = {}; # hash of partners used
        my($prune) = [];
        # sort the winners list in descending order
        $winners = [ sort({$b->{per} <=> $a->{per}} @$winners) ];
        my($l);
        # We have to look at each in turn...
        # used to have a shortcut here, don't bother anymore.
        foreach $l (@$winners) {
            next if exists($part->{$l->{pair}}) && $part->{$l->{pair}} >= $max;
            # How many entries do I have spare to fill with new partners?
            my($slotsfree) = $qualsessions - scalar(@$prune);
            my($parts) = scalar(keys(%$part));
            my($partfree) = $minpart - $parts;
            if ($slotsfree > $partfree) {
                # Just bung this one in.
                push(@$prune, $l);
                $part->{$l->{pair}}++;
            } else {
                # We can't push an entry that already exists
                next if exists($part->{$l->{pair}});
                push(@$prune, $l);
                $part->{$l->{pair}}++;
            }
            last if scalar(@$prune) >= $qualsessions;
        }
        my($qual, $qualreason, $score) = beamscore($qualsessions, $part, $minpart, $prune);
        # pair, number of partners in qualify, total number of partners, results, qualified, qual reason, percentage
        push(@prunes, {
                       player => $main,
                       qpart => scalar(keys(%$part)),
                       apart => scalar(keys(%$others)),
                       results => $prune,
                       qual => $qual,
                       qual_reason => $qualreason,
                       score => $score
                      });
    }

    # Now sort the prune list....
    @prunes = sort({$b->{qual} <=> $a->{qual} || $b->{score} <=> $a->{score}} @prunes);
    my($lastpos);
    my($pos) = 1;
    my($l);
    foreach $l (@prunes) {
        if (defined($lastpos) && ($l->{score} == $lastpos->{score})) {
            if (!($lastpos->{pos} =~ "=")) {
                $lastpos->{pos} .= "=";
            }
            $l->{pos} = $lastpos->{pos};
        } else {
            $l->{pos} = $pos;
            $lastpos = $l;
        }
        $pos++;
    }

    $fh->print($preamble,
               "<h2>$date</h2>",
               '<table class="center">',
               "<tr><td>Sessions required</td><td>$qualsessions</td></tr>\n",
               "<tr><td>Minimum partners</td><td>$minpart</td></tr>\n",
               "<tr><td>Maximum sessions with one partner</td><td>$max</td></tr></table>\n",
               '<table class="center">',
               "\n",
               "<tr>",
               "<th>Pos</th>",
               "<th>Name</th>",
               "<th>Score</th>",
               "<th>Qualified</th>",
               "<th>Qualifying<br>Partners</th>",
               "<th>Total<br>Partners</th>",
               "<th>1</th>",
               "<th>2</th>",
               "<th>3</th>",
               "<th>4</th>",
               "<th>5</th>",
               "<th>6</th>",
               "<th>7</th>",
               "<th>8</th>",
               "<th>9</th>",
               "<th>10</th>",
               "</tr>\n");


    foreach $l (@prunes) {
        my($titlestr) = "";
        my($qualstr) = "";
        if ($l->{qual}) {
            $qualstr = "Yes";
        } else {
            $qualstr = "No";
            $titlestr = qq: title="$qual_reasons->{$l->{qual_reason}}":;
        }
        $fh->print(
                   "<tr>",
                   "<td>", $l->{pos}, "</td>",
                   "<td>", $single->name($l->{player}), "</td>",
                   "<td>", sprintf("%.02f", $l->{score}->as_float()), "</td>",
                   "<td$titlestr>$qualstr</td>",
                   "<td>", $l->{qpart}, "</td>",
                   "<td>", $l->{apart}, "</td>");
        my($i);
        my($r) = $l->{results};
        for ($i = 0; $i < $qualsessions; $i++) {
            if (defined($r->[$i])) {
                $fh->print('<td class="sm">', sprintf("%.02f", $r->[$i]->{per}->as_float()), "<br>", $single->name($r->[$i]->{pair}), "</td>");
            } else {
                $fh->print("&nbsp;");
            }
        }
        $fh->print("</tr>\n");
    }
    $fh->print("</table>\n", $postamble);
    $fh->close();
}


sub beamscore
{
    my($sessions, $part, $minpart, $prune) = @_;
    my($qual, $qualreason, $score);

    if (scalar(@$prune) < $sessions) {
        $qual = 0;
        $qualreason = FEWSESSIONS;
    } elsif (scalar(keys(%$part)) < $minpart) {
        $qual = 0;
        $qualreason = FEWQUALIFIED;
    } else {
        $qual = 1;
        $qualreason = QUALIFIED;
    }

    $score = Math::BigRat->new(0);
    my($l);
    foreach $l (@$prune) {
        $score += $l->{per};
    }
    my($missing) = $sessions - scalar(@$prune);
    $score += Math::BigRat->new(50) * $missing;
    $score = $score / scalar($sessions);
    return ($qual, $qualreason, $score);
}


sub firstplayed
{
    my($date, $single, $fphash, $all) = @_;
    my($wh) = Webhtml->new();
    my($fh) = IO::File->new();
    my($defname) = "firstplayed";
    my($title) = checkhead($defname, "$Conf::Club - First Played");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  $stylesheet,
                                  [],
                                  {});

    my($postamble) = $wh->postamble();

    if (!$fh->open("$Conf::compdir/$defname.htm", ">")) {
        die("Failed to open $Conf::compdir/$defname.htm $!\n");
    }
    # Sort the players by the first played date.
    my($key);
    my($keys) = [];
    foreach $key (keys(%$fphash)) {
        my($ent) = $single->entry($key);
        next if $ent->png();
        push(@$keys, $key);
    }

    $keys = [ sort({$fphash->{$a} <=> $fphash->{$b}} @$keys) ];

    $fh->print($preamble,
               "<h2>$date</h2>",
               '<table class="center">',
               "\n",
               "<tr>",
               "<th>Date</th>",
               "<th>Name</th>",
               "<th>Sessions</th>",
               "</tr>\n");


    foreach $key (@$keys) {
        $fh->print(
                   "<tr>",
                   "<td>", $fphash->{$key}, "</td>",
                   "<td>", $single->name($key), "</td>",
                   "<td>", $all->{$key}, "</td>",
                   "</tr>\n");
    }
    $fh->print("</table>\n", $postamble);
    $fh->close();
}



sub improvers
{
    my($date, $edate, $single, $imp) = @_;
    my($wh) = Webhtml->new();
    my($fh) = IO::File->new();
    my($defname) = "improvers";
    my($title) = checkhead($defname, "$Conf::Club - Improvers");
    my($preamble) = $wh->preamble($title,
                                  $title,
                                  $stylesheet,
                                  [],
                                  {});

    my($postamble) = $wh->postamble();

    if (!$fh->open("$Conf::compdir/$defname.htm", ">")) {
        die("Failed to open $Conf::compdir/$defname.htm $!\n");
    }

    my($year) = int($edate / 10000);

    # Lets construct a 'thisyear' and a 'lastyear' hash by player id.
    # We start with this year. Only consider those players with at least 12 sessions
    # in the year.
    my($ty) = {};
    my($ly) = {};
    my($qual) = 12;
    getimpyear($imp, $ty, $year, $qual);
    # Now get last year.
    getimpyear($imp, $ly, $year - 1, $qual);

    # Build up a list. Only include players with both hash. And the 'last year' percentage
    # must be < 50%. If this contition matches, the push an array of id, percent diff, lastyear this year
    my(@imps);
    my($id, $per);

    while (($id, $per) = each(%$ly)) {
        next if $per >= 50;
        next if !exists($ty->{$id});
        push(@imps, [ $id, $ty->{$id} - $ly->{$id}, $ly->{$id}, $ty->{$id} ]);
    }
    @imps = sort({ $b->[1] <=> $a->[1] } @imps);
    $fh->print($preamble);
    my($lyear) = $year - 1;
    $fh->print('<table class="center">', "\n");
    $fh->print("<tr><th>Name</th><th>Change</th><th>$lyear</th><th>$year</th></tr>\n");

    foreach $id (@imps) {
        $fh->printf("<tr><td>%s</td><td>%.02f</td><td>%.02f</td><td>%.02f</td></tr>\n",
                    $single->name($id->[0]), $id->[1], $id->[2], $id->[3]);
    }

    
    $fh->print("</table>\n", $postamble);
    $fh->close();
}


sub getimpyear
{
    my($master, $out, $myear, $qual) = @_;
    my($id, $v);

    while (($id, $v) = each(%$master)) {
        my($year, $ar);
        while (($year, $ar) = each %$v) {
            if (($year == $myear) && ($ar->[1] >= $qual)) {
                $out->{$id} = $ar->[0] / $ar->[1];
            }
        }
    }
}


############
package Acc;
############
# the accumulator class

sub new
{
    my($class) = shift();
    my($key) = @_;
    my($self) = {};
    bless($self, $class);
    $self->{plays} = 0;
    $self->{maxmp} = 0;
    $self->{master} = 0;
    $self->{tto} = 0;
    $self->{percents} = [];
    $self->{key} = $key;
    return $self;
}

sub plays
{
    my($self) = shift();
    my($inc) = @_;
    if (defined($inc)) {
        $self->{plays} += $inc;
    }
    return $self->{plays};
}

sub maxmp
{
    my($self) = shift();
    my($inc) = @_;
    if (defined($inc)) {
        $self->{maxmp} += $inc;
    }
    return $self->{maxmp};
}
sub master
{
    my($self) = shift();
    my($inc) = @_;
    if (defined($inc)) {
        $self->{master} += $inc;
    }
    return $self->{master};
}

sub percents
{
    my($self) = shift();
    my($inc) = @_;
    if (defined($inc)) {
        push(@{$self->{percents}}, $inc);
    }
    return $self->{percents};
}

sub tto
{
    my($self) = shift();
    my($inc) = @_;
    if (defined($inc)) {
        $self->{tto} += $inc;
    }
    return $self->{tto};
}


sub get_ave_percent
{
    my($self) = shift();
    my($qual) = @_;

    if (!exists($self->{ave})) {
        if (!defined($qual)) {
            $qual = 10;
        }

        # We have 3 cases:
        # 1. fewer than qual - no need to sort return unqualified average
        # 2. Exactly qual - no need to sort, return qualified average
        # 3. More than qual - sort, truncate, return qualified average

        my($num) = scalar(@{$self->{percents}});
        my($d);
        if ($num <= $qual) {
            $d = $self->{percents};
            if ($num == $qual) {
                $self->{isqual} = 1;
            } else {
                $self->{isqual} = 0;
            }
        } else {
            $d = [ sort({$b <=> $a} @{$self->{percents}}) ];
            splice(@$d, $qual);
            $self->{tobeat} = $d->[$qual - 1];
            $num = $qual;
            $self->{isqual} = 1;
        }
        my($sum) = 0;
        my($it);
        foreach $it (@$d) {
            $sum += $it;
        }
        $self->{ave} = sprintf("%.2f", $sum / $num);
        if (!exists($self->{tobeat})) {
            $self->{tobeat} = $self->{ave};
        }
    }
    return $self->{ave};
}

sub isqual
{
    my($self) = shift();
    return $self->{isqual};
}

sub tobeat
{
    my($self) = shift();
    return $self->{tobeat};
}

sub key
{
    my($self) = shift();
    return $self->{key};
}

sub valbykey
{
    my($self) = shift();
    my($key) = @_;
    if ($key eq "master") {
        return $self->{master};
    } elsif ($key eq "plays") {
        return $self->{plays};
    } elsif ($key eq "ave_percent") {
        return $self->get_ave_percent() + ($self->isqual() ? 100 : 0);
    } elsif ($key eq "tto") {
        return $self->{tto};
    } else {
        die("Unknown key in valbykey ($key)\n");
    }
}

#################
package Litescan;
#################

# we are called to do a pre-scan of just the
# selected result directory names, so that
# we can construct a look up table to match
# session to decay points.
use Scanbase;
our(@ISA);
@ISA = qw(Scanbase);


sub new
{
    my($class) = shift();
    # we get passed the lookup table.
    my($lookup, $allfiles) = @_;
    my($self) = {};

    $self->{lookup} = $lookup;
    $self->{allfiles} = $allfiles;
    bless($self, $class);
    return $self;
}

sub filename
{
    my($self) = shift();
    my($fname) = @_;
    my($lookup) = $self->{lookup};
    my($allfiles) = $self->{allfiles};
    if ($fname !~ m/_/) {
        # Just create the entry for this filename
        # in the lookup table.
        $lookup->{$fname} = 0;
        push(@$allfiles, $fname);
    }
    # By always returning 0 we won't load the result file,
    # hence the Lite description.
    return 0;
}


# combine all the scans into one.
################
package Onescan;
################
use Scanbase;
use Time::Local;
use Data::Dumper;

# These are the indexes in use with the 'decay' structure
use constant WILTOT => 0;
use constant WILENTRIES => 1;
use constant DATEHASH => 2;
use constant RUFFTOT => 3;
use constant RUFFENTRIES => 4;

# Then the datehash entries indexes.

use constant WILPOINTS => 0;
use constant WILUNDECAY => 1;
use constant RUFFPOINTS => 2;
use constant RUFFUNDECAY => 3;


our(@ISA);
@ISA = qw(Scanbase);

sub new
{
    my($class) = shift();
    my($sdate, $edate, $global, $single, $decayby, $decaylookup, $allfiles) = @_;
    my($self) = {};
    bless($self, $class);
    $self->{sdate} = $sdate;
    $self->{global} = $global;
    $self->{edate} = $edate;
    $self->{single} = $single;
    $self->{decayby} = $decayby;
    $self->{decaylookup} = $decaylookup;
    $self->{session_count} = 0;
    $self->{session_players} = 0;
    $self->{certs_issued} = 0;
    $self->{lowdate} = 0;
    # The analysis data for part 7.
    $self->{ysis} = [];
    $self->{ysispairs} = {}; # pairs that have an analysis entry
    $self->{seventy} = [];
    $self->{firstdata} = undef;
    # Use for average monthly numbers graph.
    $self->{ymind} = {};
    $self->{how} = {}; # how are you doing global

    # total of all the sessions and players.
    $self->{all} = {};
    $self->{all}->{pmap} = {}; # The player map
    $self->{all}->{psessions} = 0;
    $self->{all}->{sessions} = 0;
    $self->{all}->{maxtbls} = [0, ""]; # number of pairs, date it happend

    # Create all the yeartot buckets, using the allfiles array.
    # Start from the 'end' date. and always include the current
    # year
    $self->{yeartots} =
      [
       {
        bot => $edate - 10000,
        top => $edate,
        year => int($edate / 10000),
        counter => 0,
        sessions => 0
       }
      ];


    $self->{ht} = {};  # half tables, index by year, e.g. "2014". Each value
                       # in an array ref, 0 => NS sitout, 1 => EW sitous,
                       # 2 => no sitouts. (These are all counts)

    $self->{beamish} = {};
    $self->{firstplayed} = {};  # indexed by player id.

    $self->{imp} = {}; # The improver's - index by player id, then year. It points to an
                       # array of two values, count percentage and number of entries.

    my($top, $bot);
    $top = $edate - 10000;
    for(;;) {
        $bot = $top - 10000;
        if (scalar(@$allfiles) == 0) {
            die("No files to process!\n");
        }
        # search the $allfiles, if we find one that is less than
        # the $bot date, then we are in.
        if ($allfiles->[0] < $bot) {
            push(@{$self->{yeartots}},
                 {
                  bot => $bot,
                  top => $top,
                  year => int($top / 10000),
                  counter => 0,
                  sessions => 0
                 });
        } else {
            last;
        }
        $top = $top - 10000;
    }

    my($y, $m, $d) = $edate =~ m/^(\d\d\d\d)(\d\d)(\d\d)/;
    $self->{edatesecs} = timegm(0, 0, 0, $d, $m - 1, $y - 1900);

    if (!$decayby) {
        $self->{decayinsecs} = 60 * 60 * 24 * 7;
    } else {
        if ($decayby =~ m/\D/) {
            $self->{decayinsecs} = 0; # means use sessions, not time.
        } else {
            # $decayby is expressed in days, convert to seconds.
            $self->{decayinsecs} = 60 * 60 * 24 * $decayby;
        }
    }
    $self->{decay} = {};

    # These are all the masterpoint based 'within' the
    # selected time period accumulators.
    # The players.
    $self->{player} = {};
    # The pairs
    $self->{pairs} = {};
    return $self;
}

# called when an entry in the result table is found.
sub entry
{
    my($self) = shift();
    my($ent) = @_;
    my($single) = $self->{single};
    my($key) = $ent->{pair};
    my(@pkeys) = $single->break($key);
    my($pkey);
    my($ok) = 1;
    my($beamish) = $self->{beamish};
    # If you are a personae non gratae, your entries are completly
    # ignored.
    {
        foreach $pkey (@pkeys) {
            my($it) = $single->entry($pkey);
            if ($it->png()) {
                $ok = 0;
                last;
            }
        }
    }
    # $ok is now set to 0 if we don't like this player.


    # Do the inclusive entries
    if ($self->{active}) {
        $self->{session_players} += 2;
        if ($ent->{master}) {
            $self->{certs_issued} += 2;
        }

        # Count them, but do no more
        return if !$ok;

        my($pairmap) = $self->{pairs};
        my($playermap) = $self->{player};
        my($acc);


        if (!exists($pairmap->{$key})) {
            $acc = Acc->new($key);
            $pairmap->{$key} = $acc;
        } else {
            $acc = $pairmap->{$key};
        }
        $acc->plays(1);
        $acc->maxmp($self->{maxmp});
        $acc->master($ent->{master});
        $acc->percents($ent->{percent});
        $acc->tto($ent->{tto});

        my($ind) = 0;
        foreach $pkey (@pkeys) {
            if (!exists($playermap->{$pkey})) {
                $acc = Acc->new($pkey);
                $playermap->{$pkey} = $acc;
            } else {
                $acc = $playermap->{$pkey};
            }
            $acc->plays(1);
            $acc->maxmp($self->{maxmp});
            $acc->master($ent->{master});
            $acc->percents($ent->{percent});
            $acc->tto($ent->{tto});

            my($oth);
            if ($ind == 0) {
                $oth = $pkeys[1];
            } else {
                $oth = $pkeys[0];
            }
            push(@{$beamish->{$pkey}->{$oth}},
                 {
                  date => $self->{filedate},
                  per  => $ent->{percent},
                  pair => $oth
                 });
            $ind++;
        }
    }
    # Do the 'all' section
    foreach $pkey (@pkeys) {
        $self->{all}->{pmap}->{$pkey}++;
    }

    # a disliked player.
    return if !$ok;

    # We are generating the global data
    if ($self->{global}) {
        my($canpush) = 2;
        foreach my $p (@pkeys) {
            my($e) = $single->entry($p);
            if (!defined($e)) {
                $canpush--;
                next;
            }
            if ($e->{notactive}) {
                $canpush--;
                next;
            }
        }
        if ($canpush > 0) {
            foreach my $p (@pkeys) {
                $self->{ysispairs}->{$p} = 1;
            }
            my($pushee) =  {
                            pair => $ent->{pair},
                            date => $self->{filedate},
                            percent => $ent->{percent},
                            pos => $ent->{pos},
                            outof => $self->{outof},
                           };
            if ($ent->{master} > 0) {
                $pushee->{mp} = $ent->{master} + 0;
            }
            if (exists($ent->{tto})) {
                $pushee->{tto} = sprintf("%.2f", $ent->{tto}) + 0;
            }
            push(@{$self->{ysis}}, $pushee);
        }
        # Part 8, the pairs with >= 70% score.
        if ($ent->{percent} >= 70) {
            push(@{$self->{seventy}}, [ $ent->{pair}, $self->{filedate},
                                        $ent->{percent} ] );
        }

        # Part 9, the decay points.
        if (($ent->{master} > 0) || ($ent->{ruff} > 0)) {
            my($psf) = $ent->{master} - $self->{unit};
            my($hsf) = $ent->{ruff} - $self->{unit};
            my($psfcount, $hsfcount);
            if ($psf <= 0) {
                $psf = 0;
                $psfcount = 0;
            } else {
                $psfcount = 1;
            }
            if ($hsf <= 0) {
                $hsf = 0;
                $hsfcount = 0;
            } else {
                $hsfcount = 1;
            }
            my($date) = $self->{filedate};
            if (($psf > 0) || ($hsf > 0)) {
                my($playkey);
                my($val) = [$psf, $ent->{master}, $hsf, $ent->{ruff}];
                foreach $playkey (@pkeys) {
                    # Ignore inactive players.
                    my($e) = $single->entry($playkey);
                    next if $e->{notactive};
                    if (!exists($self->{decay}->{$playkey})) {
                        $self->{decay}->{$playkey} =
                          [ $psf, $psfcount, {$date => $val}, $hsf, $hsfcount ];
                    } else {
                        $self->{decay}->{$playkey}->[WILTOT] += $psf;
                        $self->{decay}->{$playkey}->[WILENTRIES] += $psfcount;
                        $self->{decay}->{$playkey}->[RUFFTOT] += $hsf;
                        $self->{decay}->{$playkey}->[RUFFENTRIES] += $hsfcount;
                        $self->{decay}->{$playkey}->[DATEHASH]->{$date} = $val;
                    }
                }
            }
        }
        # Part 10, How you doing section...
        my($how) = $self->{how};
        foreach my $playkey (@pkeys) {
            my($e) = $single->entry($playkey);
            next if $e->{notactive};
            $how->{$playkey}->{$self->{filedate}} = $ent->{percent};
        }

        # the first played date.
        my($hash) = $self->{firstplayed};
        foreach my $p (@pkeys) {
            if (!exists($hash->{$p}) || ($self->{filedate} < $hash->{$p})) {
                $hash->{$p} = $self->{filedate};
            }
        }

        # The improver stats
        my($imp) = $self->{imp};
        my($year) = int($self->{filedate} / 10000);
        foreach my $id (@pkeys) {
            if (!exists($imp->{$id}->{$year})) {
                $imp->{$id}->{$year} = [ Math::BigRat->new(0), 0 ];
            }
            $imp->{$id}->{$year}->[0] += $ent->{percent};
            $imp->{$id}->{$year}->[1] += 1;
        }
    }
}

# called when we start on a new result file
sub filename
{
    my($self) = shift();
    # The name of the result file.
    my($fname) = @_;

    if ($fname =~ m/_/) {
        return 0;
    }
    $self->{activefile} = $fname;
    # See if we are in the selected period.
    my($filedate) = $fname =~ m/(\d\d\d\d\d\d\d\d)/;
    $self->{filedate} = $filedate;
    if (($filedate >= $self->{sdate}) && ($filedate <= $self->{edate})) {
        $self->{active} = 1;
        $self->{activedate} = $filedate;
        $self->{session_count}++;
        if (!$self->{lowdate}) {
            $self->{lowdate} = $filedate;
        } elsif ($filedate < $self->{lowdate}) {
            $self->{lowdate} = $filedate;
        }
    } else {
        $self->{active} = 0;
    }

    if ((!defined($self->{firstdata})) || ($filedate < $self->{firstdate})) {
        $self->{firstdate} = $filedate;
    }

    # We need to do some extra work for the decayed masterpoints
    my($year, $mon, $day) = $filedate =~ m/^(\d\d\d\d)(\d\d)(\d\d)/;
    if (!defined($day)) {
        die("Bad format of filename $filedate\n");
    }
    $self->{htyear} = $year;
    if ($self->{global}) {
        my($sec) = timegm(0, 0, 0, $day, $mon - 1, $year - 1900);
        my($unit);
        if ($self->{decayinsecs} == 0) {
            if (!exists($self->{decaylookup}->{$filedate})) {
                die("Can't find the decay lookup key $filedate!\n");
            }
            $self->{unit} = $self->{decaylookup}->{$filedate};
        } else {
            $unit = int(($self->{edatesecs} - $sec) / $self->{decayinsecs});
            $self->{unit} = $unit;
        }
    }
    return 1;
}

#called when the top level data items are read from file
sub load
{
    my($self) = shift();
    my($sp) = @_;

    if ($self->{active}) {
        $self->{maxmp} = $sp->{maxmp};
    } else {
        $self->{maxmp} = undef;
    }

    my($outer);
    my($pcount) = 0;

    foreach $outer (@{$sp->{array}}) {
        $pcount += scalar(@$outer);
    }
    $pcount *= 2;
    my($ymind) = $self->{ymind};
    my($ind) = $self->{activefile};
    $ind = substr($ind, 0, -2); # lose the last two digits.
    push(@{$ymind->{$ind}}, $pcount);

    # Do the year totals.
    my($yt);
    $ind = $self->{filedate};
    foreach $yt (@{$self->{yeartots}}) {
        if (($ind > $yt->{bot}) &&  ($ind <= $yt->{top})) {

            $yt->{counter} += $pcount;
            $yt->{sessions}++;
        }
    }
    # Do the all section.
    if ($pcount >= $self->{all}->{maxtbls}->[0]) {
        $self->{all}->{maxtbls}->[0] = $pcount;
        $self->{all}->{maxtbls}->[1] = $ind;
    }
    $self->{all}->{sessions}++;

    # The sitouts.
    $outer = $sp->{array};
    if (scalar(@$outer) > 1) {
        # we have two winners.
        my($hr);
        if (exists($self->{ht}->{$self->{htyear}})) {
            $hr = $self->{ht}->{$self->{htyear}};
        } else {
            $hr = [0, 0, 0];
            $self->{ht}->{$self->{htyear}} = $hr;
        }
        my($nscount) = scalar(@{$outer->[0]});
        my($ewcount) = scalar(@{$outer->[1]});
        if ($nscount > $ewcount) {
            $hr->[0]++; # We have a NS sitout
        } elsif ( $ewcount > $nscount) {
            $hr->[1]++;
        } else {
            $hr->[2]++;
        }
    }
}

# Called when we process a table of the results.
sub startinner
{
    my($self) = shift();
    my($inner) = @_;
    $self->{outof} = scalar(@$inner);


    my(@points) = (3, 2, 1);
    my($pot) = 0;
    my($winnerids) = [];
    my($last) = "";
    my($each);

    my($id) = -1;
    foreach my $ent (@$inner) {
        $id++;
        if ($last && ($last ne $ent->{pos})) {
            $each = $pot / (scalar(@$winnerids));

            foreach my $index (@$winnerids) {
                $inner->[$index]->{tto} = $each;
            }
            $pot = 0;
            $winnerids = [];
            last if @points == 0;
        }
        if (@points > 0) {
            $pot += shift(@points);
        }
        push(@$winnerids, $id);
        $last = $ent->{pos};
    }

    # ruffs has a different termination criteria, so rescan...
    $id = -1;
    $last = "";
    my($topid) = 0;
    foreach my $ent (@$inner) {
        $id++;
        if ($last && ($last ne $ent->{pos})) {
            $each = ((scalar(@$inner) - $topid - 1) * 2) - ((scalar(@$winnerids)) - 1);
            foreach my $index (@$winnerids) {
                $inner->[$index]->{ruff} = $each;
            }
            $winnerids = [];
            $topid = $id;
        }

        push(@$winnerids, $id);
        $last = $ent->{pos};
    }
    # Finish off the trailing entry.
    $each = ((scalar(@$inner) - $topid - 1) * 2) - ((scalar(@$winnerids)) - 1);
    foreach my $index (@$winnerids) {
        $inner->[$index]->{ruff} = $each;
    }

    # Do the 'all' section
    $self->{all}->{psessions} += $self->{outof} * 2;
}
1;
