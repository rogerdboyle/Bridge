#!/usr/bin/perl

# Copyright (c) 2007 Paul Haffenden. All rights reserved.
# $Id: bsetup.pl 1471 2015-10-09 05:45:56Z phaff $

use strict;
use warnings;

# Configure and setup the result data.

use Conf;
use Bsetupclient;
use Sql;

sub main
{
    Sql->GetHandle($Conf::Dbname);
    Bsetupclient::main();
}

main();
exit(0);
