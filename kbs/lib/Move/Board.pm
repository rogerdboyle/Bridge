
# $Id: Board.pm 661 2011-02-23 08:33:58Z paulh $

####################
package Move::Board;
####################

use strict;
use warnings;

sub new
{
    my($class) = shift();

    if (@_ != 2) {
        die("Board->new wrong args\n");
    }
    my($conf, $ind) = @_;

    my($self) = {};
    $self->{conf} = $conf;
    $self->{num} = $ind + 1;
    bless($self, $class);
    return ($self);
}

# Calculate the board description string, in the form like 2-4
sub boards
{
    my($self) = shift;
    my($bpr) = @_;

    use integer;
    my($start) = (($self->{num} - 1) * $bpr) + 1;
    my($end) = $start + $bpr -1;
    return("$start-$end");
}

1;

