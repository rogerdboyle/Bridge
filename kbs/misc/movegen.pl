#!/usr/bin/perl

# Movement generator. Uses input data files to create
# a table and traveller details.

use strict;
use warnings;

use Dir::Self qw(:static);
use lib __DIR__ . "/../lib";

use Movegenclient;

sub main
{
    Movegenclient::main();
}

main();
exit(0);

