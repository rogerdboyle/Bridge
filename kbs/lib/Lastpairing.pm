

# $Id: Lastpairing.pm 1307 2014-06-23 11:17:42Z paulh $

# Copyright (c) 2011 Paul Haffenden. All rights reserved.

####################
package Lastpairing;
####################

# Remember the last person someone played with

use strict;
use warnings;
use IO::File;
use JSON;
use Conf;
use Single;

sub new
{
    my($class) = shift();
    my($self) = {};

    $self = {};
    bless($self, $class);
    return $self;
}

sub load
{
    my($self) = shift();
    my($fname) = @_;

    # Load up the json format file
    my($fh) = IO::File->new();
    if (!$fh->open($fname, "<")) {
        $self->{map} = {};
        return;
    }
    my($datastr);
    $datastr = join("", $fh->getlines());
    $fh->close();
    my($json);
    $json = JSON->new();
    my($oldmap, $map);
    $oldmap = $json->decode($datastr);
    my($key, $val);
    $map = {};
    while (($key, $val) = each(%$oldmap)) {
        $map->{$key} = Mapentry->new($val->[0], $val->[1]);
    }
    $self->{map} = $map;
}

# Return the structure that maps
sub map
{
    my($self) = shift();
    return $self->{map};
}

# Given the current pairmap from a 'pairmap'
# session, rewrite the {list} items to update the
# latest pairs.

sub merge
{
    my($self) = shift();
    my($pmap, $sdate) = @_;
    my($val);
    my($map) = $self->map();

    foreach $val (values(%$pmap)) {
        my($low, $high) = Single::classbreak($val);
        check_insert($map, $low, $high, $sdate);
        check_insert($map, $high, $low, $sdate);
    }
}

sub check_insert
{
    my($map, $key, $other, $date) = @_;
    if (!exists($map->{$key}) || ($date >= $map->{$key}->date())) {
        $map->{$key} = Mapentry->new($other, $date);
    }
}


sub save
{
    my($self) = shift();
    my($fname) = @_;

    my($fh) = IO::File->new();
    if (!$fh->open($fname, ">")) {
        die("Failed to open $fname for writing $!\n");
    }
    my($map) = $self->{map};
    my($json) = JSON->new();
    $json->canonical(1);
    $json->pretty();
    my($newmap) = {};
    my($key, $val);
    # Declass the map when we send it to the JSON encoder.
    while (($key, $val) = each(%$map)) {
        $newmap->{$key} = [ map { $_ + 0 } @$val ];
    }
    $fh->print($json->encode($newmap), "\n");
    $fh->close();
}

#################
package Mapentry;
#################

sub new
{
    my($class) = shift();
    my($gid, $date) = @_;
    my($self) = [$gid, $date];
    bless($self, $class);
    return $self;
}

sub other
{
    my($self) = shift();
    return $self->[0];
}

sub date
{
    my($self) = shift();
    return $self->[1];
}


1;

