# $Id: Pairmap.pm 1471 2015-10-09 05:45:56Z phaff $

# Copyright (c) 2007 Paul Haffenden. All rights reserved.

################
package Pairmap;
################

use strict;
use warnings;
use JSON;
use Conf;
use IO::File;
use Sql;

our($pname) = "pairmap.db";

# All things to do with the pairmap.
sub new
{
    my($class) = shift();

    my($self) = {};
    bless($self, $class);
    return ($self);
}

sub save
{
    my($self) = shift();
    my($dir) = @_;
    my($ret);
    my($key, @keys);

    my($jdata);
    my($json) = JSON->new();
    $json->canonical(1);
    $json->pretty();
    %$jdata = %$self;
    $ret = Sql->save(Sql::MAP, $dir, $json->encode($jdata));
    if (!defined($ret)) {
        die("Failed to load the map record $dir\n");
    }
}

sub add
{
    my($self) = shift();
    my($key, $val) = @_;

    if (exists($self->{$key})) {
        die("Duplicate key when adding a pair to the session ($key). Error in the movement file?\n");
    }
    $self->{$key} = $val;
}

sub addpair
{
    my($self) = shift();
    my($sessionpair, $p1, $p2) = @_;
    $self->{$sessionpair} = $self->normal($p1, $p2);
}

# A class method, split the pair input into
# the two global pair numbers.
sub break
{
    my($class) = shift();
    my($gid) = @_;
    my($id0, $id1);

    if ($gid =~ m/_/) {
        ($id0, $id1) = $gid =~ m/([^_]*)_(.*)/;
    }
    return ($id0, $id1);
}


# Generate a unique id for this pair.
# The old format used to be a single decimal digit,
# with the first number multiplied by 1000 and added
# to the second. The new format just puts a '_' between
# the digits, so we don't run into problem when we hit more
# than 999 in the contact.csv file.
sub normal
{
    my($self) = shift();
    my($id0, $id1) = @_;
    # Fixed alphabetical ordering, but what if the name name changes
    # in the contact csv file?
    # That is a problem.......
    if ($id0 < $id1) {
        return ("${id0}_$id1");
    } else {
        return ("${id1}_$id0");
    }
}


sub load
{
    my($self) = shift();
    my($dir) = @_;
    my($json);
    my($jstr);
    my($jdata);

    $jstr = Sql->load(Sql::MAP, $dir);
    if (!defined($jstr)) {
        return (0);
    }
    $json = JSON->new();
    $jdata = $json->decode($jstr);
    %$self = %$jdata;
    return (1);
}

sub oldload
{
    my($self) = shift();
    my($dir) = @_;
    my($fh);
    my($line);
    my($pn, $gid);
    my($fname) = "$Conf::resdir/$dir/$pname";
    $fh = IO::File->new();

    if (!$fh->open($fname, "<:crlf")) {
        return (0);
    }
    my($lc) = 0;
    while ($line = $fh->getline()) {
        $lc++;
        ($pn, $gid) = $line =~ m/([^=]+)=(\S*)/;
        if (!defined($pn)) {
            die("Failed to parse $fname line $lc\n");
        }
        my($low, $high);
        ($low, $high) = $gid =~ m/(\d+)_(\d+)/;
        if (!defined($low) || !defined($high)) {
            if (($low) = $gid =~ m/(\d+)/) {
                use integer;
                $high = $low % 1000;
                $low = $low / 1000;
                $gid = "${low}_$high";
            } else {
                die("The pair (gid) at line $lc has not parsed ($gid)\n");
            }
        }
        if ($low == $high) {
            die("The pair (gid) contains the same player number twice " .
                "at line $lc ($gid)\n");
        }
        # We always store them in low-high order....
        if ($high < $low) {
            $gid = "${high}_$low";
        }
        $self->{$pn} = $gid;
    }
    $fh->close();
    return (1);
}

# Count the number of players stored in the map.
sub count
{
    my($self) = shift();
    my(@vals) = values(%$self);
    my($count) = 0;
    my($val);
    foreach $val (@vals) {
        my(@d) = $self->break($val);
        foreach my $d (@d) {
            if ($d != 0) {
                $count++;
            }
        }
    }
    return $count;
}

1;
