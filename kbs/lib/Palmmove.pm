# $Id: Palmmove.pm 747 2011-07-08 16:50:28Z phaff $
# Copyright (c) 2008 Paul Haffenden. All rights reserved.
# The PalmMovement database support code.
#
#################
package Palmmove;
#################
use Palm::PDB;
our(@ISA) = qw(Palm::PDB);
sub import
{
    Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
     [ "PJJH", "MOVD" ] );
}

sub PackAppInfoBlock
{
    return ("");
}

sub PackSortBlock
{
    return ("");
}


# We get passed the Moveconfig record.
# We have to pack it so the Palm can use the
# Move data.
# We first have a header that contains the following:
# Id of the movement. (UInt32)
# tables
# relays
# rounds
# sets of boards
# Name offset (Uint16)
# Movement descripton offset (Uint16)
#
#
# Following those four bytes are round * (tables + relays)
# data elements. Each element contains the following 4 bytes
# (even the relays)
# n/s pair number
# e/w pair number
# board set number
# a pad byte.
#
# Finally a string table, that the name and descriptions
# offset into.
sub PackRecord
{
    my($self) = shift();
    my($rec) = @_;
    my($data) = "";

    # This is the special first record.
    if (exists($rec->{special})) {
        # The array of movements.
        my($movea) = $rec->{special}->{movements};
        my($pin) = $rec->{special}->{pin};
        if (scalar(@$movea) != 34) {
            die("The Quick setup movement array does not ",
                "contain 34 entries\n");
        }
        $data = pack("N" x 35, @$movea, $pin);
    } else {
        my($mc) = $rec->{moveconfig};
        my($not, $nor, $id);
        my($rnd);
        my($rndctl) = $mc->{rndctl};

        $not = $mc->get_not();
        $nor = $mc->get_nor();
        $id = $mc->get_id();


        # The header.
        my($size);

        # The offset for the string table is the size of the
        # header, the table and relay data.

        $size = 4 + 4 + 4 + (($not + $nor) * $mc->get_maxrounds()) * 4;

        $data = pack("NCCCCnn", $id, $not, $nor, $mc->get_maxrounds(),
                     $mc->get_nos(), $size, $size + length($mc->{name}) + 1);

        if ($mc->get_maxrounds() != scalar(@$rndctl)) {
            die("The control array is not the correct length!\n");
        }
        foreach $rnd (@$rndctl) {
            my($ctltables) = $rnd->{tables};
            my($ctlrelays) = $rnd->{relays};
            my($item);

            if ($not != scalar(@$ctltables)) {
                die("The number of tables is incorrect!\n");
            }
            if ($nor != scalar(@$ctlrelays)) {
                die("The number of relays is incorrect!\n");
            }
            foreach $item (@$ctltables) {
                $data .= pack("CCCC", $item->{ns}, $item->{ew}, $item->{set},
                              0);
            }
            foreach $item (@$ctlrelays) {
                $data .= pack("CCCC", $item->{ns}, $item->{ew}, $item->{set},
                              0);
            }
        }
        print("Name is ($mc->{name}) and description $mc->{desc}\n");
        # Now the string table, the name.
        $data .= pack("Z*Z*", $mc->{name}, $mc->{desc});
    }
    return ($data);
}

1;


