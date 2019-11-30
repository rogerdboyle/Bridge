#!/usr/bin/perl

# $Id: pairmap.pl 576 2010-07-25 10:44:24Z root $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

use strict;
use warnings;

use Tk;
use Getopt::Std;

use Conf;
use Playereditclient;

sub main
{
    my($mw);

    $mw = MainWindow->new();
    Playereditclient::main($mw, [ \&exit ]);
    MainLoop();
}

main();
exit(0);
