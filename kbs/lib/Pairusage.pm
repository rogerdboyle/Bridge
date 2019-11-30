# $Id: Pairusage.pm 670 2011-03-04 08:39:52Z paulh $

# Copyright (c) 2007 Paul Haffenden. All rights reserved.

# Record the number of times a pair has played NS or EW.
# Once all the pair data has been processed, we can call
# process() to calculate the number of winners and the pair
# split.

##################
package Pairusage;
##################

use strict;
use warnings;


sub new
{
    my($class) = shift();
    my($self) = {};
    # The pair map, indexed by the pairnumber.
    $self->{map} = {};
    $self->{opp} = {}; # number of times the same oppenents play
                       # each other.
    bless($self, $class);
    return ($self);
}

# Record which way this pair number, $pn, played.
# If $ns is set, then they played ns, else ew.
sub set
{
    my($self) = shift();
    my($ns, $ew) = @_;
    my($map) = $self->{map};

    if (exists($map->{$ns})) {
        $map->{$ns}->[0]++;
    } else {
        $map->{$ns} = [1, 0];
    }

    if (exists($map->{$ew})) {
        $map->{$ew}->[1]++;
    } else {
        $map->{$ew} = [ 0, 1 ];
    }

    #
    my($key);
    my($opp) = $self->{opp};

    if ($ns < $ew) {
        $key = $ns . "-" . $ew;
    } else {
        $key = $ew . "-" . $ns;
    }
    if (exists($opp->{$key})) {
        $opp->{$key}++;
    } else {
        $opp->{$key} = 1;
    }
}


# Take the pu, pair usage hash, generated for us when
# examining the results. (Each key in the hash contains
# an array reference. The first contains the number of
# times this pair played NS, and the second the number of
# times played EW.) We return a hash ref. For a two
# winner movement it contains two elements, the first of
# all the NS pairs, the second, all the EW pairs.
# For a single winner, return all the pairs.
# The pair numbers are sorted in ascending order.

sub process
{
    my($self) = shift();
    my($bpr) = @_;  # boards per round

    my($opp) = $self->{opp};
    my($keys, $count);


    while (($keys, $count) = each(%$opp)) {
        if ($count && ($count > $bpr)) {
            die("The pairs $keys have played each other, and more than ",
                "$bpr times (actual $count)\n");
        }
    }

    my($map) = $self->{map};
    my($reta) = [];
    # north south only pairs
    my($nsa) = [];
    # east west only pairs
    my($ewa) = [];
    # all pairs
    my($all) = [];
    my($pn, $usage);
    while (($pn, $usage) = each(%$map)) {
        if ($usage->[0] && $usage->[1]) {
            # played both ways
            push(@$all, $pn);
        } elsif ($usage->[0]) {
            push(@$nsa, $pn);
        } elsif ($usage->[1]) {
            push(@$ewa, $pn);
        } else {
            die("The pair $pn does not appear to have played!\n");
        }
    }
    if (scalar(@$all)) {
        # We do allow a mixure here, i.e. a pair
        # that plays as both N/S and E/W and a pair
        # that plays in one position.
        if (scalar(@$nsa)) {
            push(@$all, @$nsa);
        }
        if (scalar(@$ewa)) {
            push(@$all, @$ewa);
        }
        $all = [ sort({$a <=> $b} @$all) ];
        push(@$reta, $all);
    } else {
        $nsa = [ sort({$a <=> $b} @$nsa) ];
        $ewa = [ sort({$a <=> $b} @$ewa) ];
        push(@$reta, $nsa);
        push(@$reta, $ewa);
    }
    $self->{info} = $reta;
}

# Return either 1 or 2.
sub numberofwinners
{
    my($self) = @_;
    if (!exists($self->{info})) {
        die("process method has not been called to calculate winner number\n");
    }
    return (scalar(@{$self->{info}}));
}

# returns an array ref of the north/south pairs
# sorted in ascending order.
sub nspairs
{
    my($self) = @_;
    if (!exists($self->{info})) {
        die("process method has not been called to calculate winner number\n");
    }
    my($info) = $self->{info};
    if (scalar(@$info) == 1) {
        die("We only have one winner\n");
    }
    return ($info->[0]);
}

# returns an array ref of the east/west pairs
# sorted in ascending order.
sub ewpairs
{
    my($self) = @_;
    if (!exists($self->{info})) {
        die("process method has not been called to calculate winner number\n");
    }
    my($info) = $self->{info};
    if (scalar(@$info) == 1) {
        die("We only have one winner\n");
    }
    return ($info->[1]);
}

# returns all the pairs in ascending order.
sub allpairs
{
    my($self) = @_;
    if (!exists($self->{info})) {
        die("process method has not been called to calculate winner number\n");
    }
    my($info) = $self->{info};
    if (scalar(@$info) == 2) {
        die("We only two winners\n");
    }
    return ($info->[0]);
}

# Which way did this pair play?
# (Can only be called for two winner events)
sub playedns
{
    my($self) = shift();
    my($pn) = @_;
    if (!exists($self->{info})) {
        die("process method has not been called to calculate winner number\n");
    }
    if (scalar(@{$self->{info}}) == 1) {
        die("Only one winner\n");
    }
    my($map) = $self->{map};
    if ($map->{$pn}->[0]) {
        return (1);
    }
    return (0);
}

# Find the minimum number of boards played
sub minboardsplayed
{
    my($self) = shift();
    my($low) = undef();
    my($map) = $self->{map};
    my($pn, $ar);

    while (($pn, $ar) = each(%$map)) {
        my($sum) = $ar->[0] + $ar->[1];
        if (defined($low)) {
            if ($sum < $low) {
                $low = $sum;
            }
        } else {
            $low = $sum;
        }
    }
    return $low;
}


1;
