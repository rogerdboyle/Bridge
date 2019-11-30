#!/usr/bin/perl

# $Id: ecats.pl 1046 2013-02-22 19:35:35Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

# Given a result directory, generate the ecats results files,
# C.TXT, R.TXT, P.TXT, E.TXT, in the directory "ecats".

use strict;
use warnings;

use Conf;

use Ecatsclient;

sub main
{
    Ecatsclient::main();
}

main();
exit(0);
