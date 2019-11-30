##############
package Magix;
##############


# Code to upload to the Magix web server club pages

use strict;
use warnings;
use Net::FTP;
use IO::File;
use Digest;
use Uploadbwclient; # for the competion filelist
use Webhtml;
use Sql;
our($host) = "ftp.magix-online.com";

sub new
{
    my($class) = shift();
    my($club_token, $user, $pw) = @_;


    # create the digest;
#    my($digest) = Digest::digest($club_token);
    my($digest) = $club_token;
    my($self) = {
                 token => $club_token,
                 user => $user,
                 pw => $pw,
                 digest => $digest
                };
    bless($self, $class);
    return ($self);
}


sub upload
{
    my($self) = shift();
    my($fl, $local) = @_;
    my($ret);

    my($ftph) = Net::FTP->new($host,
                              passive => 1,
                              debug => 1,
                              binary => 1);

    if (!defined($ftph)) {
        die("Failed to connect to the magix ftp server $!\n");
    }

    $ret = $ftph->login($self->{user}, $self->{pw});
    if (!$ret) {
        die("Failed to authenticate with Magix ftp server\n");
    }
    my($targetdir) = "clubs/" . $self->{digest} . "/main/";

    my($f);
    if (!defined($fl)) {
        $fl = $Uploadbwclient::comp_files;
    }
    if (!defined($local)) {
        $local = $Conf::compdir;
    }
    foreach $f (@$fl) {
        my($local) = "$local/$f";
        my($remote) = $targetdir . $f;
        $ret = $ftph->delete($remote);
        if (!$ret) {
            print("Failed to delete $remote\n");
        }

        $ret = $ftph->put($local, $remote);
        if (!$ret) {
            die("Failed to transfer $remote ", $ftph->code(), ":",
                $ftph->message(), "\n");
        }
        print($remote, "\n");
    }
}

# three functions to generate the magix front web pages.
our($index_sheet) =<<EOF;
<style type="text/css">
html, body {
    height: 100%;
    overflow: hidden;
    margin: 0;
}
#content {
    height: 100%;
}
#left {
    float: left;
    width: 20%;
    height: 100%;
    overflow: auto;
    box-sizing: border-box;
}
#right {
    float: left;
    width: 80%;
    background: #cccccc;
    height: 98%;
    overflow: auto;
    box-sizing: border-box;
    padding: 0.4em;
}
</style>
EOF


sub index_page
{
    my($self) = shift();
    my($web) = Webhtml->new();
    my($title) = "$Conf::Club";
    my($fh) = IO::File->new();
    if (!$fh->open("$Conf::compdir/index.htm", ">")) {
        die("Failed to open the index file $!\n");
    }
    $fh->print($web->preamble($title, "", $index_sheet, [], {}), "\n");
    my($template);
    $template =<<EOF;
<div id="content">
<iframe src="left.htm" id="left" name="left">
</iframe>
<iframe src="desc.htm" id="right" name="right">
</iframe>
</div>
EOF
    $fh->print($template);

    $fh->print($web->postamble(), "\n");
    $fh->close();
}


our($left_style) = <<EOF;
<style type="text/css">
body {
       text-align: center;
       font-family: Verdana, Geneva, sans-serif;
       background-image: url("oldpaper.jpg");
}
input {
       width: 180px;
       border-radius: 50px;
       pad: 1px;
}
</style>
EOF



sub left
{
    my($self) = shift;
    my($web) = Webhtml->new();
    my($title) = "";
    my($fh) = IO::File->new();
    if (!$fh->open("$Conf::compdir/left.htm", ">")) {
        die("Failed to open the left file $!\n");
    }
    my($ss) = "";
    $fh->print($web->preamble($title, $title, $left_style, [], {}), "\n");
    my($template);
    $template =<<EOF;
<p>
$Conf::Club
</p>
<form>
<input type="button" onClick="parent.right.location.href='desc.htm'" value="Description"></input><br>
<input type="button" onClick="parent.right.location.href='graph.htm'" value="Player Numbers"></input><br>
<input type="button" onClick="parent.right.location.href='yearcompare.htm'" value="Yearly totals"></input><br>
<input type="button" onClick="parent.right.location.href='seventy.htm'" value="70% Hall of Fame"></input><br>
<input type="button" onClick="parent.right.location.href='wilsondecay.htm'" value="Leading Player"></input><br>
<input type="button" onClick="parent.right.location.href='analysis.htm'" value="Player Analysis"></input><br>
<input type="button" onClick="parent.right.location.href='howyou.htm'" value="How you doing?"></input><br>

<input type="button" onClick="parent.right.location.href='allsessions.htm'" value="All session counts"></input><br>
<input type="button" onClick="parent.right.location.href='beamish.htm'" value="Partner Competition"></input><br>
<input type="button" onClick="parent.right.location.href='ruffdecay.htm'" value="Leading Player (Ruff)"></input><br>
<input type="button" onClick="parent.right.location.href='sitout.htm'" value="Sitouts"></input><br>

<input type="button" onClick="parent.right.location.href='wpair.htm'" value="Pair Totals"></input><br>
<input type="button" onClick="parent.right.location.href='ppair.htm'" value="Pair Percentage"></input><br>
<input type="button" onClick="parent.right.location.href='tpair.htm'" value="Pair Win/Place/Show"></input><br>
<input type="button" onClick="parent.right.location.href='spair.htm'" value="Pair Sessions"></input><br>
<input type="button" onClick="parent.right.location.href='wplay.htm'" value="Player Totals"></input><br>
<input type="button" onClick="parent.right.location.href='pplay.htm'" value="Player Percentage"></input><br>
<input type="button" onClick="parent.right.location.href='tplay.htm'" value="Player Win/Place/Show"></input><br>
<input type="button" onClick="parent.right.location.href='splay.htm'" value="Player Sessions"></input><br>
</form>
EOF

    $fh->print($template);

    $fh->print($web->postamble(), "\n");
    $fh->close();
}

our($desc_style) =<<EOF;
<style type="text/css">
body {
       font-family: Verdana, Geneva, sans-serif
}
li {
       margin: 10px 0;
}
</style>
EOF


sub desc
{
    my($self) = shift;
    my($web) = Webhtml->new();
    my($title) = "Description";
    my($fh) = IO::File->new();
    if (!$fh->open("$Conf::compdir/desc.htm", ">")) {
        die("Failed to open the desc file $!\n");
    }
    my($ss) = "";
    $fh->print($web->preamble($title, $title, $desc_style, [], {}), "\n");
    my($template);
    my($gmail) = '@gmail';
    $template =<<EOF;
<ol>
<li>
Player Numbers - this shows the number of player sessions averaged over a month as it changes over the years.
</li>
<li>
Yearly totals - this presents a graphical representation of the total number of player sessions during the year, starting from the date in the header and going back exactly 365 days. Each column is labelled by the year in which the last session was played. It gives a good indication if the club is growing or shrinking as using a whole year's numbers cancels out any seasonal fluctuations. (Numbers tend to drop during the summer holidays).
</li>
<li>
70% Hall of Fame - this lists those partnerships that have scored
over 70% in a session and the date of its achievement.
</li>
<li>
Leading Player - the ranking of the current best player based
on the number of Wilsons scored. Wilsons are awarded roughly in the
same way as the EBU's master point scheme, but they decay over time by
one point per session.
</li>
<li>
Player Analysis - allows you to see all the sessions you and your
partner(s) have played at the club. Click on the left hand box
and select your name, then click on the right hand box and
select a partner or "all". The buttons at the top of the columns
will re-sort the table by that column.
</li>
<li>
How you doing? - this allows you to select up to five active players and generate a graph of their session percentage over time. Nothing is shown until you use one of the five drop down menus and select an active player's name. To remove a player from the plot, select the first menu item of dashes.
</li>
<li>
All session count - All members' session counts over 50
</li>
<li>
Partner Competition - Lists players by their best 10 percentage results with at least 3 different partners. Named after John Beamish who devised the scoring scheme.
</li>
<li>
Leading Player (Ruff) - The current leading player as calculated using Ruff points. Ruff points decay by one per session. Ruff points are calculated by giving each pair 2 points for each pair they defeat and one point per tie. (The same way that match points are assigned on a traveller).
</li>
<li>
Sitouts - The number sitouts by direction for every year.
</li>
<li>
Pair Total - total number of Wilson's awarded to a pair during the year.
</li>
<li>
Pair Percentage - the average of the best 10 percentage scores made by a pair. Also included on the output is the percentage needed by the pair to improve. Those pairs who have player fewer that 10 sessions are marked as "Unqualified" and will always sort below any qualified pairs.
</li>
<li>
Pair Win/Place/Show - three points awarded for a win, two for second and one for third irrespective of the field size.
</li>
<li>
Pair Sessions - number of times a pair have played together so far during the year.
</li>
<li>
The next  entries are the same as the pair variants, except that they list individual players rather than pairs.
</li>
</ol>
<p>
Note that if you don't play at the club for 6 months, the software
marks you as inactive. Inactive players will only show up in the
70% Hall of Fame. If you play again after becoming inactive all
your results/session details will re-appear.
</p>
<p>
The software may also mark players as 'png'. These players have all their sessions discarded
except for the player session totals. They never appear in any of the ranking or analysis pages.
Any partner playing with a player marked as 'png' has that session discarded.
</p>
<p>
The code to generate these pages is part of the Knave Bridge Scoring
software suite, freely available to download, use and modify.
</p>
<p>
haffread$gmail.com
</p>
<p>&nbsp;
</p>
EOF

    $fh->print($template);

    $fh->print($web->postamble(), "\n");
    $fh->close();


}

sub gen_past_years
{
    my($self) = shift();
    my($ret);
    my($files);
    my($file);
    $ret = Sql->GetHandle($Conf::Dbname);
    if (!defined($ret)) {
        die("Failed to load db\n");
    }
    $files = Sql->keys(Sql::SCORE);
    # find the latest/highest by year.
    my($hby) = {};
    my($ent);
    foreach $file (@$files) {
        my($date, $year, $month) = $file =~ /((\d\d\d\d)(\d\d)\d\d)/;
        if (!defined($date)) {
            die("Failed to match ($file)\n");
        }
        $ent = 0;
        if (exists($hby->{$year})) {
            if ($date > $hby->{$year}->[0]) {
                $ent = 1;
            }
        } else {
            $ent = 1;
        }
        if ($ent) {
            $hby->{$year} = [ $date, $year, $month, $file ];
        }
    }
    my($keys) = [ sort({ $a <=> $b } keys(%$hby)) ];
    my($year);
    # skip the first entry, it is probably not a complete yesr.
    my($fl) = [];
    shift(@$keys);
    foreach $year (@$keys) {
        my($date, $month, $file);
        my(@cmds);
        $date = $hby->{$year}->[0];
        $month = $hby->{$year}->[2];
        $file = $hby->{$year}->[3];
        @cmds = qw(perl ../comp.pl -q 10 -y -x);
        push(@cmds, $year, $date);
        system(@cmds);
        if ($? != 0) {
            die("comps failed for year $year");
        }
        my($name);
        foreach $name ("wplay", "wpair", "splay", "spair", "pplay", "ppair", "tplay", "tpair") {
            push(@$fl, "$name$year.htm");
        }
    }
    return $fl;
}



1;

