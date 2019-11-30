#!/usr/bin/perl
# Generate all the competition result's data.
# $Id: comp.pl 778 2011-10-15 10:39:55Z phaff $
# Copyright (c) 2011 Paul Haffenden. All rights reserved.
#
# This is the front end to the competition generating process.
# We just call the library routine here and exit.
use strict;
use warnings;

use Conf;
use Compclient;

sub main
{
    Compclient::main();
}

main();
exit(0);


