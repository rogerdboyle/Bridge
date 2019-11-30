#!/usr/bin/perl

#
# The main front end.
# $Id: kbs.pl 1695 2017-01-07 15:49:58Z phaff $
#

use strict;
use warnings;
use Config;
use File::Glob ':glob';
use File::Basename;
use IO::File;
use Tk;
use Tk::ROText;
use Tk::DateEntry;
use Tk::NumEntry;
use Tk::ProgressBar;

use Conf;

use Bsetupclient;
use Confobj;
use Ecatsclient;
use Inactiveclient;
use Listclient;
use Travclient;
use Movegenclient;
use Pairmapclient;
use Playereditclient;
use Scoreclient;
use Scorepositions;
use Compclient;
use Configclient;
use Uploadbwclient;
use Uploadresultclient;
use Sdate;
use Move::Moveconfig;
use Sql;


our($cmdlookup) = {
                  inactive => \&Inactiveclient::main,
                  movegen => \&Movegenclient::main,
                  bsetup => \&Bsetupclient::main,
                  score => \&Scoreclient::main,
                  comp  => \&Compclient::main,
                  uploadbw => \&Uploadbwclient::main,
                  uploadresult => \&Uploadresultclient::main,
                  sb2kbs => \&Sb2kbsclient::main,
                  pairmap => \&Pairmapclient::main,
                  playeredit => \&Playereditclient::main,
                  trav => \&Travclient::main,
                  perl => \&runperl,
};

sub runperl
{
    system("$^X " . join(" ", @ARGV));
    if ($? == 0) {
      exit(0);
    } else {
      exit(1);
  }
}

sub main
{
    # Before we get started proper, see if we want to run a command
    # line program, at the moment that is movegen.pl.
    if (defined($ARGV[0])) {
        my($cmd) = shift(@ARGV);
        if (exists($cmdlookup->{$cmd})) {
            &{$cmdlookup->{$cmd}}();
            exit(0);
        }
        die("Unknown command $cmd. I only know about ",
            join(" ", keys(%$cmdlookup)), "\n");
    }
    Sql->GetHandle($Conf::Dbname);
    my($mw);
    # This list the supported items passed via the Confobj
    my($confconfig) =
      {
       datestr => undef,
       suffix => undef,
       tf => undef,
       mf => undef,
       rf => undef,
       rrf => undef,
       rrrf => undef,
       rrrrf => undef,
       mw => undef,
       tablerb => undef,
       moverb => undef,
       lrb => undef,
       lab => undef,
       mcpath => undef,
       missing_but => undef,
       mpair => 0,
       buttcol => undef,
       font => undef,
       tl => undef,
       textframe => undef,
       ctlbuttons => undef,
       perlpath => undef,
       set => undef,
       round_var => 0,
       bpr_var => 0,
       ecats_session => "",
       ecats_session_orig => "",
       bm => undef,
       resultpb => 0,
       playerpb => 0,
       bmframes => undef,
       sfr => 0,
      };
    my($confobj) = Confobj->new($confconfig);
    my($perlpath);

    $perlpath = $^X;
    if ($^O ne "VMS") {
        $perlpath  .= $Config{_exe} unless $perlpath =~ m/$Config{_exe}/i;
    }

    $mw = MainWindow->new();
    mainwindowtitle($mw);


    # Make the window large....
    my($h, $w);
    $h = $mw->screenheight();
    $w = $mw->screenwidth();
    $h -= 70;
    $mw->MoveToplevelWindow(0, 0);
    $mw->geometry(join("x", $w, $h));
    # and green looks nice.
    $mw->configure(-background => "green");

    my($tm);
    $tm = [ localtime() ];
    my($datestr) = sprintf("%04d%02d%02d", $tm->[5] + 1900, $tm->[4] + 1,
                           $tm->[3]);

    $confobj->set("perlpath", $perlpath);
    $confobj->set("datestr", $datestr);
    $confobj->set("suffix", "");
    $confobj->set("mw", $mw);

    my($font) = $mw->fontCreate(-family => "courier new", -size => 10);
    $confobj->set("font", $font);

    # Get the date and the suffix of the event
    setup_date_suffix($mw, $confobj);

    MainLoop();
}


main();
exit(0);

sub mainwindowtitle
{
    my($mw) = @_;
    $mw->title("$Conf::Club - session setup");
}

sub parsedate
{
    my($tstr) = @_;
    my($year, $mon, $day) = $tstr =~ m/(\d\d\d\d)(\d\d)(\d\d)/;
    return ($year, $mon, $day);
}

sub formatdate
{
    my($year, $mon, $day) = @_;
    return sprintf("%04d%02d%02d", $year, $mon, $day);
}

sub setup_date_suffix
{
    my($mw, $conf) = @_;
    my($tf);

    $tf = $mw->Frame(
                     -relief => "ridge",
                     -borderwidth => 5,
                    );
    $tf->pack();

    $conf->set("tf", $tf);

    my($config_but);

    $config_but = $tf->Button(
                              -text => "Configurator",
                              -command => [ \&runconfigurator, $conf ],
                             );
    $config_but->pack(-side => "left");


    my($played_but);

    $played_but = $tf->Button(
                              -text => "Player Editor",
                              -command => [ \&topplayeredit, $conf ],
                             );
    $played_but->pack(-side => "left");


    # Pre-set todays date in the DateEntry widget.
    my($de) = $tf->DateEntry(
                             -parsecmd => \&parsedate,
                             -formatcmd => \&formatdate,
                             -textvariable => $conf->getref("datestr"),
                            );
    $de->pack(-side => "left");


    # Now allow a suffix to be entered.
    my($suffix) = $tf->Entry(
                             -relief => "groove",
                             -textvariable => $conf->getref("suffix"),
                             # only three chars.
                             -width => 3,
                            );

    $suffix->pack(-side => "left");

    my($list_but);
    $list_but = $tf->Button(-text => "List sessions",
                           -command => [ \&list_sessions, $conf ],
                          );
    $list_but->pack(-side => "left");


    # And we need a "Go" button to indicate completion.
    my($ok_but);
    $ok_but = $tf->Button(
                          -text => "Ok",
                          -command => [ \&dook, $conf ],
                         );
    $ok_but->pack(-side => "left");

}

sub list_sessions
{
    my($conf) = @_;

    my($mw) = $conf->get("mw");
    my($tf) = $conf->get("tf");
    $conf->set("tf", undef);

    # remove the top frame.
    $tf->destroy();
    Listclient::main($conf);
}

sub dook
{
    my($conf) = @_;
    my($datestr) = $conf->get("datestr");
    my($suffix) = $conf->getref("suffix");

    my($resname);

    $resname = $datestr;
    if ($$suffix ne "") {
        $resname .= "_$$suffix";
    }
    my($tf) = $conf->get("tf");
    $tf->destroy();

    # If the setup file already exists.
    if (Sql->keypresent(Sql::SETUP, $resname)) {
        runsetup($conf);
    } else {
        setup_movementchoice($conf);
    }
}

sub topplayeredit
{
    my($conf) = @_;
    my($tf) = $conf->get("tf");
    $tf->destroy();
    my($mw) = $conf->get("mw");
    my($tl) = $mw->Toplevel();
    $tl->geometry("+0+5");
    $tl->focus();
    $conf->set("tl", $tl);
    $tl->OnDestroy([ \&destroy_topplayeredit, $conf ]);
    Playereditclient::main($tl, [ \&quit_config, $conf]);
}

sub quit_config
{
    my($conf) = @_;
    my($tl) = $conf->get("tl");
    $tl->destroy();
}

sub destroy_config
{
    my($conf) = @_;
    my($mw) = $conf->get("mw");
    if (!Tk::Exists($mw)) {
        return;
    }
    # reread the configuration data.
    Confload::load();
    mainwindowtitle($mw);
    setup_date_suffix($mw, $conf);
}

sub destroy_topplayeredit
{
    my($conf) = @_;
    my($mw) = $conf->get("mw");
    setup_date_suffix($mw, $conf);
}


# Run the config editor.
sub runconfigurator
{
    my($conf) = @_;
    my($tf) = $conf->get("tf");
    $tf->destroy();
    my($mw) = $conf->get("mw");
    my($tl) = $mw->Toplevel();
    $tl->geometry("+0+5");
    $tl->focus();
    $conf->set("tl", $tl);
    $tl->OnDestroy([ \&destroy_config, $conf ]);
    Configclient::main($tl, [ \&quit_config, $conf]);
}

# We now want the user to select the number of tables,
# and the movement, and who is missing.
sub setup_movementchoice
{
    my($conf) = @_;

    # First a list of radio buttons that select the table
    # number. Allow 3-20 tables.

    my($mw) = $conf->get("mw");
    my($mf);
    my($rf);
    my($rrf);
    my($rrrf);
    my($rrrrf);

    my($f) = $mw->Frame();
    $f->pack(-side => "top");

    my($but) = $f->Button(-text => "Back",
                          -command => [ \&backtomain, $conf]);
    $but->pack(-side => "left");

    $but = $f->Button(-text => "Quit", -command => [ sub {exit(0);} ]);
    $but->pack(-side => "left");

    $mf = $mw->Frame(
                     -relief => "ridge",
                     -borderwidth => 5,
                    );
    $mf->pack(-side => "left");
    $rf = $mw->Frame(
                     -relief => "ridge",
                     -borderwidth => 5,
                    );
    $rf->pack(-side => "left");
    $rrf = $mw->Frame(
                      -relief => "ridge",
                      -borderwidth => 5,
                     );
    $rrf->pack(-side => "left");
    $rrrf = $mw->Frame(
                       -relief => "ridge",
                       -borderwidth => 5,
                      );
    $rrrf->pack(-side => "left");
    $rrrrf = $mw->Frame(
                        -relief => "ridge",
                        -borderwidth => 5,
                       );
    $rrrrf->pack(-side => "left");
    $conf->set("mf", $mf);
    $conf->set("rf", $rf);
    $conf->set("rrf", $rrf);
    $conf->set("rrrf", $rrrf);
    $conf->set("rrrrf", $rrrrf);
    $conf->set("tablerb", "");
    $conf->set("moverb", "");

    my($table);

    for ($table = 2; $table <= 20; $table++) {
        my($rb);

        $rb = $mf->Radiobutton(
                               -text => "$table tables",
                               -value => $table,
                               -variable => $conf->getref("tablerb"),
                               -indicatoron => 0,
                               -command => [ \&showselmove, $conf ],
                              );
        $rb->pack(-side => "top", -fill => "x");
    }
}

sub backtomain
{
    my($conf) = @_;

    $conf->set("mf", undef);
    $conf->set("rf", undef);
    $conf->set("rrf", undef);
    $conf->set("rrrf", undef);
    $conf->set("rrrrf", undef);
    $conf->set("lrb", undef);
    $conf->set("lab", undef);
    $conf->set("tablerb", "");
    $conf->set("moverb", "");

    my($mw) = $conf->get("mw");
    foreach my $f ($mw->children()) {
        $f->destroy();
    }
    setup_date_suffix($mw, $conf);
}


#
# The user has selected a numner of tables, show all the movements
# that match that number of tables.
sub showselmove
{
    my($conf) = @_;
    my($tabno) = $conf->get("tablerb");
    my($rf) = $conf->get("rf");
    my($lrb) = $conf->get("lrb");

    if ($lrb) {
        foreach my $rb (@$lrb) {
            $rb->destroy();
        }
        $conf->set("lrb", undef);
    }

    my($lab) = $conf->get("lab");
    if ($lab) {
        $lab->destroy();
        $conf->set("lab", undef);
    }
    # Ditch the previous right right frame
    my($rrf) = $conf->get("rrf");
    if ($rrf) {
        $rrf->packForget();
    }

    my($rrrf) = $conf->get("rrrf");
    if ($rrrf) {
        $rrrf->packForget();
    }

    my($rrrrf) = $conf->get("rrrrf");
    if ($rrrrf) {
        $rrrrf->packForget();
    }
    my(@mfiles) = bsd_glob("$Conf::movesdir/T$tabno*");
    # We have to basename them
    my($mfile);
    $lrb = [];
    my($len) = 12;
    foreach $mfile (@mfiles) {
        my($rb);
        ($mfile, undef, undef) = fileparse($mfile);
        $rb = $rf->Radiobutton(
                               -text => $mfile,
                               -value => $mfile,
                               -variable => $conf->getref("moverb"),
                               -width => $len,
                               -justify => "right",
                               -indicatoron => 0,
                               -command => [ \&selmove, $conf ],
                              );
        $rb->pack(-side => "top");
        push(@$lrb, $rb);
    }
    $conf->set("lrb", $lrb);
#    die("Selected table number is $tabno\n");
}

sub selmove
{
    my($conf) = @_;
    my($sel) = $conf->get("moverb");

    # We have to open the specified movement file.

    my($path) = $Conf::movesdir . "/" . $sel;
    my($fh);
    my($mc);
    my($lab);

    $lab = $conf->get("lab");
    if ($lab) {
        $lab->destroy();
        $conf->set("lab", undef);
    }

    $fh = IO::File->new();
    $mc = Move::Moveconfig->new();

    if (!$fh->open($path, "<")) {
        die("I can't open ($path) $!\n");
    }
    $mc->load($fh);
    $conf->set("mcpath", $path);
    # Create the label, and show the description.
    my($rrf) = $conf->get("rrf");
    $rrf->pack(-side => "left");
    $lab = $rrf->Label(
                       -text => $mc->{desc},
                       -padx => 3,
                      );

    $conf->set("lab", $lab);
    $lab->pack(-side => "top");

    # Setup the table of missing pairs.
    my($rrrf) = $conf->get("rrrf");
    ungridall($rrrf);
    $rrrf->pack(-side => "left");


    # We are going to grid it.
    # 1. Do the first row.
    $lab = $rrrf->Label(-text => "Half Table\nSelection");
    $lab->grid(-row => 0, -column => 0);

    $lab = $rrrf->Label(-text => "N/S pair");
    $lab->grid(-row => 0, -column => 1);

    $lab = $rrrf->Label(-text => "E/W pair");
    $lab->grid(-row => 0, -column => 2);

    $mc->generate();
    my($not) = $mc->get_not();
    my($rounds) = $mc->get_rounds();
    my($maxrounds) = $mc->get_maxrounds();
    my($tbl);

    my($tblctl) = $mc->{rndctl}->[0]->{tables};

    my($missing_but) = [];
    for ($tbl = 1; $tbl <= $not ; $tbl++) {
        $lab = $rrrf->Label(-text => "Table $tbl");
        $lab->grid(-row => $tbl, -column => 0);
        my($but);
        $but = $rrrf->Button(
                             -text => $tblctl->[$tbl - 1]->{ns},
                             -command => [ \&missing_but, $conf, 0, $tbl - 1],
                             -width => 2,
                            );
        my($buttcol) = $but->cget("-background");
        $conf->set("buttcol", $buttcol);

        $missing_but->[0]->[$tbl - 1] = $but;
        $but->grid(-row => $tbl, -column => 1);


        $but = $rrrf->Button(
                             -text => $tblctl->[$tbl - 1]->{ew},
                             -command => [ \&missing_but, $conf, 1, $tbl - 1 ],
                             -width => 2,
                            );
        $missing_but->[1]->[$tbl -1] = $but;
        $but->grid(-row => $tbl, -column => 2);
    }

    my($rlab) = $rrrf->Label(-text => "Rounds");
    $rlab->grid(
                -row => $tbl,
                -column => 0,
                -pady => 10,
               );

    ## Add the rounf control button.
    $conf->set("round_var", $rounds);
    if (!defined($maxrounds)) {
        $maxrounds = $rounds;
    }
    my($nent) = $rrrf->NumEntry(
                                -readonly => 1,
                                -value => $rounds,
                                -maxvalue => $maxrounds,
                                -minvalue => int($rounds * 3 / 4),
                                -width => 3,
                                -browsecmd => [ \&changeround, $conf ],
                                -textvariable => $conf->getref("round_var"),
                               );
    $nent->grid(
                -row => $tbl,
                -column => 2,
                -pady => 10,
               );
    $tbl++;


    my($cb) = $rrrf->Checkbutton(
                                 -text => "Skip first round?",
                                 -variable => $conf->getref("sfr"),
                                 -command => [ \&changesfr, $conf ],
                                );
    $cb->grid(
              -row => $tbl,
              -column => 1,
              -pady => 10,
             );
    $tbl++;

    # Boards per round

    $rlab = $rrrf->Label(-text => "Boards\nper round");
    $rlab->grid(
                -row => $tbl,
                -column => 0,
                -pady => 10,
               );

    my($bpr) = $mc->get_bpr();
    $conf->set("bpr_var", $bpr);
    $nent = $rrrf->NumEntry(
                                -readonly => 1,
                                -maxvalue => maxbpr($mc->get_nos()),
                                -minvalue => 1,
                                -width => 3,
                                -browsecmd => [ \&changeround, $conf ],
                                -textvariable => $conf->getref("bpr_var"),
                               );
    $nent->grid(
                -row => $tbl,
                -column => 2,
                -pady => 10,
               );
    $tbl++;


    # And we put three extra buttons on the bottom row,
    # back a traveller, Setup, forward a traveller.

    my($but) = $rrrf->Button(
                             -text => "Back",
                             -command => [ \&changeset, $conf, 0 ],
                            );
    $but->grid(
               -row => $tbl,
               -column => 0,
               -pady => 10,
              );

    $but = $rrrf->Button(
                         -text => "Done",
                         -command => [ \&runsetup, $conf ],
                        );
    $but->grid(
               -row => $tbl,
               -column => 1,
               -pady => 10,
              );

    $but = $rrrf->Button(
                         -text => "Forward",
                         -command => [ \&changeset, $conf, 1 ],
                        );
    $but->grid(
               -row => $tbl,
               -column => 2,
               -pady => 10,
              );

    $conf->set("missing_but", $missing_but);
    $conf->set("set", 0);
    generate_trav($conf);
}

# Calculate a sensible maximum bpr based on the number of sets in the
# movement.
sub maxbpr
{
    my($sets) = @_;

    # Limit it by the number of bpr you can habdle with 40 boards
    # at your disposal.
    my($bpr) = int(40 / $sets);
    if ($bpr < 1) {
        $bpr = 1;
    }
    return $bpr;
}

sub changesfr
{
    my($conf) = @_;
    generate_trav($conf);
}

sub changeround
{
    my($conf) = @_;
    generate_trav($conf);
}

sub changeset
{
    my($conf, $inc) = @_;

    my($set) = $conf->get("set");
    if ($inc) {
        $set++;
    } else {
        $set--;
    }
    $conf->set("set", $set);
    generate_trav($conf);
}

sub generate_trav
{
    my($conf) = @_;
    my($rrrrf) = $conf->get("rrrrf");

    unpackall($rrrrf);
    $rrrrf->pack(-side => "left");
    my($tfh);
    my($trav);
    my($mcpath) = $conf->get("mcpath");
    my($mpair) = $conf->get("mpair");
    my($set) = $conf->get("set");
    my($mc);
    my($rounds) = $conf->get("round_var");
    my($bpr) = $conf->get("bpr_var");
    my($sfr) = $conf->get("sfr");

    $mc = Move::Moveconfig->new();
    my($fh) = IO::File->new();
    $fh->open($mcpath, "<");
    $mc->load($fh);

    if ($mpair) {
        $mc->set_excludepair($mpair);
    }
    $mc->set_bpr($bpr);
    $mc->generate($rounds);
    $tfh = IO::File->new();
    $tfh->open(\$trav, ">");

    my($moves) = $mc->get_moves($sfr);
    my($sets) = $mc->get_nos();

    if ($set < 0) {
        $set = 0;
        $conf->set("set", $set);
    }
    if ($set >= $sets) {
        $set = $sets - 1;
        $conf->set("set", $set);
    }
    my(@m) = split(m/,/, $moves->[$set]);
    my($m);
    my(@msort);

    my($low, $high);
    $low = $set * $bpr + 1;
    $high = $low + $bpr - 1;

    for ($m = 0; $m < @m; $m += 2) {
        push(@msort, [ $m[$m], $m[$m + 1] ]);
    }
    if ($Conf::Travsort) {
        @msort = sort({$a->[0] <=> $b->[0]} @msort);
    }
    $tfh->print("Traveller $low-$high\n",
                "---------\n");
    my($start) = 0;
    foreach $m (@msort) {
        $tfh->print("\n") if $start > 0;
        $tfh->printf("%2d %2d", $m->[0], $m->[1]);
        $start++;
    }

    # This is the traveller display.
    my($font) = $conf->get("font");
    my($tlab) = $rrrrf->Label(
                              -font => $font,
                              -text => $trav,
                              -padx => 3,
                             );
    $tlab->pack(-side => "top");
}

sub missing_but
{
    my($conf, $ew, $tbl) = @_;

    my($missing_but) = $conf->get("missing_but");
    my($but) = $missing_but->[$ew]->[$tbl];

    my($mpair) = $conf->get("mpair");
    my($buttcol) = $conf->get("buttcol");
    my($bcol) = $but->cget("-background");

    if ($bcol eq $buttcol) {
        $but->configure(
                        -background => "blue",
                        -activebackground => "blue",
                        -activeforeground => "white",
                        -foreground => "white",
                       );
        $mpair = $but->cget("-text");
        # Have to turn the rest off.
        if ($mpair) {
            my($out, $in);
            foreach $out (@$missing_but) {
                foreach $in (@$out) {
                    if ($in != $but) {
                        $in->configure(
                                       -background => $buttcol,
                                       -activebackground => $buttcol,
                                       -activeforeground => "black",
                                       -foreground => "black",
                                      );
                    }
                }
            }
        }
    } else {
        $but->configure(
                        -background => $buttcol,
                        -activebackground => $buttcol,
                        -activeforeground => "black",
                        -foreground => "black",
                       );
        $mpair = 0;
    }
    $conf->set("mpair", $mpair);
    generate_trav($conf);
}

# at last....
sub runsetup
{
    my($conf) = @_;
    my($mw);
    # Get the main window....
    $mw = $conf->get("mw");

    my($datestr) = $conf->get("datestr");
    my($suffix) = $conf->get("suffix");
    my($title_str);

    my(@y) = $datestr =~ m/^(\d\d\d\d)(\d\d)(\d\d)/;
    $title_str = "$y[0]-$y[1]-$y[2]";
    if ($suffix) {
        $title_str .=  "_" . $suffix;
    }
    $mw->title("$Conf::Club - Session: $title_str");

    # remove all the widgets.
    unpackall($mw);

    # But we have to run the setup program first, if the movement
    # path is set.
    my($mcpath) = $conf->get("mcpath");
    my($rounds) = $conf->get("round_var");
    my($bpr) = $conf->get("bpr_var");
    my($sfr) = $conf->get("sfr");
    if ($mcpath) {
        local(@ARGV);
        @ARGV = ();
        push(@ARGV, "-s", $mcpath);
        my($mpair);

        $mpair = $conf->get("mpair");
        if ($mpair) {
            push(@ARGV, "-e", $mpair);
        }
        if ($sfr) {
            push(@ARGV, "-k");
        }
        push(@ARGV, "-r", $bpr, "-R", $rounds);
        my($datestr) = $conf->get("datestr");
        my($suf) = $conf->get("suffix");
        if ($suf) {
            $datestr .= "_$suf";
        }
        push(@ARGV, $datestr);
        # Don't catch the exception.... we don't do anything with it.
        Bsetupclient::main();
    }
    # We want four  button, "edit contacts", "trav", "pairs", "score".
    my($tf, $bf);
    $tf = $mw->Frame();
    $tf->pack(-side => "top");

    my($ctlbuts) = [];
    my($but);
    $but = $tf->Button(
                       -text => "Enter Traveller details",
                       -command => [ \&trav, $conf ],
                       );
    $but->pack(-side => "left", -fill => "x");
    push(@$ctlbuts, $but);

    $but = $tf->Button(
                       -text => "Enter Pair details",
                       -command => [ \&pair, $conf ],
                       );
    $but->pack(-side => "left", -fill => "x");
    push(@$ctlbuts, $but);

    $but = $tf->Button(
                       -text => "Edit Pair database",
                       -command => [ \&playeredit, $conf ],
                       );
    $but->pack(-side => "left", -fill => "x");
    push(@$ctlbuts, $but);

    # Not efficient.....
    eval "require Bridgemate";
    if (!$@ && ($^O eq "MSWin32")) {
        # We only support this on Win32.
        $but = $tf->Button(
                           -text => "BridgeMate",
                           -command => [ \&bridgemate, $conf ],
                          );
        $but->pack(-side => "left", -fill => "x");
        push(@$ctlbuts, $but);
    }

    $but = $tf->Button(
                       -text => "Score",
                       -command => [ \&score, $conf ],
                      );
    $but->pack(-side => "left", -fill => "x");
    push(@$ctlbuts, $but);

    # Add the ecats session number box.
    {
        my($label) = $tf->Label(-text => "Ecats:");
        my($session) = getecats($conf);
        $conf->set("ecats_session", $session);
        $conf->set("ecats_session_orig", $session);
        $label->pack(-side => "left", -fill => "x");

        my($ent) = $tf->Entry(-textvariable => $conf->getref("ecats_session"),
                             -width => 8);
        $ent->pack(-side => "left", -fill => "x");
        push(@$ctlbuts, $ent);
    }

    # The do all the scoring based updates.
    # Not sure this is correct, we may still want the
    # competition pages generated?
    if (defined($Conf::bridgeweb_scores) && $Conf::bridgeweb_scores &&
        defined($Conf::BWpassword) && $Conf::BWpassword) {
        $but = $tf->Button(
                -text => "Update Bridgewebs",
                -command => [ \&updatebw, $conf ],
                          );
        $but->pack(-side => "left", -fill => "x");
        push(@$ctlbuts, $but);
    }
    $but = $tf->Button(
                       -text => "Quit",
                       -command => \&exit,
                       );
    $but->pack(-side => "left", -fill => "x");
    push(@$ctlbuts, $but);
    $conf->set("ctlbuttons", $ctlbuts);
}

# Run the traveller sub command
sub trav
{
    my($conf) = @_;
    my($dir);
    my($datestr) = $conf->get("datestr");
    my($suf) = $conf->get("suffix");
    $dir = "$datestr";
    if ($suf) {
        $dir .= "_$suf";
    }

    my($mw) = $conf->get("mw");
    my($tl) = $mw->Toplevel();
    $tl->focus();
    $conf->set("tl", $tl);
    control_buttons($conf, 0);
    remove_textframe($conf);
    $tl->OnDestroy([ \&destroy_tidy, $conf ]);
    Travclient::main($tl, $dir, [ \&quit_trav, $conf ]);

}
# Run the traveller sub command
sub playeredit
{
    my($conf) = @_;

    my($mw) = $conf->get("mw");
    my($tl) = $mw->Toplevel();
    # put us at the top, so that the 'Done' button is visible
    $tl->geometry("+0+5");
    $tl->focus();
    $conf->set("tl", $tl);
    control_buttons($conf, 0);
    remove_textframe($conf);
    $tl->OnDestroy([ \&destroy_tidy, $conf ]);
    Playereditclient::main($tl, [ \&quit_trav, $conf ]);
}

sub destroy_tidy
{
    my($conf) = @_;
    control_buttons($conf, 1);
}

sub quit_trav
{
    my($conf) = @_;
    my($tl) = $conf->get("tl");
    $conf->set("tl", undef);
    if ($tl) {
        $tl->destroy();
    }
}

# Run the pair sub command
sub pair
{
    my($conf) = @_;
    my($dir);
    my($datestr) = $conf->get("datestr");
    my($suf) = $conf->get("suffix");
    $dir =  $datestr;
    if ($suf) {
        $dir .= "_$suf";
    }
    my($mw) = $conf->get("mw");
    my($tl) = $mw->Toplevel();
    # put us at the top, so that the 'Done' button is visible
    $tl->geometry("+0+5");
    $tl->focus();
    $conf->set("tl", $tl);
    control_buttons($conf, 0);
    remove_textframe($conf);
    $tl->OnDestroy([ \&destroy_tidy, $conf ]);
    # The fourth argument is the width, which controls scrolling.
    # TODO.
    Pairmapclient::main($tl, $dir, [\&quit_trav, $conf ], undef);
}

sub score
{
    my($conf) = @_;
    remove_textframe($conf);
    my($cmd);

    local(@ARGV);
    @ARGV = ();
    if ($Conf::short_scores) {
        push(@ARGV, "-s");
    }
    if ($Conf::bridgeweb_scores) {
        push(@ARGV, "-b");
    }

    if ($Conf::nomp) {
        push(@ARGV, "-m");
    }

    my($datestr) = $conf->get("datestr");
    my($suf) = $conf->get("suffix");
    $cmd =  $datestr;
    if ($suf) {
        $cmd .= "_$suf";
    }
    push(@ARGV, $cmd);
    my($fh);
    my($data);
    my($mw) = $conf->get("mw");

    $fh = IO::File->new();
    $fh->open(\$data, ">");
    control_buttons($conf, 0);
    # Make sure the buttosn go off.
    $mw->update();
    my($f);
    $f = $mw->Frame();
    $f->pack(-side => "top");
    my($t);
    my($font) = $conf->get("font");
    $t = $f->Scrolled("ROText", -scrollbars => 'e');
    $fh = Pseudofh->new($t);
    eval {
        Scoreclient::main($fh);
    };
    # Fix it so we see the N/S scores first.
    $t->see("1.0");
    if ($@) {
        $fh->print("scoring failed: $@");
    } else {
        # See if the ecats session is set, and if so run
        # the ecats scoreing session
        my($sess) = $conf->get("ecats_session");
        if (length($sess) > 0) {
            if ($sess =~ m/\D/) {
                $fh->print("Illegal character in ecats session only digits allowed\n");
            } else {
                $fh->print("Running Ecats - $datestr $sess\n");
                @ARGV = ();
                push(@ARGV, "-e", $datestr, "-s", $sess, $cmd);
                eval {
                    Ecatsclient::main($fh);
                };
                if ($@) {
                    $fh->print("Ecats scoring failed ($@)\n");
                } else {
                    $fh->print("Ecats scoring complete\n");
                }
            }
        }
    }


    # Only run it if scoring today or a day after.
    # We have already done this at start up.
    my($tm);
    $tm = [ localtime() ];
    my($datenow) = sprintf("%04d%02d%02d", $tm->[5] + 1900, $tm->[4] + 1,
                           $tm->[3]);

    if (($datestr + 1) >= $datenow) {
        # Run the inactive script.
        @ARGV = ();
        push(@ARGV, $datestr);
        eval {
            Inactiveclient::main($fh);
        };
    }
    control_buttons($conf, 1);
    $t->pack(-side => "top");
    $conf->set("textframe", $f);
}


sub bridgemate
{
    my($conf) = @_;
    my($dir);
    my($datestr) = $conf->get("datestr");
    my($suf) = $conf->get("suffix");
    my($mw) = $conf->get("mw");
    my($tl) = $mw->Toplevel();
    my($single);

    $tl->title("BridgeMate Control Window");



    $dir = "$datestr";
    if ($suf) {
        $dir .= "_$suf";
    }

#    $tl->geometry("+0+5");
    $tl->focus();
    $conf->set("tl", $tl);
    control_buttons($conf, 0);
    remove_textframe($conf);
    $tl->OnDestroy([ \&destroy_tidy, $conf ] );

    # See if we have an existing bridgemate object.
    my($bm) = $conf->get("bm");

    # Lets defined some state variables.
    my($havedb); # is the database created and setup?
    my($haveprog); # Is the bridgemates control program running.


    if (!defined($bm)) {
        $bm = Bridgemate->new($dir);
        $conf->set("bm", $bm);
        $haveprog = 0;
    } else {
        $haveprog = $bm->haveprog();
    }
    $havedb = $bm->havedb();
    # Create the required buttons.
    # First, one to create the db.
    my($state);
    my($action);
    my($pstate);
    # If the prog is running we can't recreate the db
    if ($havedb) {
        $pstate = "normal";
        if ($haveprog) {
            $state = "disabled";
            $action = "Stop";
            # Start the polling process
            start_poll($conf, $tl, $bm);
        } else {
            $state = "normal";
            $action = "Start";
        }
    } else {
        $state = "normal";
        $pstate = "disabled";
        $action = "Start";
    }

    my($but) = $tl->Button(-text => "Create database", -state => $state);
    $but->pack(-side => "top");

    my($but2) = $tl->Button(-text => "$action BridgeMate Process", -state => $pstate);
    $but2->pack(-side => "top");

    $but->configure(-command => [ \&bmcreatedb, $but, $but2, $conf ]);
    $but2->configure(-command => [ \&startbm, $but, $but2, $conf ]);

    $but = $tl->Button(-text => "Back", -command => [ \&quit_trav, $conf]);
    $but->pack(-side => "top");

    # Create a frame in which to place the ProgressBars
    my($framep) = $tl->Frame();
    $framep->pack(-side => "top", -expand => 1, -fill => 'x');

    my($resultbar) = $framep->ProgressBar(-variable => $conf->getref("resultpb"), -colors => [ 50, "green", 100 => "red"]);
    $resultbar->pack(-side => "left");

    $resultbar = $framep->ProgressBar(-variable => $conf->getref("playerpb"), -colors => [ 50, "green", 100 => "red" ]);
    $resultbar->pack(-side => "right");

    # Update the progress bars
    $conf->set("playerpb", $bm->playerprogress());
    $conf->set("resultpb", $bm->resultprogress());

    my($t) = $tl->Scrolled("ROText", -scrollbars => 'e', -height => 3);
    $t->pack(-side => "top");
    my($fh) = Pseudofh->new($t);
    $bm->setfh($fh);


    my($fr) = $tl->Frame(-borderwidth => 5);
    $fr->pack(-side => "top", -expand => 1, -fill => 'x');
    my($frames) = [];
    if ($bm->{setup}->winners() == 2) {
        my($frns) = $fr->Frame(-borderwidth => 1);
        $frns->pack(-side => "left", -expand => 1, -fill => 'x');
        my($frew) = $fr->Frame(-borderwidth => 1);
        $frew->pack(-side => "left", -expand => 1, -fill => 'x');
        push(@$frames, $frns, $frew);
    } else {
        push(@$frames, $fr);
    }
    $conf->set("bmframes", $frames);
}


sub startbm
{
    my($but, $but2, $conf) = @_;
    my($tl) = $conf->get("tl");
    my($bm) = $conf->get("bm");

    if ($bm->haveprog()) {
        $bm->stop_process();
        $but2->configure(-text => "Start BridgeMate Process");
        $but->configure(-state => "normal");
        if ($tl) {
            my($id) = $bm->getid();
            $id->cancel();
        }
    } else {
        # Don't let them create the database if the BM process
        # is running.
        $but->configure(-state => "disabled");
        # Start the BM process
        my($bm) = $conf->get("bm");
        $bm->start_process();
        start_poll($conf, $tl, $bm);
        $but2->configure(-text => "Stop BridgeMate Process");
    }
}

sub start_poll
{
    my($conf, $tl, $bm) = @_;
    my($id) = $tl->repeat(5000, [ \&process_bm_results, $conf ]);
    $bm->setid($id);
}


sub bmcreatedb
{
    my($but, $but2, $conf) = @_;
    my($bm) = $conf->get("bm");
    my($ret) = $bm->createdb();
    if ($ret) {
        return;
    }
    # ok, we have a created database, so we can allow
    # the start process button to be enabled.
    $but2->configure(-state => "normal");
}


sub process_bm_results
{
    my($conf) = @_;
    my($dir);
    my($datestr) = $conf->get("datestr");
    my($suf) = $conf->get("suffix");
    my($bm) = $conf->get("bm");

    $dir = $datestr;
    if ($suf) {
        $dir .= "_$suf";
    }
    $bm->get_latest();
    $bm->save();
    # Update the progress bars
    $conf->set("playerpb", $bm->playerprogress());
    $conf->set("resultpb", $bm->resultprogress());

    # score it
    local(@ARGV);
    @ARGV = ();
    push(@ARGV, "-s", "-a", $dir);

    my($fh) = IO::File->new();
    my($data);

    $fh->open(\$data, ">");
    Scoreclient::main($fh);
    $fh->close();
    undef($fh);
    # Load the Score file.

    my($sc) = Scorepositions->new();
    $sc->load($dir);
    my($frames) = $conf->get("bmframes");
    my($inner);
    my($ind) = 0;
    if ($bm->{setup}->winners() == scalar(@{$sc->{array}})) {
        foreach $inner (@{$sc->{array}}) {
            display_partial_result($frames->[$ind], $inner, $bm->single());
            $ind++;
        }
    }
}

sub display_partial_result
{
    my($frame, $ranks, $single) = @_;

    # Remove all the existing content.
    foreach my $f ($frame->children()) {
        $f->destroy();
    }
    my($row) = 0;
    my($ent);

    foreach $ent (@$ranks) {
        my($lab) = $frame->Label(-text => $ent->{pos}, -borderwidth => 5,
                                -relief => "ridge", -width => 4);
        $lab->grid(-column => 0, -row => $row, -sticky => "e");

        my($name);
        if (!defined($ent->{pair})) {
            $name = "Pair $ent->{matchpair}";
        } else {
            $name = $single->fullname($ent->{pair} . " ($ent->{matchpair})");
        }
        $lab = $frame->Label(-text => $name, -borderwidth => 5, -relief =>
                            "ridge");
        $lab->grid(-column => 1, -row => $row, -sticky => "nsew");

        $lab = $frame->Label(-text => $ent->{percent}, -borderwidth => 5,
                            -relief => "ridge", -width => 6);
        $lab->grid(-column => 2, -row => $row, -sticky => "w");

        $row++;
    }
}





# Find and remove the frame that holds the score Text box.
sub remove_textframe
{
    my($conf) = @_;

    my($mw) = $conf->get("mw");
    my($textframe) = $conf->get("textframe");

    if ($textframe) {
        foreach my $f ($mw->children()) {
            if ($f == $textframe) {
                $f->destroy();
                $conf->set("textframe", undef);
                last;
            }
        }
    }
}

# Disable the control buttons,
# Called when running a sub process.
sub control_buttons
{
    my($conf, $enable) = @_;
    my($ctlbuts) = $conf->get("ctlbuttons");
    my($but);
    my($state);
    if ($enable) {
        # Save the ecats session, if required.
        setsess($conf);
        $state = "normal";
    } else {
        $state = "disabled";
    }

    if (!scalar(@$ctlbuts) || !Tk::Exists($ctlbuts->[0])) {
        # These buttons may have been destroyed already
        return;
    }

    foreach $but (@$ctlbuts) {
        $but->configure(-state => $state);
    }
}

sub unpackall
{
    my($widget) = @_;
    my($w);
    foreach $w ($widget->children()) {
        my(@i);

        @i = $w->configure();
        foreach my $i (@i) {
            if ($i->[0] eq "-command") {
                $w->configure(-command => undef());
                last;
            }
        }
        $w->destroy();
    }
}

sub ungridall
{
    my($widget) = @_;
    my($w);

    foreach $w ($widget->children()) {
        my(@i);

        @i = $w->configure();
        foreach my $i (@i) {
            if ($i->[0] eq "-command") {
                $w->configure(-command => undef());
                last;
            }
        }
        $w->destroy();
    }
}

sub updatebw
{
    my($conf) = @_;
    my($perlpath) = $conf->get("perlpath");
    my($cmd);
    # Remove any existing text frame.
    remove_textframe($conf);

    # Run the competition generator.
    my($suf) = $conf->get("suffix");
    # If we have a suffix, then don't process this result.
    if ($suf) {
        return;
    }
    my($datestr) = $conf->get("datestr");
    local(@ARGV);
    @ARGV = ();
    if (defined($Conf::compargs[0])) {
        push(@ARGV, @Conf::compargs);
    }
    push(@ARGV, $datestr);
    my($fh);
    my($data) = "";
    my($mw) = $conf->get("mw");
    my($f);
    $f = $mw->Frame();
    $f->pack(-side => "top");
    my($t);
    my($font) = $conf->get("font");
    $t = $f->Scrolled("ROText", -scrollbars => 'e');
    $t->pack(-side => "top");
    $conf->set("textframe", $f);
    $t->update();
    $fh = Pseudofh->new($t);
    control_buttons($conf, 0);
    # Make sure the buttons go off.
    $mw->update();
    eval {
        Compclient::main($fh);
    };
    if ($@) {
        $fh->print($@);
        control_buttons($conf, 1);
        return;
    }

    eval {
        Uploadbwclient::main($fh);
    };
    if ($@) {
        $fh->print($@);
        control_buttons($conf, 1);
        return;
    }

    local(@ARGV);
    @ARGV = ();
    push(@ARGV, $datestr);
    eval {
        Uploadresultclient::main($fh);
    };
    if ($@) {
        $fh->print($@);
    }
    control_buttons($conf, 1);
}

sub getecats
{
    my($conf) = @_;
    my($sess);
    my($fh) = IO::File->new();

    my($fname) = ecatsfilename($conf);
    if ($fh->open($fname, "<")) {

        my($line) = $fh->getline();
        $fh->close();
        chomp($line);
        $sess = $line;
    } else {
        $sess = "";
    }
    return $sess;
}

sub setsess
{
    my($conf) = @_;
    my($sess) = $conf->get("ecats_session");
    my($sess_orig) = $conf->get("ecats_session_orig");
    if ($sess ne $sess_orig) {
        if ($sess =~ m/\D/) {
            # Bad character.
            $conf->set("ecats_session", $sess_orig);
        } else {
            my($fh) = IO::File->new();
            my($fname) = ecatsfilename($conf);
            if ($fh->open($fname, ">")) {
                $fh->print($sess, "\n");
                $fh->close();
                $conf->set("ecats_session_orig", $sess);
            }
        }
    }
}


sub ecatsfilename
{
    my($conf) = @_;
    my($date) = $conf->get("datestr");
    my($suf) = $conf->get("suffix");
    my($dir) = $date;
    if ($suf) {
        $dir .= "_$suf";
    }
    $dir = "$Conf::resdir/$dir/ecats_session.txt";
    return $dir;
}


# A filehandle that writes to a text box.
#################
package Pseudofh;
#################
sub new
{
    my($class) = shift();
    my($textbox) = @_;

    my($self) = {};
    $self->{textbox} = $textbox;
    bless($self, $class);
    return $self;
}

sub print
{
    my($self) = shift();
    my(@msg) = @_;
    my($msg) = join("", @msg);
    my($tb) = $self->{textbox};

#    chomp($msg);
    $tb->insert("end", $msg);
    $tb->see("end");
    $tb->update();
}

1;

