################
package Ebukeys;
################


use strict;
use warnings;

sub full_key
{
    my($class) = shift();
    my($sname, $cname) = @_;

    return uc($sname) . "|" . uc($cname);
}


sub key
{
    my($class) = shift();
    my($sname) = @_;

    return uc($sname);
}


sub ebu_key
{
    my($class) = shift();
    my($ebuno) = @_;

    if (!defined($ebuno) || (length($ebuno) == 0)) {
        $ebuno = 0;
    }
    $ebuno +=  0;
    return $ebuno;
}


1;


