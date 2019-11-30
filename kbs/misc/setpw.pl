#!/usr/bin/perl

#
#
# Set the encrpytion password in the config file.
#

use strict;
use warnings;

use Conf;

sub main
{
    if (!defined($ARGV[0])) {
        die("You must pass in the password on the command line\n");
    }
    my($cl) = Confload::load(1);
    $cl->{Conf}->{BWpassword}->{val} = $ARGV[0];
    Confload::save($cl);
}

main();
exit(0);
