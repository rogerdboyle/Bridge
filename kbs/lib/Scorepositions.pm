#######################
package Scorepositions;
#######################

# Code to save and load the score after it has been calculated
# so we can perform analysis of multiple results.
# $Id: Scorepositions.pm 1615 2016-08-18 19:59:03Z phaff $
use strict;
use warnings;
use Conf;
use IO::File;
use Data::Dumper;
use Pairmap;
use JSON;
use Sql;

use constant SCOREFILE => "score.txt";


sub new
{
    my($class) = shift();
    my($self) = {};
    $self->{maxmp} = 0; # The maximum masterpoints for this match
    $self->{array} = [];
    bless($self, $class);
    return ($self);
}

sub addentry
{
    my($self) = shift();
    my($ind, $entry) = @_;

    my($push);
    if (!defined($self->{array}->[$ind])) {
        $push = [];
        $self->{array}->[$ind] = $push;
    } else {
        $push = $self->{array}->[$ind];
    }
    push(@$push, $entry);
}

sub save
{
    my($self) = shift();
    my($dir) = @_;
    my($ret);

    my($json) = JSON->new();
    $json->canonical(1);
    $json->pretty();

    my($bl) = {};
    # This is so we don't need any fancy options
    # to JSON to encode the data. It doesn't like
    # blessed objects.
    $bl->{array} = $self->{array};
    $bl->{maxmp} = $self->{maxmp};
    $ret = Sql->save(Sql::SCORE, $dir, $json->encode($bl));
    if (!defined($ret)) {
        die("Failed to save score file\n");
    }
}

sub load
{
    my($self) = shift();
    my($dir) = @_;
    my($jdata);

    my($json) = JSON->new();
    my($jstr);

    $jstr = Sql->load(Sql::SCORE, $dir);
    if (!defined($jstr)) {
        die("Failed to load score file $dir\n");
    }
    $jdata = $json->decode($jstr);
    %$self = %$jdata;
}

sub oldload
{
    my($self) = shift();
    my($dir) = @_;
    my($VAR1);
    my($infile) = SCOREFILE;
    my($datastr);
    my($fh) = IO::File->new();

    $infile = "$Conf::resdir/$dir/$infile";
    if (!$fh->open($infile, "<")) {
        die("I've failed to open the scorefile ($infile)\n");
    }
    $fh->sysread($datastr, 40960);
    $fh->close();
    eval($datastr);
    %$self = %$VAR1;
}

sub fixpairs
{
    my($self) = shift();
    my($dir) = @_;

    my($outer);
    my($inner);
    my($id0, $id1);

    foreach $outer (@{$self->{array}}) {
        foreach $inner (@$outer) {
            my($gid) = $inner->{pair};
            if (!defined($gid)) {
                print("Anon pairs for $dir\n");
                return;
            }
            if ($gid =~ m/_/) {
                ($id0, $id1) = $gid =~ m/([^_]*)_(.*)/;
            } else {
                $id0 = int($gid / 1000);
                $id1 = int($gid % 1000);
            }
            if ($id0 < $id1) {
                $inner->{pair} = "${id0}_$id1";
            } else {
                $inner->{pair} = "${id1}_$id0";
            }
        }
    }
}

# Given a handicap file, rescore the evert. We return a
# new object on success.
sub rescore
{
    my($self) = shift();
    my($cap) = @_;

    my($newsp) = Scorepositions->new();
    my($outer, $inner);
    my($ind) = 0;
    foreach $outer (@{$self->{array}}) {
        foreach $inner (@$outer) {
            my($newent);
            %$newent = %$inner;
            my($per) = Math::BigRat->new($newent->{percent}) * 100;
            if (defined($cap)) {
                $newent->{oldpos} = $newent->{pos};
                $newent->{oldpercent} = $newent->{percent};
                my(@p) = Pairmap->break($newent->{pair});
                my($adj) = $cap->adj(@p);
                $per += $adj;
                $newent->{adj} = sprintf("%.02f", Math::BigRat->new($adj) / 100);
                $newent->{qualify} = $cap->qualifyboth(@p);
            }
            $newent->{percent} = sprintf("%.02f", $per / 100);
            $newsp->addentry($ind, $newent);
        }
        $ind++;

    }

    foreach $outer (@{$newsp->{array}}) {
        $outer = [ sort ({$b->{percent} <=> $a->{percent}} @$outer) ];
        my($lastpos);
        my($pos) = 1;
        foreach $inner (@$outer) {
            if (defined($lastpos) && ($inner->{percent} == $lastpos->{percent})) {
                if (!($lastpos =~ m/=/)) {
                    $lastpos->{pos} .= "=";
                }
                $inner->{pos} = $lastpos->{pos};
            } else {
                $inner->{pos} = $pos;
                $lastpos = $inner;
            }
            $pos++;
        }
    }
    return $newsp;
}

# Do we have any masterpoints assigned.
sub havemasters
{
    my($self) = shift();
    my($wins) = $self->{array};
    my($out, $in);
    my($mp);

    foreach $out (@$wins) {
        foreach $in (@$out) {
            if ($in->{master} > 0) {
                return 1;
            }
        }
    }
    return (0);
}

sub domasters
{
    my($self) = shift();
    my($trs) = @_;

    # Calculate the number of pairs.
    my($wins) = $self->{array};
    my($out, $in);
    my($npairs) = 0;

    foreach $out (@$wins) {
        $npairs += scalar(@$out);
    }
    print("I have $npairs pairs playing in total\n");

    # Find the minimun number of boards each pair has played.
    my($pc) = {}; # The pair count, indexed by pair number.
    my($res);
    my($low);
    if (defined($trs)) {
        my($boards) = $trs;
        my($top) = scalar(@$boards);
        print("I have $top boards\n");
        my($bno);

        foreach $bno (@$boards) {

            foreach $res (@$bno) {
                $pc->{$res->[0]}++;
                $pc->{$res->[1]}++;
            }
        }
        $low = 5000;
        foreach $res (values(%$pc)) {
            if ($res < $low) {
                $low = $res;
            }
        }
        print("Lowest number of boards played is $low\n");
    } else {
        $low = 18;
    }

    my(@totalmp) = Masterpoints::mppoints($low, $npairs, scalar(@$wins) == 2);
    $self->{maxmp} = $totalmp[0];
    if (scalar(@totalmp) == 0) {
        return;
    }
    my($pairs);
    foreach $pairs (@$wins) {
        my($pn);
        my($mp);
        $mp = [];
        for ($pn = 0; $pn < @$pairs; $pn++) {
            if (($pn > 0) &&
                (($pairs->[$pn]->{percent} == $pairs->[$pn - 1]->{percent}))) {
                push(@{$mp->[-1]}, $pn);
            } else {
                push(@$mp, [ $pn ])
            }
        }
        my($ind) = 0;
        my(@mpawards) = @totalmp;
        while (@mpawards) {
            my($num);
            my($tot);
            my($i);
            my($n);
            # Number of pairs that have this award.
            $num = scalar(@{$mp->[$ind]});
            $i = $num;
            $tot = 0;
            while ($i-- > 0) {
                $n = shift(@mpawards);
                if (defined($n)) {
                    $tot += $n;
                }
            }
            $n = int($tot / $num);
            # The minimum number of master points awarded is 6.
            # enforce this here.
            if ($n < 6) {
                $n = 6;
            }
            foreach $pn (@{$mp->[$ind]}) {
                $pairs->[$pn]->{master} = $n;
            }
            $ind++;
        }
    }
}

# Work out how many pairs/ hence tables and if we have a two winnner
# movmeent adjust the ew parts.
sub pair_refactor
{
    my($self) = shift();
    my($trs) = @_;
    my($out, $in);
    my($wins) = $self->{array};
    if (scalar(@$wins) == 1) {
        # Single winner, so the pairs must already be unique,
        # nothing to do.
        print("Single winner movement\n");
        return;
    }
    my($npairs, $ewadj);
    $npairs = 0;
    foreach $out (@$wins) {
        $npairs += scalar(@$out);
    }
    if ($npairs > 20) {
        $ewadj = 20;
    } else {
        $ewadj = 10;
    }
    print("Number of pairs $npairs adjustment is $ewadj\n");

    foreach $out (@{$wins->[1]}) {
        $out->{matchpair} += $ewadj;
    }
    # Now the travellers.
    foreach $out (@$trs) {
        foreach $in (@$out) {
            $in->[1] += $ewadj;
        }
    }
}

1;
