# $Id: Tables.pm 540 2010-04-28 15:25:24Z root $

# We know all about the tables.

#####################
package Move::Tables;
#####################


use strict;
use warnings;

use Move::Table;

sub new
{
    my($class) = shift();
    if (@_ != 2) {
        die("Tables->new: Wrong args\n");
    }
    my($conf, $num) = @_;

    my($self) = {};
    my($tables) = [];

    $self->{conf} = $conf;
    $self->{tables} = $tables;

    bless($self, $class);

    my($i);
    for ($i = 0; $i < $num; $i++) {
        push(@$tables, Move::Table->new($conf, $i + 1));
    }
    return ($self);
}

sub gettable
{
    my($self) = shift();
    if (@_ != 1) {
        die("Tables->gettable: Wrong args\n");
    }
    my($num) = @_;
    return ($self->{tables}->[$num - 1]);
}

sub num
{
    my($self) = shift();
    if (@_ != 0) {
        die("Tables->num: Wrong args\n");
    }
    return (scalar(@{$self->{tables}}))
}
1;
