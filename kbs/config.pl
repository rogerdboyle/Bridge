#
# Program to edit the club configuration file
# $Id$


use strict;
use warnings;
use Tk;

use Conf;
use Configclient;


sub main
{
    my($mw) = MainWindow->new();
    Configclient::main($mw, [ sub { exit(0); }]);
}

main();
exit(0);
