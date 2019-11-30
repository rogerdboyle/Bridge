# $Id: Boards.pm 712 2011-05-24 09:26:35Z paulh $

#####################
package Move::Boards;
#####################

use strict;
use warnings;

use Move::Board;


sub new
{
    my($class) = shift();

    if (@_ != 1) {
        die("Boards->new: wrong args\n");
    }
    my($conf) = @_;

    my($i);
    my($nos) = $conf->get_nos();
    my($self) = {};
    my($boards) = [];

    $self->{boards} = $boards;
    $self->{conf} = $conf;

    bless($self, $class);
    for ($i = 0; $i < $nos; $i++) {
        push(@$boards, Move::Board->new($conf, $i));
    }
    return ($self);
}

sub getboard
{
    my($self) = shift();

    if (@_ != 1) {
        die("Boards->getboard: wrong args\n");
    }
    my($ind) = @_;


=for comment

    if (substr($ind, 0, 1) eq "S") {
        my($t) = $self->{conf}->get_tables();
        # we have a shared board.
        $ind = substr($ind, 1);
        # Now have the table we are sharing with,
        $ind = $t->gettable($ind);
        $ind = $ind->{boards};
    }

=cut

    die(caller()) if !defined($ind);
    # For Bowman movements (or the one we use), we
    # have a table with no boards.
    if ($ind == 0) {
        return undef();
    }


    return ($self->{boards}->[$ind - 1]);
}
1;
