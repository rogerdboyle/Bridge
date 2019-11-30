# $Id: Board.pm 540 2010-04-28 15:25:24Z root $

# Copyright (c) 2007 Paul Haffenden. All rights reserved.

##############
package Board;
##############

use strict;
use warnings;

use constant YES => 1;
use constant NO  => 0;

use constant NS => [ YES, NO ];
use constant EW => [ NO, YES ];
use constant BOTH => [ YES, YES ];
use constant NONE => [ NO, NO ];
our(@vul);
our(@deal);

BEGIN {
@vul = (
        NONE, # 1
        NS,   # 2
        EW,   # 3
        BOTH, # 4
        NS,   # 5
        EW,   # 6
        BOTH, # 7
        NONE, # 8
        EW,   # 9
        BOTH, # 10
        NONE, # 11
        NS,   # 12
        BOTH, # 13
        NONE, # 14
        NS,   # 15
        EW,   # 16
);

@deal = (
         "N",
         "E",
         "S",
         "W",
);
}

sub vul
{
    my($class) = shift();
    my($no) = @_;

    $no--;
    $no = $no % 16;
    return ($vul[$no]->[0], $vul[$no]->[1]);
}

sub vulstr
{
    my($class) = shift();
    my($no) = @_;
    my($obj);

    $no--;
    $no = $no % 16;
    $obj = $vul[$no];

    if ($obj->[0] && $obj->[1]) {
        return ("All");
    } elsif ($obj->[0]) {
        return ("N/S");
    } elsif ($obj->[1]) {
        return ("E/W");
    } else {
        return ("None");
    }
}

sub dealstr
{
    my($class) = shift();
    my($bn) = @_;
    $bn--;
    return ($deal[$bn % 4]);
}

1;
