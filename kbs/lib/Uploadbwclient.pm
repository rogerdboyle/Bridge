#
# Copyright (c) 2010 Paul Haffenden. All rights reserved.
# quick and dirty upload to the bridgewebs site, namely
# all the document competition files.
# $Id:$

#######################
package Uploadbwclient;
#######################

use strict;
use warnings;
use Getopt::Std;
use Bridgewebs;

our($comp_files) = [
                   qw(wplay.htm
                      pplay.htm
                      splay.htm
                      tplay.htm
                      wpair.htm
                      spair.htm
                      tpair.htm
                      ppair.htm
                      seventy.htm
                      wilsondecay.htm
                      ruffdecay.htm
                      analysis.htm
                      graph.htm
                      howyou.htm
                      yearcompare.htm
                      sitout.htm
                      beamish.htm
                      allsessions.htm
                    )];
sub main
{
    my($fh, $fl) = @_;
    if (!defined($fh)) {
        $fh = "STDOUT";
    }
    my($suf);
    my($opts) = {};
    getopts("x:", $opts);
    if (exists($opts->{x})) {
        $suf = $opts->{x};
    } else {
        $suf = "";
    }
    my($filelist);
    if (!defined($fl)) {
        $filelist = [
                     "$Conf::compdir/wplay.htm" => "wplay.htm",
                     "$Conf::compdir/pplay.htm" => "pplay.htm",
                     "$Conf::compdir/splay.htm" => "splay.htm",
                     "$Conf::compdir/tplay.htm" => "tplay.htm",
                     "$Conf::compdir/wpair.htm" => "wpair.htm",
                     "$Conf::compdir/spair.htm" => "spair.htm",
                     "$Conf::compdir/tpair.htm" => "tpair.htm",
                     "$Conf::compdir/ppair.htm" => "ppair.htm",
                     "$Conf::compdir/seventy.htm" => "seventy.htm",
                     "$Conf::compdir/wilsondecay.htm" => "wilsondecay.htm",
                     "$Conf::compdir/ruffdecay.htm" => "ruffdecay.htm",
                     "$Conf::compdir/analysis.htm" => "analysis.htm",
                     "$Conf::compdir/graph.htm" => "graph.htm",
                     "$Conf::compdir/howyou.htm" => "howyou.htm",
                     "$Conf::compdir/yearcompare.htm" => "yearcompare.htm",
                     "$Conf::compdir/sitout.htm" => "sitout.htm",
                     "$Conf::compdir/beamish.htm" => "beamish.htm",
                    ];
    } else {
        $filelist = $fl;
    }

    # Apply the suffix to all the yeartotal files
    my($infilelist);
    if ($suf) {
        $infilelist = [];
        my($it);
        foreach $it (@$filelist) {
            if (($it =~ m/[wstp](play|pair)\./) || ($it =~ m/beamish\./)) {
                $it =~ s/\.htm/$suf.htm/;
                push(@$infilelist, $it);
            }
        }
    } else {
        $infilelist = $filelist;
    }


    my($bwup) = Bridgewebs->new();
    my($ret) = $bwup->upload($Conf::BWclub, $Conf::BWpassword, $infilelist, $fh);
    if ($ret) {
        die("The upload has failed $ret\n");
    }
}
1;
