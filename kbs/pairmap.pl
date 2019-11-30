#!/usr/bin/perl

# $Id: pairmap.pl 1046 2013-02-22 19:35:35Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

use strict;
use warnings;
use Tk;
use Getopt::Std;

use Conf;
use Pairmapclient;

sub main
{
    my($mw);
    my($opts) = {};
    my($rwidth);
    my($dir);

    getopts("Ww:", $opts);

    if (exists($opts->{W})) {
        $rwidth = 650;
    }
    if (exists($opts->{w})) {
        if (defined($rwidth)) {
            die("You can't specify both -w and -W\n");
        }
        $rwidth = $opts->{w};
        if ($rwidth =~ m/\D/) {
            die("The width argumnet must be numeric\n");
        }
        if ($rwidth == 0) {
            die("The width argument must not be zero\n");
        }
    }

    if (!defined($ARGV[0])) {
        die("Directory argument not specified\n");
    }
    $dir = $ARGV[0];
    $mw = MainWindow->new();
    Pairmapclient::main($mw, $dir, [ \&exit ], $rwidth);
    MainLoop();
}

main();
exit(0);
