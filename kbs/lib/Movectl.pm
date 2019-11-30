# $Id: Movectl.pm 699 2011-04-24 16:58:21Z root $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.
#
# Object that controls the movement data and tries
# to fill in the pair numbers for the user.
#

################
package Movectl;
################

use strict;
use warnings;

# Each one of these contains an ordered array. Each element in
# this arrry contain two values, the ns pair number and the ew
# pair number. e.g.
# [[1 , 2 ], [3, 4], ... ]

sub new
{
    my($class) = shift();
    my($self) = {};
    # The boardmap allows you to lookup the movement data
    # for a given board. The keys are the board number
    # and the values are the array refs returned by boardmove.
    $self->{boardmap} = {};
    return (bless($self, $class));
}

# Setup the boardmap. We get passed a boardnumber,
# the number of boards in a round, and a 'boardmove'.
sub setboardmap
{
    my($self) = shift();
    my($bn, $bpr, $move, $travorder) = @_;
    my($low, $high);
    my($ref);

    $ref = $self->{boardmap};

    $low = int(($bn - 1) / $bpr) * $bpr;
    $low = $low + 1;
    $high = $low + $bpr - 1;

    # Convert $move into a new record.
    # $rec->{move} is the array of traveller entries.
    # $rec->[lookup} is a hash of sort order keys, indexed
    # by the north pair number.
    # Construct this hash first.
    my($lookup) = {};
    my($m); # to iterate along the traveller entries.
    my($ind); # the sort index.


    if ($travorder) {
        # We have to pre-sort the traveller order
        # because we want it sorted by the north pair number.
        $move = [ sort({$a->[0] <=> $b->[0]} @$move) ];
    }

    $ind = 0;
    foreach $m (@$move) {
        $lookup->{$m->[0]} = $ind;
        $ind++;
    }
    my($rec) =
      {
       move => $move,
       lookup => $lookup,
      };

    for ($bn = $low; $bn <= $high; $bn++) {
        $ref->{$bn} = $rec;
    }
}

sub boardmove
{
    # given the data from a traveller entry, construct the
    # array.
    my($self) = shift();
    my($td) = @_;
    my($k, $v);
    my($list);
    my($key);

    $list = [];
    foreach $k (@$td) {
        push(@$list, [ $k->n(), $k->e() ]);
    }
    return ($list);

=for comment

    $list = {};
    foreach $k (@$td) {
        $key = $k->n() . "-" . $k->e();
        $list->{$key} = [$k->n(), $k->e()];
    }
    return ($list);

=cut

}

# Given a traveller, return the next pairs
sub freepair
{
    my($self) = shift();
    my($travs, $move) = @_;
    my($k);
    my(@keys);
    my($trav);

    # Covert the travellers array
    # into a hash;
    my($lookup) = {};
    foreach $trav (@$travs) {
        $lookup->{$trav->n()} = 1;
    }
    foreach $k (@{$move->{move}}) {
        if (exists($lookup->{$k->[0]})) {
            next;
        }
        return ("$k->[0] $k->[1] ");
    }
    return ("");
}

1;

