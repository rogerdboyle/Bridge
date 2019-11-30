#!/usr/bin/perl
# Copyright (c) 2007 Paul Haffenden. All rights reserved.
# $Id: score.pl 1046 2013-02-22 19:35:35Z phaff $

use strict;
use warnings;

use Conf;
use Scoreclient;

sub main
{
    Scoreclient::main();
}

main();
exit(0);
