#
# $Id: inactive.pl 1046 2013-02-22 19:35:35Z phaff $
# Generate a list of inactive players.
# (6 months is the hardcode value).

use strict;
use warnings;

use Conf;

use Inactiveclient;
sub main
{
    Inactiveclient::main();
}

main();
exit(0);
