# $Id: Pair.pm 1017 2013-01-13 11:53:02Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

#############
package Pair;
#############

use strict;
use warnings;
use Math::BigRat;

our($pairs);

# Reset the global pairs hash.
sub init
{
    $pairs = {};
}

sub new
{
    my($class) = shift();
    my($pn) = @_;
    my($self);

    if (!defined($pairs)) {
        $pairs = {};
    }
    if ($pn !~ m/\d+/) {
        die("Pair number not numeric $pn\n");
    }
    $self = {};
    bless($self, $class);
    if (exists($pairs->{$pn})) {
        die("Attempting to add Pair $pn twice\n");
    }
    # pn is this pairnumber
    $self->{pn} = $pn;
    # pts is the number of points scored by this pair
    $self->{pts} = Math::BigRat->new(0);
    # tpts is the total nuumber of possible points that could
    # be scored by this pair.
    $self->{tpts} = Math::BigRat->new(0);
    $pairs->{$pn} = $self;
    return ($self);
}

sub getpair
{
    my($class) = shift();
    my($pn) = @_;

    if (exists($pairs->{$pn})) {
        return ($pairs->{$pn});
    } else {
        return ($class->new($pn));
    }
}
sub add
{
    my($self) = shift();
    my($pts) = @_;

    $self->{pts} += $pts;
}

sub addtot
{
    my($self) = shift();
    my($pts) = @_;

    $self->{tpts} += $pts;
}


# We use the Pairusage object to split the pairs.
sub pairlist
{
    my($class) = shift();
    # takes the pair usage object.
    my($pu) = @_;

    my($ns) = [];
    my($ew) = [];

    if ($pu->numberofwinners() == 2) {
        my($where) = $ns;
        foreach my $pnl ($pu->nspairs(), $pu->ewpairs()) {
            foreach my $pn (@$pnl) {
                push(@$where, $pairs->{$pn});
            }
            $where = $ew;
        }
        return ($ns, $ew);
    } else {
        my($pnl) = $pu->allpairs();
        foreach my $pn (@$pnl) {
            push(@$ns, $pairs->{$pn});
        }
        return ($ns);
    }
}

# Just return all the known pairs.
sub pairs
{
    return (values(%$pairs));
}
1;
