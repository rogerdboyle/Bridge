#######################
package Sbplayer;
#######################


use strict;
use warnings;

use IO::File;
use Sbplayerent;

our($magic) = "player.txt";

sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    $self->{recs} = [];
    $self->{lookup} = {};
    $self->{full_lookup} = {};
    return $self;
}

sub load
{
    my($self) = shift();
    my($fname) = @_;
    my($fh) = IO::File->new();

    if (!$fname) {
        $fname = $magic;
    }

    if (!$fh->open($magic, "<")) {
        die("Failed to open $magic for reading $!\n");
    }
    my($csv) = Text::CSV->new(
     {
      sep_char => ",",
      quote_char => '"',
     });
    $csv->eol("\n");
    my($row);
    my($recs) = $self->{recs};
    my($snamelook) = $self->{lookup};
    my($full) = $self->{full_lookup};
    while ($row = $csv->getline($fh)) {
        next if scalar(@$row) != 25;
        next if $row->[0] eq "F" && $row->[1] eq "S";
        my($ent) = Sbplayerent->new($row);
        push(@$recs, $row);
        # take the surname.
        my($surname) = $ent->key();
        my($fkey) = $ent->fullkey();
        my($ref);
        if (exists($snamelook->{$surname})) {
            $ref = $snamelook->{$surname};
        } else {
            $ref = [];
            $snamelook->{$surname} = $ref;
        }
        push(@$ref, $ent);

        if (exists($full->{$fkey})) {
            $ref = $full->{$fkey};
        } else {
            $ref = [];
            $snamelook->{$fkey} = $ref;
        }
        push(@$ref, $ent);
    }
}

sub lookup
{
    my($self) = shift();
    return $self->{lookup};
}

sub full_lookup
{
    my($self) = shift();
    return $self->{full_lookup};
}

sub recs
{
    my($self) = shift();
    return $self->{recs};
}
1;

