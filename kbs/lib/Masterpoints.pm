#####################
package Masterpoints;
#####################

# $Id: Masterpoints.pm 669 2011-03-04 07:51:28Z paulh $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

# Calculate the number of Master points to be awarded.
use strict;
use warnings;

use constant TWOWINNER => 10;
use constant ONEWINNER => 6;


# Return an array of points, the first (index 0) being the
# points awards to the winner, index 1 second place etc.
# Takes argument of the number of boards, number of pairs, and
# if split results.
# Return an empty array if no points can be awarded.

sub mppoints
{
    use integer;
    my($boards, $nopairs, $issplit) = @_;
    my(@ret) = ();
    my($div);
    # Number of full tables, by dividing the number of pairs by
    # two and discarding any remained.
    my($tbls) = $nopairs / 2;

    # Must have at least 5 tables for a split award.
    if ($issplit && $tbls <= 4) {
        return (@ret);
    }

    # If we are not split, then we have double the number of winners.
    if (!$issplit) {
        $tbls *= 2;
    }


    if ($boards < 18) {
        $div = 4; # Less than 18 boards, than a fourth of the
                  # field gets points.
    } elsif ($boards > 35) {
        $div = 2; # Greater than 35 boards, then a half of the
                  # field gets points.
    } else {
        # 18 - 35 a third of the field
        $div = 3;
    }

    # Find the number of winners by dividing by $div
    my($ents) = $tbls / $div;
    # Round up
    if ($tbls % $div) {
        $ents++;
    }
    my($mul) = ($issplit) ? TWOWINNER : ONEWINNER;
    # allocate the points to the winner
    my($top) = $ents * $mul;
    while ($top > 0) {
        push(@ret, $top);
        $top -= $mul;
    }
    return @ret;
}

1;
