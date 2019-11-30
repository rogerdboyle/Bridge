
# $Id: Relays.pm 540 2010-04-28 15:25:24Z root $

#####################
package Move::Relays;
#####################


use strict;
use warnings;

use Move::Relay;


# We know all about the tables.

sub new
{
    my($class) = shift();
    if (@_ != 2) {
        die("Relays->new: Wrong args\n");
    }
    my($conf, $num) = @_;
    my($self) = {};
    my($relays) = [];
    bless($self, $class);

    $self->{conf} = $conf;
    $self->{relays} = $relays;

    my($i);
    for ($i = 0; $i < $num; $i++) {
        push(@$relays, Move::Relay->new($conf, $i + 1));
    }
    return ($self);
}

sub getrelay
{
    my($self) = shift();
    if (@_ != 1) {
        die("Relays->getrelay: Wrong args\n");
    }
    my($num) = @_;

    return ($self->{relays}->[$num - 1]);
}

sub num
{
    my($self) = shift();
    if (@_ != 0) {
        die("Relays->num: Wrong args\n");
    }
    return (scalar(@{$self->{relays}}));
}

1;
