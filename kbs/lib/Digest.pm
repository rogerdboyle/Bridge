###############
package Digest;
###############

use strict;
use warnings;

use Digest::SHA qw(sha256_hex);


sub digest
{
    my($club) = @_;

    my($secretprefix) = "foal";
    my($secretsuffix) = "mare";
    my($digest);

    $digest = sha256_hex($secretprefix . $club . $secretsuffix);
    return($club . $digest);
}
1;
