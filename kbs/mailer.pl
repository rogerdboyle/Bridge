#!/usr/bin/perl
# Copyright (c) 2007 Paul Haffenden. All rights reserved.
# $Id: mailer.pl 1046 2013-02-22 19:35:35Z phaff $
use strict;
use warnings;

use Conf;
use Mailclient;

# We are now just a front end to the library code.
#
sub main
{
    Mailclient::main();
}


main();
exit(0);


