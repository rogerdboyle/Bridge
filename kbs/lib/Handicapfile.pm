use strict;
use warnings;

#####################
package Handicapfile;
#####################
use JSON;
use IO::File;
use Math::BigRat;

sub new
{
    my($class) = shift();
    my($self) = {};
    $self->{hand} = {};
    bless($self, $class);
    return $self;
}


sub qualify
{
    my($self) = shift();
    my($id) = @_;

    if (!exists($self->{hand}->{$id})) {
        return 0;
    }
    if (scalar(@{$self->{hand}->{$id}}) < 12) {
        return 0;
    }
    return 1;
}

sub qualifyboth
{
    my($self) = shift();
    my(@p) = @_;
    my($p);

    foreach $p (@p) {
        if (!$self->qualify($p)) {
            return 0;
        }
    }
    return 1;
}

sub handicap
{
    my($self) = shift();
    my($id) = @_;

    my($hand) = $self->{hand};
    my($val);

    $val = $hand->{$id};


    my($v);
    my($tot) = Math::BigRat->new(0);
    foreach $v (@$val) {
        $tot += Math::BigRat->new($v->[0]) * 100;
    }
    my($min) = 12;
    my($count) = scalar(@$val);
    if ($count < $min) {
        $tot += Math::BigRat->new(5000) * ($min - $count);
        $count = $min;
    }
    return $tot / $count;
}

sub save
{
    my($self) = shift();
    my($fname) = @_;

    my($tosave) = {};
    my($key, $val);
    my($hand) = $self->{hand};

    my($fh) = IO::File->new();
    if (!$fh->open($fname, ">")) {
        die("Failed to open $fname for writing $!\n");
    }
    my($json) = JSON->new();
    $json->pretty();
    $fh->print($json->encode($hand));
}

sub load
{
    my($self) = shift();
    my($fname) = @_;
    my($fh) = IO::File->new();

    if (!$fh->open($fname, "<")) {
        die("Failed to open $fname for reading $!\n");
    }
    my($jdata) = JSON->new()->decode(join("", $fh->getlines()));
    $self->{hand} = $jdata;
}

sub sethand
{
    my($self) = shift;
    my($hand) = @_;
    $self->{hand} = $hand;
}


sub gethand
{
    my($self) = shift;
    return $self->{hand};
}

sub count
{
    my($self) = shift();
    my($id) = @_;
    return scalar(@{$self->{hand}->{$id}});
}

# return the handicap adjustment of a pair.
sub adj
{
    my($self) = shift();
    my(@ids) = @_;

    my($tot) = Math::BigRat->new(0);
    my($i);

    foreach $i (@ids) {
        if (exists($self->{hand}->{$i})) {
            $tot += $self->handicap($i);
        } else {
            $tot += 5000;
        }
    }
    $tot /= 2;
    my($ipart) = $tot->as_number();
    my($frac) = $tot - $ipart;
    # Round up
    if ($frac >= Math::BigRat->new("1/2")) {
        $ipart += 1;
    }
    return ($ipart - 5000) * -1;
}

sub entrylist
{
    my($self) = shift();
    my($id) = @_;
    if (exists($self->{hand}->{$id})) {
        return ($self->{hand}->{$id});
    }
    return ([]);
}

1;
