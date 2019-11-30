#!/usr/bin/perl
#
# Copyright (c) 2010 Paul Haffenden. All rights reserved.
# quick and dirty upload to the bridgewebs site, namely
# all the document competition files.
# $Id: uploadbw.pl 781 2011-10-19 11:35:53Z phaff $

use strict;
use warnings;
use Conf;

use lib "lib";
use Uploadbwclient;

sub main
{
    Uploadbwclient::main();
}

main();
exit(0);
