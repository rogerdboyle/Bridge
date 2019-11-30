#
# Copyright (c) 2010 Paul Haffenden. All rights reserved.
# quick and dirty upload to the bridgewebs site, namely
# all the document competition files.
# $Id: Uploadresultclient.pm 1447 2015-09-09 14:31:41Z phaff $
###########################
package Uploadresultclient;
###########################
use strict;
use warnings;
use Bridgewebs;

sub main
{
    my($csvfile);
    my($sbwr) = Bridgewebs->new();

    if (!defined($ARGV[0])) {
        die("Must pass the date argument of the result file\n");
    }
    # The argument maybe an exact file name.
    # So try that first.
    if (stat($ARGV[0])) {
        $csvfile = $ARGV[0];
    } else {
        $csvfile = "bw_$ARGV[0].csv";
        if (!stat($csvfile)) {
            die("I can't find the result file $csvfile\n");
        }
    }
    my($ret) = $sbwr->action($Conf::BWclub, $Conf::BWpassword, $csvfile, "upload", "res");
    if ($ret) {
        die("The upload has failed $ret\n");
    }
}
1;
