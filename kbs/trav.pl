#!/usr/bin/perl

# $Id: trav.pl 1046 2013-02-22 19:35:35Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

use strict;
use warnings;
use Tk;

use Conf;
use Travclient;

sub main
{
    my($dir);
    my($mw);

    if (!defined($ARGV[0])) {
        die("Must specify a result directory\n");
    } else {
        $dir = $ARGV[0];
    }

    $mw = MainWindow->new(-width => 800, -height => 600);
    Travclient::main($mw, $dir, [ \&exit ]);
    MainLoop();
}


main();
exit(0);
