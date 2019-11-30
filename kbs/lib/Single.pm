# $Id: Single.pm 1674 2016-12-17 13:16:09Z phaff $

# Copyright (c) 2007,2010 Paul Haffenden. All rights reserved.

##################
package SingleEnt;
##################
use constant ANON     => 0x0001;
use constant INACTIVE => 0x0002;
use constant NOEMAIL  => 0x0004;
use constant CLUB     => 0x0008;
use constant PNG      => 0x0010;
use constant DUMMY    => 0x0020;    # Added/made up.
use constant XPIRED   => 0x0040;    # Dead/Rip

sub new
{
    my($class) = shift();
    my($self) = {
                 cname => "",
                 sname => "",
                 id => 0,
                 email => "",
                 phone => "",
                 refnum => "",
                 flags => 0
                };
    return bless($self, $class);
}

sub cname
{
    my($self) = shift;
    my($arg) = @_;
    my($r) = $self->{cname};
    if (defined($arg)) {
        $self->{cname} = $arg;
    }
    return $r;
}


sub sname
{
    my($self) = shift;
    my($arg) = @_;
    my($r) = $self->{sname};
    if (defined($arg)) {
        $self->{sname} = $arg;
    }
    return $r;
}


sub id
{
    my($self) = shift;
    my($arg) = @_;
    my($r) = $self->{id};
    if (defined($arg)) {
        $self->{id} = $arg;
    }
    return $r;
}

sub phone
{
    my($self) = shift;
    my($arg) = @_;
    my($r) = $self->{phone};
    if (defined($arg)) {
        $self->{phone} = $arg;
    }
    return $r;
}

sub refnum
{
    my($self) = shift;
    my($arg) = @_;
    my($r) = $self->{refnum};
    if (defined($arg)) {
        $self->{refnum} = $arg;
    }
    return $r;
}


sub email
{
    my($self) = shift;
    my($arg) = @_;
    my($r) = $self->{email};
    if (defined($arg)) {
        $self->{email} = $arg;
    }
    return $r;
}

sub noemail
{
    my($self) = shift;
    return $self->flags(NOEMAIL, @_);
}


sub anon
{
    my($self) = shift;
    return $self->flags(ANON, @_);
}


sub notactive
{
    my($self) = shift;
    return $self->flags(INACTIVE, @_);
}


sub png
{
    my($self) = shift;
    return $self->flags(PNG, @_);
}

sub club
{
    my($self) = shift;
    return $self->flags(CLUB, @_);
}


sub dummy
{
    my($self) = shift;
    return $self->flags(DUMMY, @_);
}

sub expired
{
    my($self) = shift;
    return $self->flags(XPIRED, @_);
}

sub flags
{
    my($self) = shift;
    my($const, $val) = @_;
    my($r) = ($self->{flags} & $const) != 0;
    if (defined($val)) {
        if ($val) {
            $self->{flags} |= $const;
        } else {
            $self->{flags} &= ~$const;
        }
    }
    return $r;
}



###############
package Single;
###############

use strict;
use warnings;
use IO::File;
use JSON;
use Pairmap;

our($nametoid);
sub new
{
    my($class) = shift();
    my($anon) = @_;
    my($self) = {};
    undef($nametoid);
    if ($anon) {
        $self->{anon} = 1;
    }
    bless($self, $class);
    return ($self);
}

sub load
{
    my($self) = shift();
    my($fname) = @_;

    # if ignore is set, we ignore all entries in the player
    # file that have the inactive flag set

    $fname = "contact.js";
    my($map);
    my($fh);
    my($ver);
    my($top) = 0;
    my($json) = JSON->new();
    my($data);
    my($rev);
    my($ent);


    $fh = IO::File->new();
    if (!$fh->open($fname, "<:crlf:encoding(utf8)")) {
        return ("Failed to open $fname $!");
    }
    # Remember the input filename
    $self->{fname} = $fname;

    delete($self->{map});
    $map = {};

    $data = $json->decode(join("", $fh->getlines()));
    foreach $ent (@$data) {
        my($ref) = ref($ent);
        if (defined($ref) && $ref eq "ARRAY") {
            my($it) = SingleEnt->new();
            $it->id($ent->[0]);
            $it->sname($ent->[1]);
            $it->cname($ent->[2]);
            $it->email($ent->[3]);
            $it->phone($ent->[4]);
            $it->refnum($ent->[5]);
            if (scalar(@$ent) == 7) {
                my($tstr) = $ent->[6];
                $it->anon($tstr =~ m/[Aa]/);
                $it->notactive($tstr =~ m/[Ii]/);
                $it->noemail($tstr =~ m/[Ee]/);
                $it->club($tstr =~ m/[Cc]/);
                $it->png($tstr =~ m/[Pp]/);
                $it->dummy($tstr =~ m/[Dd]/);
                $it->expired($tstr =~ m/[Xx]/);
            } else {
                $it->noemail($ent->[6]);
                $it->notactive($ent->[7]);
            }
            $map->{$it->id()} = $it;
            if ($it->id() > $top) {
                $top = $it->id();
            }
        } else {
            ($ver) = $ent =~ m/\$Rev: (\d+) \$/;
            if (!defined($ver)) {
                $ver = 0;
            }
            $self->{version} = $ver;
            $self->{line} = $ent;
        }
    }
    $self->{map} = $map;
    $self->{top} = $top;
    return ("");
}

sub sorted
{
    my($self) = shift();
    my($retall) = @_;

    # If we pass an argument, then return everyone.

    my(@ret);

    # Don't return inactive entries
    foreach my $val (values(%{$self->{map}})) {
        next if $val->notactive() && !defined($retall);
        push(@ret, $val);
    }
    foreach my $val (@ret) {
        if (!defined($val->sname())) {
            die("sname not defined in sorted. ", $val->id(), "\n");
        }
        if (!defined($val->cname())) {
            die("cname not defined in sorted. ", $val->id(), "\n");
        }
    }
    @ret = sort({ (uc($a->sname()) cmp uc($b->sname())) ||
                 (uc($a->cname()) cmp uc($b->cname()))} @ret);
    return (@ret);
}

sub maxnamelen
{
    my($self) = shift();
    my($len) = 0;
    my($val);

    while ((undef, $val) = each(%{$self->{map}})) {
        my($tlen);
        $tlen = length($val->cname()) + length($val->sname());
        if ($tlen > $len) {
            $len = $tlen;
        }
    }
    return ($len);
}


sub break
{
    my($self) = shift();
    my($gid) = @_;

    my($id0, $id1);
    my($e0, $e1);

    ($id0, $id1) = Pairmap->break($gid);
    if (!exists($self->{map}->{$id0})) {
        return ($id0, $id1);
    } else {
        $e0 = $self->{map}->{$id0};
    }
    if (!exists($self->{map}->{$id1})) {
        return ($id0, $id1);
    } else {
        $e1 = $self->{map}->{$id1};
    }
    if (($e0->sname() lt $e1->sname()) ||
        (($e0->sname() eq $e1->sname()) &&
         ($e0->cname() lt $e1->cname()))) {
        return ($id0, $id1);
    } else {
        return ($id1, $id0);
    }
}

sub classbreak
{

    my($gid) = @_;
    return Pairmap->break($gid);
}

sub fullname
{
    my($self) = shift();
    my($gid) = @_;

    my($id0, $id1) = $self->break($gid);

    if (exists($self->{map}->{$id0})) {
        $id0 = $self->{map}->{$id0}->cname() . " " . $self->{map}->{$id0}->sname();
    } else {
        $id0 = "Player $id0";
    }

    if (exists($self->{map}->{$id1})) {
        $id1 = $self->{map}->{$id1}->cname() . " " . $self->{map}->{$id1}->sname();
    } else {
        $id1 = "Player $id1";
    }
    return ("$id0 & $id1");
}

sub name1
{
    my($self) = shift();
    my($gid) = @_;

    my($id0, undef) = $self->break($gid);
    if (exists($self->{map}->{$id0})) {
        $id0 = $self->{map}->{$id0}->cname() . " " . $self->{map}->{$id0}->sname();
    } else {
        $id0 = "Player $id0";
    }
    return ($id0);
}

sub name2
{
    my($self) = shift();
    my($gid) = @_;

    my(undef, $id0) = $self->break($gid);
    if (exists($self->{map}->{$id0})) {
        $id0 = $self->{map}->{$id0}->cname() . " " . $self->{map}->{$id0}->sname();
    } else {
        $id0 = "Player $id0";
    }
    return ($id0);
}


sub refnum1
{
    my($self) = shift();
    my($gid) = @_;

    my($id0, undef) = $self->break($gid);
    if (exists($self->{map}->{$id0})) {
        $id0 = $self->{map}->{$id0}->refnum();
    } else {
        $id0 = 0;
    }
    return ($id0);
}

sub refnum2
{
    my($self) = shift();
    my($gid) = @_;

    my(undef, $id0) = $self->break($gid);
    if (exists($self->{map}->{$id0})) {
        $id0 = $self->{map}->{$id0}->refnum();
    } else {
        $id0 = 0;
    }
    return ($id0);
}

# return the revision number of the contact.csv file.
sub version
{
    my($self) = shift();
    return ($self->{version});
}

sub name
{
    my($self) = shift();
    my($id) = @_;
    if (exists($self->{map}->{$id})) {
        return $self->{map}->{$id}->cname() . " " . $self->{map}->{$id}->sname();
    } else {
        return ("Player $id");
    }
}

sub refnum
{
    my($self) = shift();
    my($id) = @_;
    if (exists($self->{map}->{$id})) {
        return $self->{map}->{$id}->refnum();
    } else {
        return 0;
    }
}

sub savetofile
{
    my($self) = shift();
    my($fh) = IO::File->new();
    my($fname) = "contact.js";
    if (!$fh->open($fname, ">:crlf:encoding(utf8)")) {
        die("Failed to open $fname for writing $!\n");
    }


    my($reta) = [];
    my($i) = 1;
    my($map) = $self->{map};
    while ($i <= $self->{top}) {
        if (exists($map->{$i})) {
            my($ent) = $map->{$i};
            my($fstr) = "";
            if ($ent->anon()) {
                $fstr .= "a";
            }
            if ($ent->club()) {
                $fstr .= "c";
            }
            if ($ent->dummy()) {
                $fstr .= "d";
            }
            if ($ent->noemail()) {
                $fstr .= "e";
            }
            if ($ent->notactive()) {
                $fstr .= "i";
            }
            if ($ent->png()) {
                $fstr .= "p";
            }
            if ($ent->expired()) {
                $fstr .= "x";
            }
            push(@$reta,
                 [ $ent->id() + 0, $ent->sname(), $ent->cname(),
                   $ent->email(), $ent->phone(), $ent->refnum(),
                   $fstr ] );
        }
        $i++;
    }
    my($json) = JSON->new();
    $json->allow_nonref();
    my($str) = "[\n";
    chomp($self->{line});
    $str .= $json->encode($self->{line});

    foreach $i (@$reta) {
        $str .= ",\n";
        $str .= $json->encode($i);
    }
    $str .= "\n]\n";
    $fh->print($str);
    $fh->close();
}



sub entry
{
    my($self) = shift();
    my($id) = @_;

    return ($self->{map}->{$id});
}

# Do a name to id lookup

sub nametoid
{
    my($self) = shift();
    my($name) = @_;   # The name is cname one space surname

    if (!defined($nametoid)) {
        $nametoid = {};
        my($e);
        foreach $e ($self->sorted(1)) {
            my($key) = $e->cname() . " " . $e->sname();
            Alias::trim($key);
            $key = lc($key);
            if (exists($nametoid->{$key})) {
                die("We have a duplicate name ($key) in the contact file\n");
            }
            $nametoid->{$key} = $e->id();
        }
    }
    Alias::trim($name);
    $name = lc($name);
    if (exists($nametoid->{$name})) {
        return $nametoid->{$name};
    }
    return undef
}


sub checkname
{
    my($self) = shift();
    my($alias, $p1name, $p2name, $dummies) = @_;
    my($p);
    my($ent);
    my($pa) = [ $p1name , $p2name ];
    my(@newids);
    my($id);

    my($ind) = -1;
    foreach $p (@$pa) {
        $ind++;
        $id = $alias->nametoid($p);
        if (!$id) {
            print("$p does not exist\n");
            # We don't exist
            $id = $self->{top} + 1;
            $self->{top} = $id;

            my(@f) = split(/\s+/, $p, 2);
            if (scalar(@f) == 1) {
                @f = qw(Not Known);
            }
            $ent = SingleEnt->new();
            $ent->id($id);
            $ent->sname($f[1]);
            $ent->cname($f[0]);
            $self->{map}->{$id} = $ent;
            if ($dummies->[$ind]) {
                $self->dummy(1);
            }
        } else {
            $self->{map}->{$id}->notactive(0);
        }
        push(@newids, $id);
    }
    return @newids;
}


# Take a string like "Peter Haffenden & Rosemary Biscuit"
# and return a valid pair number. If the name or alias doesn't exist
# add one. Try to deal with badly formatted names and make up ones when this
# happens, using the $indexref to create a unique one within an individual
# session. Note the caller has to take steps to save the '$single' file
# to retain the new names


our($surname) = "Zz_%03d";
our($cname) = "Chad";

sub checknames_alias_update
{
    my($self) = shift();
    my($alias, $namestring, $indexref) = @_;
    my($dummies) = [0, 0];
    if ($namestring !~ /&/) {
        # Make up a new name.
        $namestring .= " & $cname " . sprintf($surname, $$indexref++);
        $dummies->[0] = 1;
        $dummies->[1] = 1;
    }
    my($amps) = [ split("&", $namestring) ];
    my($amp);
    my($rnames) = [];

    for $amp (@$amps) {
        Alias::trim($amp);

        my($subname) = [ split(/ +/, $amp) ];
        if (scalar(@$subname) > 2) {
            # We have more than just the two fields!
            # Make this double (or even trippled) barreled by hyphen
            my($front) = shift(@$subname);
            my($sur) = join(" ", @$subname);
            $subname = [ $front, $sur ];
        }
        push(@$rnames, $subname);
    }
    if (!defined($rnames->[0]) || !defined($rnames->[1])) {
        die("Names not quite right ($namestring)\n");
    }
    # Check for married couples and crap like "Anon1 & Anon2"
    my($len1) = scalar(@{$rnames->[0]});
    my($len2) = scalar(@{$rnames->[1]});

    if (($len1 == 1) && ($len2 == 2)) {
        # This is the normal Fred & Makr Jones stuff.
        push(@{$rnames->[0]}, $rnames->[1]->[-1]);
    } else {
        if ($len1 == 1) {
            push(@{$rnames->[0]}, sprintf($surname, $$indexref++));
            $dummies->[0] = 1;
        }
        if ($len2 == 1) {
            push(@{$rnames->[1]}, sprintf($surname, $$indexref++));
            $dummies->[1] = 1;
        }
    }
    # Check that the names aren't idendical.
    if (join(" ", @{$rnames->[0]}) eq join(" ", @{$rnames->[1]})) {
        # The same name. Make up a unique one.
        $rnames->[1]->[-1] .= sprintf("_%03d", $$indexref++);
        $dummies->[1] = 1;
    }
    my(@fullnames) = (join(" ", @{$rnames->[0]}), join(" ", @{$rnames->[1]}));
    my(@newids) = $self->checkname($alias, $fullnames[0], $fullnames[1], $dummies);
    return Pairmap->normal(@newids);
}

1;
