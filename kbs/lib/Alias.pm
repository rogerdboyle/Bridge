# $Id$
# Copyright (c) 2012 Paul Haffenden. All rights reserved.

use strict;
use warnings;
use IO::File;

##############
package Alias;
##############
use Data::Dumper;

sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    $self->{map} = {};
    # The alias is keyed by the main name, and lists all
    # its alieses.
    $self->{alias} = {};
    return $self;
}


sub oldload
{
    my($self) = shift();
    my($fname) = @_;
    my($fh) = IO::File->new();
    my($line);

    if (!$fh->open($fname, "<")) {
        die("Failed to open $fname $!\n");
    }
    my($lineno) = 0;
    while ($line = $fh->getline()) {
        $lineno++;
        if ($line =~ m/^\s*#/) {
            next;
        }
        if ($line =~ m/^\s*$/) {
            next;
        }
        chomp($line);
        my(@arrow) = split(/<=/, $line, 2);
        if (scalar(@arrow) == 1) {
            die("Failed to parse line $lineno ($line)\n");
        }
        trim($arrow[0]);
        my(@vals) = split(m/,/, $arrow[1]);
        my($v);
        foreach $v (@vals) {
            trim($v);
            $self->{map}->{$v} = $arrow[0];
        }
        $self->{alias}->{$arrow[0]} = [ @vals ];
    }
    $fh->close();
}

sub getalias
{
    my($self) = shift();
    return $self->{alias};
}

# Either return our alias, or our argument.
sub alias
{
    my($self) = shift();
    my($name) = @_;

=for testing
    {
        my($ali) = "";
        if (exists($self->{map}->{$name})) {
            $ali = $self->{map}->{$name};
        }
        print("Looking up $name. Its alias is ($ali)\n");

    }

=cut

    if (exists($self->{map}->{$name})) {
        return $self->{map}->{$name};
    }
    trim($name);
    return $name;
}


# Loadup a file with a simple list of aliese.
# No name is special, that is detemined by finding
# a single entry in the contact.csv file.
sub load
{
    my($self) = shift();
    my($fname, $single) = @_;

    if (!defined($single)) {
        die("You must pass the single parameter\n");
    }

    $self->{allmap} = {};
    my($ent);
    my(@ents) = $single->sorted(1);
    foreach $ent (@ents) {
        my($cname, $sname);
        $cname = $ent->cname();
        $sname = $ent->sname();
        trim($cname);
        trim($sname);
        my($name) = $cname . " " . $sname;
        my($lowname) = lc($name);
        if (exists($self->{allmap}->{$lowname})) {
            print("Print: alias dup of: $name\n");
        } else {
            $self->{allmap}->{$lowname} = $ent->id();
        }
    }


    my($fh) = IO::File->new();
    my($line);

    if (!$fh->open($fname, "<")) {
        die("Failed to open $fname $!\n");
    }
    my($lc) = 0;
    my(@list);

    while ($line = $fh->getline()) {
        $lc++;
        if ($line =~ m/^\s*#/) {
            next;
        }
        if ($line =~ m/^\s*$/) {
            next;
        }
        chomp($line);
        @list = split(",", $line);
        if (@list < 2) {
            die("I have an alias line with less than 2 entries $lc ($line)\n");
        }
        my($key);
        my($foundid);
        my($alis) = [];
        foreach my $v (@list) {
            trim($v);
            my($lowv) = lc($v);
            my($id);
            $id = $single->nametoid($v);
            if ($id) {
                if (defined($key)) {
                    die("I have $key and $v defined in the player database\n");
                }
                $key = $v;
                $foundid = $id;
            } else {
                push(@$alis, $v);
            }
        }
        if (!defined($key)) {
            die("None of the aliases ", join(",", @list), ") are present in the player database\n");
        }

        foreach my $v (@$alis) {
            $self->{map}->{$v} = $key;
            my($lowv) = lc($v);
            if (exists($self->{allmap}->{$lowv})) {
                print("Print: alias dup of: $v\n");
            } else {
                $self->{allmap}->{$lowv} = $foundid;
            }
        }
        $self->{alias}->{$key} = $alis;
    }
    $fh->close();
}

sub getallmap
{
    my($self) = shift();
    return ($self->{allmap});
}

sub nametoid
{
    my($self) = shift();
    my($name) = @_;
    my($lowname) = lc($name);
    if (exists($self->{allmap}->{$lowname})) {
        return $self->{allmap}->{$lowname};
    }
    return (0);
}

# Normalize the name, remove leading and trailing spaces
# replace more the consecutive whitespace with one space
sub trim
{
    $_[0] =~ s/^\s*//;
    $_[0] =~ s/\s*$//;
    $_[0] =~ s/\s+/ /g;
}

1;
