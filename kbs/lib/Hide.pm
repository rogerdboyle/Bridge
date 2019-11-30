# Hide the passwords by crytping them.
# Copyright (c) 2011 Paul Haffenden. All rights reserved.
# $Id: Hide.pm 869 2012-03-01 17:34:19Z phaff $

use strict;
use warnings;

#############
package Hide;
#############
use Crypt::DES_PP;

our($key) = "katepete";
our($des);

sub new
{
    my($class) = shift();
    my($self);
    my($ukey) = @_;

    if (!defined($ukey)) {
        $ukey = $key;
    }
    if (!defined($des)) {
        $des = Crypt::DES_PP->new($ukey);
    }
    $self = {};
    $self->{des} = $des;

    bless($self, $class);
    return $self;
}

sub codestr
{
    my($self) = shift();
    my($des) = $self->{des};
    my($instr) = @_;
    my($outstr) = "";
    my($len) = length($instr);

    while ($instr) {
        my($in);
        if ($len >= 8) {
            $in = substr($instr, 0, 8);
            substr($instr, 0, 8) = "";
            $len -= 8;
        } else {
            $in = $instr . ("\0" x (8 - $len));
            $instr = "";
        }
        $outstr .= $des->encrypt($in);
    }
    return ($outstr);
}

sub decodestr
{
    my($self) = shift();
    my($des) = $self->{des};
    my($instr) = @_;
    my($outstr) = "";
    my($in);

    if (length($instr) % 8) {
        die("Input to decodestr is not modulo 8\n");
    }

    while ($instr) {
        $in = substr($instr, 0, 8);
        substr($instr, 0, 8) = "";
        $outstr .= $des->decrypt($in);
    }
    $in = index($outstr, "\0");
    if ($in != -1) {
        substr($outstr, $in) = "";
    }
    return $outstr;
}
1;
