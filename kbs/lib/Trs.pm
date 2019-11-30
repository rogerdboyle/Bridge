# $Id: Trs.pm 1460 2015-09-14 18:48:53Z phaff $
# Copyright (c) 2010 Paul Haffenden. All rights reserved.

# This is the object that stores all the results for all the
# boards. The boards are accessed by calling the 'boards'
# method, this returns an array ref. Board 1 is found
# at etc 0 etc. Each entry in the array is another
# array ref of traveller entries. (A Result object)
# The ordering in this array is determined by trav.pl
# This module dees NOT sort the entries.

############
package Trs;
############


use strict;
use warnings;

use IO::File;
use JSON;
use Conf;
use Board;
use Result;
use Sql;

our($rev) = undef();
our($fname) = "tr.db";

sub new
{
    my($class) = shift();
    my($self) = {};

    $self->{boards} = [];
    bless($self, $class);
    return ($self);
}

sub load
{
    my($self) = shift();
    my($dir, $editor) = @_;

    # When editor is set we want to include the "Not Pleyed" entries,
    # which are makred by a '#' character. Otherwise we discard them.

    my(@vul);
    my($res);
    my($err);


    $self->{editor} = $editor;
    # It doesn't have to exist.
    my($json) = JSON->new();
    my($jstr, $jdata);

    $jstr = Sql->load(Sql::TRAV, $dir);
    if (!defined($jstr)) {
        return;
    }
    $jdata = $json->decode($jstr);
    $rev = $jdata->{rev};
    my($out, $val, $bn, $ns);
    my($checkload) = {};

    foreach $out (@{$jdata->{boards}}) {
        $bn = $out->[0];
        @vul = Board->vul($bn);

        foreach $val (@{$out->[1]}) {
            $res = Result->new($val, @vul, \$err);
            if (!defined($res)) {
                die($err, "\n");
            }
            # If we are not in editor mode, ignore the 'ignored'
            # entries.
            next if !$editor && $res->ignored();
            $ns = $res->n();
            if (exists($checkload->{$bn}->{$ns})) {
                die("Attempting to load a duplicate entry for board $bn ",
                    "with North/South pair $ns\n");
            } else {
                $checkload->{$bn}->{$ns} = 1;
            }
            push(@{$self->{boards}->[$bn - 1]}, $res);
        }
    }
}

sub oldload
{
    my($self) = shift();
    my($dir, $editor) = @_;

    # When editor is set we want to include the "Not Pleyed" entries,
    # which are makred by a '#' character. Otherwise we discard them.

    my($name);
    my($fh);
    my($line);
    my(@vul);
    my($res);
    my($err);


    $name = "$Conf::resdir/$dir/$fname";
    $fh = IO::File->new();
    $self->{editor} = $editor;
    # It doesn't have to exist.
    if (!$fh->open($name, "<:crlf")) {
        return;
    }
    my($lt, $val, $bn, $ns);
    my($lc) = 0;
    my($checkload) = {};
    # So we can check in the save routine.

    while ($line = $fh->getline()) {
        $lc++;
        next if $line =~ m/^\s*$/; # skip blank lines.
        ($lt, $val) = $line =~ m/^([^=]*)=(.*)/;
        if (!defined($lt)) {
            die("Parse failed of line number $lc of the traveller ",
                "data file\n");
        }
        chomp($val);
        if ($lt eq "board") {
            $bn = $val;
        } elsif ($lt eq "rev") {
            $rev = $val;
        } else {
            if (!defined($bn)) {
                die("Attempting to add entry with boardnumber defined\n");
            }
            @vul = Board->vul($bn);
            $res = Result->new($val, @vul, \$err);
            if (!defined($res)) {
                die($err, "\n");
            }
            # If we are not in editor mode, ignore the 'ignored'
            # entries.
            next if !$editor && $res->ignored();
            $ns = $res->n();
            if (exists($checkload->{$bn}->{$ns})) {
                die("Attempting to load a duplicate entry for board $bn ",
                    "with North/South pair $ns\n");
            } else {
                $checkload->{$bn}->{$ns} = 1;
            }
            push(@{$self->{boards}->[$bn - 1]}, $res);
        }
    }
}

sub oldsave
{
    my($self) = shift();
    my($dir) = @_;

    my(@results);
    my($bd);
    my($r);
    my($fh);
    my($name);

    if (!defined($dir)) {
        die("Trs::save missing directory argument\n");
    }

    if (!$self->{editor}) {
        die("May not save a traveller file if it has been ",
            "opened in 'readonly' mode\n");
    }

    $name = "$Conf::resdir/$dir/$fname";
    $fh = IO::File->new();
    if (!$fh->open($name, ">")) {
        die("Unable to open $fname for writing $!\n");
    }

    my($top) = scalar(@{$self->{boards}});
    $fh->print("rev=$rev\n");
    for ($bd = 1; $bd <= $top; $bd++) {
        if (defined($self->{boards}->[$bd - 1])) {
            my($ha);
            $fh->print("board=$bd\n");
            $ha = $self->{boards}->[$bd - 1];
            foreach $r (@$ha) {
                $fh->print("instr=$r->{instr}\n");
            }
        }
    }
    $fh->close();
}
sub save
{
    my($self) = shift();
    my($dir) = @_;

    my($bd);
    my($r);
    my($ret);

    if (!defined($dir)) {
        die("Trs::save missing directory argument\n");
    }

    if (!$self->{editor}) {
        die("May not save a traveller file if it has been ",
            "opened in 'readonly' mode\n");
    }

    my($jdata); # the hash we will convert to JSON,
    # and then dump to the output file.

    $jdata = {};
    $jdata->{rev} = $rev;
    my($boards) = [];
    $jdata->{boards} = $boards;

    my($top) = scalar(@{$self->{boards}});
    for ($bd = 1; $bd <= $top; $bd++) {
        if (defined($self->{boards}->[$bd - 1])) {
            my($ha);
            my($subboard) = [];
            $ha = $self->{boards}->[$bd - 1];
            foreach $r (@$ha) {
                push(@$subboard, $r->{instr});
            }
            push(@$boards, [ $bd, $subboard ]);
        }
    }
    # Convert and write.
    my($json) = JSON->new();
    $json->canonical(1);
    $json->pretty();
    $ret = Sql->save(Sql::TRAV, $dir, $json->encode($jdata));
    if (!defined($ret)) {
        die("Failed to save the trav record $dir\n");
    }
}

sub boards
{
    my($self) = shift();
    return ($self->{boards});
}

# Add or replace a result, given a board numbers and Result
# reference
sub add_result
{
    my($self) = shift();
    my($bno, $res, $err_ref) = @_;

    my($subboard) = $self->{boards}->[$bno - 1];
    if (!defined($subboard)) {
        $subboard = [];
    }

    my($n, $e);
    $n = $res->n();
    $e = $res->e();
    my($sub);
    my($newsub) = [];

    foreach $sub (@$subboard) {
        if (($sub->n() == $n) ||
            ($sub->e() == $n) ||
            ($sub->n() == $e) ||
            ($sub->e() == $e)) {
            if (!(($sub->n() == $n) && ($sub->e() == $e))) {
                # Delete the previous entries, but note it
                # if requested.
                if (defined($err_ref)) {
                    push(@$err_ref, "" . $sub->n() . " " . $sub->e());
                }
            }
        } else {
            push(@$newsub, $sub);
        }
    }
    # Add the new entry, having deleted any pair number clashes.
    push(@$newsub, $res);
    $self->{boards}->[$bno - 1] = $newsub;
}

sub count
{
    my($self) = shift();
    my($boards) = $self->{boards};
    my($count) = 0;
    my($b, $res);

    foreach $b (@$boards) {
        if (defined($b)) {
            foreach $res (@$b) {
                if (defined($res)) {
                    $count++;
                }
            }
        }
    }
    return $count;
}
1;
