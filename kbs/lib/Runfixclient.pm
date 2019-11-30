use strict;
use warnings;

#####################
package Runfixclient;
#####################

use Getopt::Std;

our($mlookup) = {
                 Jan => "01",
                 Feb => "02",
                 Mar => "03",
                 Apr => "04",
                 May => "05",
                 Jun => "06",
                 Jul => "07",
                 Aug => "08",
                 Sep => "09",
                 Oct => "10",
                 Nov => "11",
                 Dec => "12",
};


sub main
{
    local(@ARGV) = @ARGV;
    my($cmd, $ftp) = @_;
    my($fname);
    my(@cmd);
    my($opts) = {};
    getopts("c:", $opts);

    if (!$opts->{c}) {
        if (!defined($ARGV[0])) {
            $fname = `perl ../bwgetresult.pl`;
            if ($fname =~ /^OK:/) {
                $fname = substr($fname, 3);
                chomp($fname);
            } else {
                die("Failed in result fetch: $fname");
            }
        } else {
            $fname = $ARGV[0];
        }
        # Do the conversion
        @cmd = qw(perl ../sb2kbs.pl);
        push(@cmd, $fname);

        system(@cmd);
        if ($? != 0) {
            die("$cmd[1] failed\n");
        }
    } else {
        $fname = $opts->{c};
    }

    # Do the competition
    @cmd = qw(perl ../comp.pl);
    push(@cmd, @$cmd);
    push(@cmd, $fname);
    system(@cmd);
    if ($? != 0) {
        die("$cmd[1] failed\n");
    }

    if (defined($ftp)) {
        &$ftp();
    } else {
        # The upload of the competition files.
        @cmd = qw(perl ../uploadbw.pl);
        system(@cmd);
        if ($? != 0) {
            die("$cmd[1] failed\n");
        }
    }
}

