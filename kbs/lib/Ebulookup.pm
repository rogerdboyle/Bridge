##################
package Ebulookup;
##################


use strict;
use warnings;

use Text::CSV;
use IO::File;
use Ebufile;
use Ebukeys;

our($magic) = "C:/temp/cn_r6eqzmi0zq.csv";
our($magic2) = "/tmp/cn_r6eqzmi0zq.csv";
sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    $self->{recs} = [];
    $self->{lookup} = {};
    $self->{ebu_lookup} = {};
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
        if (!$fh->open($magic2, "<")) {
            die("Failed to open $magic or magic2 for reading $!\n");
        }
    }
    my($csv) = Text::CSV->new(
     {
      binary => 1, sep_char => ",",
      quote_char => '"',
      escape_char => '"'
     });
    my($row);
    my($recs) = $self->{recs};
    my($snamelook) = $self->{lookup};
    my($full) = $self->{full_lookup};
    my($elook) = $self->{ebu_lookup};
    while ($row = $csv->getline($fh)) {
        my($ent) = Ebufile->new($row);
        push(@$recs, $row);
        # take the surname.
        my($surname) = Ebukeys->key($ent->sname());
        my($fkey) = Ebukeys->full_key($ent->sname(), $ent->cname());
        my($ekey) = Ebukeys->ebu_key($ent->ebuno());
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
            $full->{$fkey} = $ref;
        }
        push(@$ref, $ent);

        if ($ekey) {
            if (exists($elook->{$ekey})) {
                die("Duplicate ebu number $ekey\n");
            } else {
                $elook->{$ekey} = $ent;
            }
        }
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

sub ebu_lookup
{
    my($self) = shift();
    return $self->{ebu_lookup};
}


1;
