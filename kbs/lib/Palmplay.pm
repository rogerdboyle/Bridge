# $Id: Palmplay.pm 1644 2016-11-10 11:42:45Z phaff $
# Copyright (c) 2008 Paul Haffenden. All rights reserved.
# The PalmPlayer database support code.
#
#################
package Palmplay;
#################
use Palm::PDB;
our(@ISA) = qw(Palm::PDB);
sub import
{
    Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
     [ "PJJH", "PLAD" ] );
}

sub PackAppInfoBlock
{
    return ("");
}

sub PackSortBlock
{
    return ("");
}
#
#
# The record contains:
# uint16 global person id
# string

sub PackRecord
{
    my($self) = shift();
    my($rec) = @_;
    my($d) = $rec->{entry};
    # Now the string table, the name.
    if (!defined($d)) {
        $data = pack("nZ*", 0, "Unknown");
    } else {
        $data = pack("nZ*", $d->id(), $d->sname() . " " . $d->cname());
    }
    return ($data);
}

1;
