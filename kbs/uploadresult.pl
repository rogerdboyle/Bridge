#!/usr/bin/perl
#
# Copyright (c) 2010 Paul Haffenden. All rights reserved.
# quick and dirty upload to the bridgewebs site, namely
# all the document competition files.
# $Id: uploadbw.pl 632 2011-01-01 12:11:25Z root $

use strict;
use warnings;
use Conf;

use Uploadresultclient;

sub main
{
    Uploadresultclient::main();
}

main();
exit(0);
