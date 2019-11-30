#
# $Id: Relay.pm 540 2010-04-28 15:25:24Z root $
# An Relay object.
#

####################
package Move::Relay;
####################
use strict;
use warnings;

use Move::Place;

our @ISA = qw(Move::Place);

sub new
{
    my($class) = shift();
    if (@_ != 2) {
        die("Relay->new: Wrong args\n");
    }
    my($conf, $num) = @_;
    my($self) = $class->SUPER::new($conf, $num);

    bless($self, $class);
    return ($self);
}
1;
