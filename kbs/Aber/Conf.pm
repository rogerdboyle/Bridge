# $Id: Conf.pm 1046 2013-02-22 19:35:35Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

#############
package Conf;
#############

use strict;
use warnings;
use Dir::Self;
use lib __DIR__ . "/../lib";

use constant NOSORT => 0;
use constant TRAVSORT => 1;

use Confload;
BEGIN {
    Confload::load();
}
1;
