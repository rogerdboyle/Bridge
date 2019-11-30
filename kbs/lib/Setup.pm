# $Id: Setup.pm 1459 2015-09-14 14:33:01Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.
#
# An object to control the setup data
#

##############
package Setup;
##############

use strict;
use warnings;
use IO::File;
use JSON;
use Conf;
use Sql;


our($fname) = "setup.txt";

sub new
{
    my($class) = @_;
    my($self) = {};

    bless($self, $class);
    return($self);
}

sub nob
{
    my($self) = shift();
    my($arg) = @_;

    if (defined($arg)) {
        $self->{nob} = $arg;
    }
    return ($self->{nob});
}

sub range
{
    my($self) = shift();
    my($arg) = @_;

    if (defined($arg)) {
        $self->{range} = $arg;
        $self->doranges();
    }

    if (wantarray()) {
        return (@{$self->{ranges}});
    } else {
        return ($self->{range});
    }
}

sub bpr
{
      my($self) = shift();
      my($arg) = @_;

      if (defined($arg)) {
          $self->{bpr} = $arg;
      }
      return ($self->{bpr});
}

sub doranges
{
    my($self) = shift();
    my($seen) = {};
    my(@ranges);
    my($low, $high, $i);
    my($it);

    @ranges = split(m/,/, $self->{range});
    foreach $it (@ranges) {
        ($low, $high) = $it =~ m/(\d+)-(\d+)/;
        if (defined($high)) {
            if ($low > $high) {
                die("first digit must be less then the second\n");
            }
        }
        for ($i = $low; $i <= $high; $i++) {
            if (exists($seen->{$i})) {
                die("Duplicate ($i)\n");
            }
            $seen->{$i} = 1;
        }
    }
    $self->{ranges} = [ sort({$a <=> $b} keys(%$seen)) ];
}

sub load
{
    my($self) = shift();
    my($dir) = @_;
    my($movedata);
    my($json, $jstr, $jdata);

    $jstr = Sql->load(Sql::SETUP, $dir);

    if (!defined($jstr)) {
        die("Failed to load the setup data\n");
    }

    $json = JSON->new();
    $jdata = $json->decode($jstr);
    $self->{bpr} = $jdata->{bpr};
    $self->{nob} = $jdata->{nob};
    $self->{range} = $jdata->{range};
    $self->{rawmoves} = $jdata->{moves};
    $self->{tables} = $jdata->{tables};
    $self->{missing_pair} = $jdata->{missing_pair};
    $self->{bmate} = $jdata->{bmate};
    $self->{winners} = $jdata->{winners};

    if (exists($jdata->{moves})) {
        $movedata = $jdata->{moves};
    } else {
        $movedata = [];
    }
    $self->doranges();
    if (defined($movedata)) {
        $self->domovectl($movedata);
    }
}

sub oldload
{
    my($self) = shift();
    my($dir) = @_;

    my($line);
    my($name);
    my($fh);
    my($key, $val);
    my(@movedata);

    $fh = IO::File->new();
    $name = "$Conf::resdir/$dir/$fname";
    if (!$fh->open($name, "<:crlf")) {
        die("Can't read $name $!\n");
    }
    while ($line = $fh->getline()) {
        if ($line !~ m/=/) {
            # The board data does not contain the "="
            chomp($line);
            push(@movedata, $line);
        } else {
            ($key, $val) = $line =~ m/^([^=]*)=(\S+)/;
            $self->{$key} = $val;
        }
    }
    $self->{rawmoves} = \@movedata;
    $self->doranges();
    $self->domovectl(\@movedata);
    $fh->close();
}

#  take the data from the setup file, and
# construct a movectl like object;
sub domovectl
{
    my($self) = shift();
    my($dr) = @_;
    my($moves);
    my($l);
    my($i);

    if (scalar(@$dr) == 0) {
        return;
    }

    $moves = [];
    foreach $l (@$dr) {
        my($ele);
        my(@items);

        $ele = [];
        @items = split(m/,/, $l);
        if ((scalar(@items) % 2) != 0) {
            die("I have an odd number of entries in the setup file\n");
        }
        for ($i = 0; $i < @items; $i+= 2) {
            push(@$ele, [ $items[$i] , $items[$i + 1] ]);
        }
        push(@$moves, $ele);
    }
    $self->{moves} = $moves;
}

sub tables
{
    my($self) = shift;
    my($tbls) = @_;
    if ($tbls) {
        $self->{tables} = $tbls;
    }
    return $self->{tables};
}

sub save
{
    my($self) = shift();
    my($dir) = @_;

    my($ret);
    my($jstr);
    my($jdata);
    my($json);

    $jdata = {};
    $jdata->{nob} = $self->{nob};
    $jdata->{range} = $self->{range};
    $jdata->{bpr} = $self->{bpr};
    $jdata->{moves} = $self->{rawmoves};
    $jdata->{tables} = $self->{tables};
    $jdata->{missing_pair} = $self->{missing_pair};
    $jdata->{bmate} = $self->{bmate};
    $jdata->{winners} = $self->{winners};

    $json = JSON->new();
    $json->canonical(1);
    $json->pretty();

    $jstr = $json->encode($jdata);

    $ret = Sql->save(Sql::SETUP, $dir, $jstr);
    if (!defined($ret)) {
        die("Failed to save the setup data\n");
    }
}

sub oldsave
{
    my($self) = shift();
    my($dir) = @_;
    my($fh);
    my($name);

    $fh = IO::File->new();
    $name = "$Conf::resdir/$dir/$fname";
    if (!$fh->open($name, ">")) {
        die("Can't open $name $!\n");
    }
    $fh->print("nob=$self->{nob}\n",
      "range=$self->{range}\n",
      "bpr=$self->{bpr}\n");
    if ($self->{moves}) {
        $fh->print(join("\n", @{$self->{moves}}), "\n");
    }
    $fh->close();
}


sub moves
{
      my($self) = shift();
      my($m) = @_;
      $self->{rawmoves} = $m
}

sub remove
{
    my($class) = shift();
    my($dir) = @_;
    my($name) = "$Conf::resdir/$dir/$fname";
    unlink($name);
}

sub has_setup
{
    my($class) = shift();
    my($dir) = @_;
    my($name) = "$Conf::resdir/$dir/$fname";

    if (stat($name)) {
        return 1;
    }
    return 0;
}

sub winners
{
    my($self) = shift();
    my($wins) = @_;

    if (defined($wins)) {
        $self->{winners} = $wins;
    }
    return $self->{winners};
}

sub missing_pair
{
    my($self) = shift();
    my($mp) = @_;

    if (defined($mp)) {
        $self->{missing_pair} = $mp;
    }
    return $self->{missing_pair};
}
sub bmate
{
    my($self) = shift();
    my($epair) = @_;

    if (defined($epair)) {
        $self->{bmate} = $epair;
    }
    return $self->{bmate};
}
1;
