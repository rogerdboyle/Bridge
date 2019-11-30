# Copyright (c) 2007 Paul Haffenden. All rights reserved.
# $Id: Sdate.pm 974 2012-09-18 16:41:35Z phaff $

##############
package Sdate;
##############


use strict;
use warnings;
use POSIX qw(strftime);
use Exporter;

our(@ISA) = qw(Exporter);
our(@EXPORT) = qw(&simpledate splitdate fixeddate);


sub simpledate
{
    my($instr) = @_;
    my($mstr);

    my($day, $mon, $year);

    ($year, $mon, $day) = $instr =~ m/(\d\d\d\d)(\d\d)(\d\d)/;
    if (!defined($day)) {
        return undef;
    }
    $year -= 1900;
    $mon--;
    $mstr = strftime("%A %d %B %Y", 0, 0, 0, $day, $mon, $year);
    return ($mstr);
}


sub fixeddate
{
    my($instr) = @_;
    my($mstr);

    my($day, $mon, $year);

    ($year, $mon, $day) = $instr =~ m/(\d\d\d\d)(\d\d)(\d\d)/;
    if (!defined($day)) {
        return undef;
    }
    $year -= 1900;
    $mon--;
    $mstr = strftime("%d %b %Y", 0, 0, 0, $day, $mon, $year);
    return ($mstr);
}

sub splitdate
{
    my($instr) = @_;
    my($day, $mon, $year);
    ($year, $mon, $day) = $instr =~ m/(\d\d\d\d)(\d\d)(\d\d)/;
    return ($year, $mon, $day);
}
1;
