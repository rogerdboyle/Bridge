
# Movement generator. Uses input data files to create
# a table and traveller details.
# $Id: Movegenclient.pm 1305 2014-06-17 11:33:15Z Root $

######################
package Movegenclient;
######################

use strict;
use warnings;

use Getopt::Std;
use File::Spec;

use lib "lib";
use Move::Moveconfig;
use constant L => '"left"';
use constant R => '"right"';
use constant C => '"center"';

our($preamble) =<<EOF;
<html>
<!--
(C) 2014 Paul Haffenden. All Rights Reserved.
You are free to use this file if you are a non profit organisation.
Otherwise you must request explict written permission from:
Paul Haffenden
paul\@haffenden.org.uk
-->
<head>
<title>
###
</title>
<style type="text/css">

h1 {
        color: blue;
        text-align: center;
}

table {
    border-collapse : collapse;
}

td {
    border : 3px double black;
    border-collapse : collapse;
}

th {
    text-align : center;
}

table.outer {
    border-collapse : collapse;
}

table.inner {
        min-width : 100%;
        border-style : none;
        border-collapse : collapse;
}

td.plain {
       text-align : center;
       border-style : none;
}

td.center {
        text-align : center;
        border-style : none;
        width : 33%

}

td.left {
        text-align : left;
        border-style : none;
        width : 33%
}

td.right {
        text-align : right;
        border-style : none;
        width : 33%
}

</style>

</head>
<body>
<h1>
###
</h1>
EOF

our($end) = <<EOF;
</body>
</html>
EOF

sub main
{
    my($opts) = {};
    my($fh);
    my($mc);
    my($outfh) = "STDOUT";
    my($bpr);
    my($mpair) = 0;
    my($ofh) = @_;
    my($ann) = 0;

    if (!defined($ofh)) {
        $ofh = "STDOUT";
    }

    binmode($outfh, ":crlf");
    $fh = IO::File->new();
    if (!getopts("f:hb:ct:r:e:a", $opts)) {
        usage("Parsing failed\n");
    }

    if (!exists($opts->{f})) {
        usage("Must specify an input file\n");
    }

    if (exists($opts->{b})) {
        $bpr = $opts->{b};
    }
    if (exists($opts->{e})) {
        $mpair = $opts->{e};
    }

    if (!$fh->open($opts->{f}, "<")) {
        die("Failed to open $opts->{f} ($!)\n");
    }
    $mc = Move::Moveconfig->new();
    $mc->load($fh);
    if (!exists($opts->{h})) {
        $mc->setoutput($outfh);
    }
    if ($bpr) {
        $mc->set_bpr($bpr);
    }
    if ($mpair) {
        $mc->set_excludepair($mpair);
    }
    $ofh->print("Filename: $opts->{f}\n",
          "Id: $mc->{id}\n",
          "Description: ", $mc->get_desc(), "\n");
    my(@args);
    if ($opts->{r}) {
        push(@args, $opts->{r});
    }
    $mc->generate(@args);
    if (exists($opts->{h})) {
        if (!$opts->{t}) {
            makehtml($opts->{f}, $bpr, $mc, $opts->{c});
        } else {
            maketablehtml($opts->{f}, $bpr, $mc, $opts->{t});
        }
    }
    if ($opts->{a}) {
        make_scorebridge_annex($opts->{f}, $mc);
    }
}

sub make_scorebridge_annex
{
    my($fname, $mc) = @_;
    my($r);
    my($nor);
    my($not);
    $nor = $mc->get_rounds();
    $not = $mc->get_not();

    for ($r = 1; $r <= $nor; $r++) {
        my($ctl) = $mc->get_ctltbl($r);
    }



}

sub maketablehtml
{
    my($infile, $bpr, $mc, $tbl) = @_;
    my($not) = $mc->get_not();
    my($rndctl) = $mc->{rndctl};

    if (!defined($bpr)) {
        $bpr = $mc->get_bpr();
    }
    if (!defined($bpr)) {
        die("bpr has not been defined on the command line (-b) or in the ",
            "movement file\n");
    }
    my($fh) = IO::File->new();
    my($fname);
    (undef, undef, $fname) = File::Spec->splitpath($infile);

    my($tblno);
    my($tabs_on_page) = 0;

    for ($tblno = 1; $tblno <= $not; $tblno++) {

        if ($tabs_on_page == 0) {
            my($outfname) = "${fname}_$tblno.html";


            $fh->open($outfname, ">");
            my($out) = $preamble;
            $out =~ s/^###/$fname/mg;

            $fh->print($out);

            # The outer table
            $fh->print("<table>\n");
            $fh->print("<tr>\n");
        }

        $fh->print("<td>\n");

        $fh->print(qq:<table class="outer">\n:);
        $fh->print(qq:<tr><th>Round</th><th>Table $tblno</th></tr>\n:);
        my($rndno) = 1;
        my($rnd);
        foreach $rnd (@$rndctl) {
            $fh->print("<tr>\n");
            $fh->print(qq:<td class="plain">$rndno</td>\n:);
            my($ct) = $rnd->{tables}->[$tblno - 1];
            $fh->print("<td>\n");
            printtableitem($fh, $bpr, $ct);
            $fh->print("</td>\n");
            $fh->print("</tr>\n");
            $rndno++;
        }
        $fh->print("</table>\n");

        $fh->print("</td>\n");

        if ($tabs_on_page == ($tbl - 1)) {
            # End of outer table
            $fh->print("</tr>\n");
            $fh->print("</table>\n");
            $fh->print($end);
            $tabs_on_page = 0;
        } else {
            $tabs_on_page++;
        }
    }
    if ($tabs_on_page) {
        # Finish off partial table
        $fh->print("</tr>\n");
        $fh->print("</table>\n");
        $fh->print($end);
        $tabs_on_page = 0;
    }
}


sub makehtml
{
    my($infile, $bpr, $mc, $commentary) = @_;
    my($not, $nor);
    my($rndctl);
    my($ctlt);
    my($ctlr);
    my($rnd);
    my($fh);
    my($i);

    if (!defined($bpr)) {
        $bpr = $mc->{bpr};
    }
    if (!defined($bpr)) {
        die("bpr has not been defined on the command line (-b) or in the ",
            "movement file\n");
    }

    my($keyrnd, $txt);
    if (exists($mc->{rnddesc})) {
        ($keyrnd, $txt) = $mc->{rnddesc} =~ m/(\d+)\s+(.*)/;
        if (!defined($keyrnd)) {
            die("I can't parse the rnddesc entry ($mc->{rnddesc})\n");
        }
    } else {
        $keyrnd = 0;
    }

    $fh = IO::File->new();
    my($fname);
    (undef, undef, $fname) = File::Spec->splitpath($infile);
    $fh->open("$fname.html", ">");

    $not = $mc->get_not();
    $nor = $mc->get_nor();
    $rndctl = $mc->{rndctl};

    my($out) = $preamble;
    $out =~ s/^###/$fname/mg;

    $fh->print($out);

    $fh->print(qq:<table class="outer">\n:);

    $fh->print("<tr>\n");
    # Blank
    $fh->print("<td class=\"plain\"></td>\n");
    $fh->print(qq'<td colspan="$not" class="plain">Tables</td>\n');
    $fh->print("</tr>\n");


    $fh->print("<tr>\n");
    $fh->print("<th>Round</th>\n");
    for ($i = 1; $i <= $not; $i++) {
        $fh->print("<th>$i</th>\n");
    }
    $fh->print("</tr>\n");
    my($rndno) = 1;
    foreach $rnd (@$rndctl) {
        my($ct);

        $ctlt = $rnd->{tables};
        $fh->print("<tr>\n");
        $fh->print(qq'<td class="plain">$rndno</td>\n');
        foreach $ct (@$ctlt) {
            $fh->print("<td>\n");
            printtableitem($fh, $bpr, $ct);
            $fh->print("</td>\n");
        }
        $fh->print("</tr>\n");

        if ($rndno == $keyrnd) {
            $fh->print(qq'<tr><td class="plain" colspan="', $not + $nor + 1,
                       qq'">$txt</td></tr>\n');
        }
        $rndno++;
    }
    $fh->print("</table>");
    # Add the movedescription to the output.
    if ($commentary) {
        my($desc) = $mc->get_desc();
        $desc =~ s/\n/<br>/gm;
        $fh->print($desc);
    }
    $fh->print($end);
}

sub printtableitem
{
    my($fh, $bpr, $ct) = @_;
    my($low, $high);
    # Start a new table
    $fh->print("<table class=\"inner\">\n");
    $fh->print("<tr>\n");

    $low = $ct->{ns};
    if (!$low) {
        $low = "&nbsp;";
    }
    $high = $ct->{ew};
    if (!$high) {
        $high = "&nbsp;";
    }
    $fh->print(printtab($low, L), printtab("&nbsp;", C),
               printtab($high, R));
    $fh->print("</tr>\n");

    $fh->print("<tr>\n");
    if ($ct->{set}) {
        $low = (($ct->{set} - 1) * $bpr) + 1;
        $high = $low + $bpr - 1;
        $low = $low . "-" . $high;
    } else {
        $low = "&nbsp;";
    }

    $fh->print(printtab("&nbsp;", L), printtab($low, C),
               printtab("&nbsp;", R));
    $fh->print("</tr>\n");
    $fh->print("</table>\n");
}


sub printtab
{
    my($data, $al) = @_;
    my($ret) = "<td class=$al>";
    return($ret . $data . "</td>\n");
}

sub usage
{
    my($msg) = @_;
    my($u) = <<'EOF';
movegen.pl [-h] [-c] [-b bpr] [-e mpair] [-r rounds] -f inputfile

    -h generate an html file of the movement
    -c add the commentary to the html output
    -b override the boards per round value
    -e specify the missing pair for half tables
    -r specify the number of rounds played, different from that in the movement file
EOF

    die($msg, $u);
}

1;
