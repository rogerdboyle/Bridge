# Copyright (c) 2007 Paul Haffenden. All rights reserved.
# $Id: Mailclient.pm 869 2012-03-01 17:34:19Z phaff $

###################
package Mailclient;
###################

use strict;
use warnings;
use IO::File;
use IO::Dir;
use Getopt::Std;
use JSON;

use Sdate;
use Mail::Sender::Easy qw(email);

#
# The current policy is to insert the text version of the
# results into the body of the mail message, with the full
# html results as an attachment. For the masterpoint issuer
# a second attachment follows, either a the test result (-t)
# or an html version.
#
sub main
{
    my($args);
    my($dir);
    my($fh);
    my($emailfile);
    my($textres);
    my($htmlres);
    my($addr);
    my($addrs);
    my($opts);
    my($data);
    my(@hdata);
    my($debug);
    my($datestr);
    my($msgfile);
    my($msg) = "";
    my($results) = 1;
    my($short) = 0;
    my($textname) = "tr.txt";
    my($htmlname) = "tr.htm";
    my($text) = 0;
    my($ofh) = @_;


    if (!defined($ofh)) {
        $ofh = "STDOUT";
    }
    # I don't want any X-Mailer stuff in the mail headers.
    $Mail::Sender::NO_X_MAILER = 1;
    $opts = {};

    getopts("p:dm:r:st", $opts);
    if (exists($opts->{p})) {
        $Conf::Eauthpwd = $opts->{p};
    }
    if ($opts->{d}) {
        $debug = 1;
    }
    # Short results, don't include the html version of the results.
    if ($opts->{s}) {
        $short = 1;
    }
    if (exists($opts->{m})) {
        $msgfile = $opts->{m};
    }

    if (exists($opts->{r})) {
        # Don't send the results.
        $results = 0;
    }

    if (exists($opts->{t})) {
        # Send the header file in text format, tr.txt instead
        # of tr.htm
        $text = 1;
    }

    if (!defined($ARGV[0])) {
        die("Missing directory argument\n");
    } else {
        $dir = $ARGV[0];
    }
    if ($results) {
        $datestr = simpledate($dir);
        if (!defined($datestr)) {
            die("Unable to extract the date from ($dir)\n");
        }
    }
    # Try to open the email file
    $emailfile = "email.txt";
    $fh = IO::File->new();
    if (!$fh->open($emailfile, "<")) {
        die("Unable to open the emailfile ($emailfile) $!\n");
    }
    my($jstr);
    my($json);
    $jstr = join("", $fh->getlines());
    $fh->close();
    $json = JSON->new();
    # read them in
    $addrs = $json->decode($jstr);

    if ($results) {
        # Open the text file of results.
        my($fname) = "$textname";
        if (!$fh->open($fname, "<")) {
            die("Failed to open ($fname) $!\n");
        }
        $fh->sysread($data, -s $fname);
        $fh->close();
    }

    $msg = "";
    if ($msgfile) {
        if (!$fh->open($msgfile, "<")) {
            die("Failed to open ($msgfile) $!\n");
        }
        $msg .= join("", $fh->getlines());
        $fh->close();
    }

    if ($results && !$short) {
        $htmlres = "tr$dir.htm";
        if (!$fh->open($htmlres, "<")) {
            die("Failed to open ($htmlres) $!\n");
        }
        @hdata = $fh->getlines();
        $fh->close();
    }
    $args = {};
    if ($debug) {
        $args->{debug} = "debug.txt";
    }
    $args->{from} = $Conf::Efrom;
    $args->{smtp} = $Conf::Esmtphost;
    $args->{port} = 25;
    if ($Conf::Eauthpwd) {
        $args->{auth} = $Conf::Eauth;
        $args->{authid} = $Conf::Eauthid;
        $args->{authpwd} = $Conf::Eauthpwd;
    }

    if ($results) {
        $args->{subject} = "$Conf::Club Results $datestr";
    } else {
        $args->{subject} = $opts->{r};
    }

    my($rawmsg);
    my($rawatt);
    if ($data) {
        $rawmsg = $msg . "\n" . $data;
    } else {
        $rawmsg = $msg . "\n";
    }

    # If we have to add a header file, construct its attachment
    # entry (headeratt) here.
    my($headeratt);
    my($ctype) = "text/html";
    my($headerfmt) = $htmlname;

    if ($results) {
        if ($text) {
            $ctype = "text/plain";
            $headerfmt = $textname;
        } else {
            my($fname) = "$htmlname";
            if (!$fh->open($fname, "<")) {
                die("Failed to open the html header file $fname $!\n");
            }
            $fh->sysread($data, -s $fname);
            $fh->close();
        }
    }
    $headeratt =
       {
        description => $headerfmt,
        msg => $data,
        ctype => $ctype,
       };

    if ($results) {
        if (!$short) {
            $rawatt =
              [
               {
                description => "fulltr.htm",
                msg => join("", @hdata),
                ctype => "text/html",
               },
              ];
        } else {
            $rawatt = [];
        }
    }

    my($retry);
    my($biffhash) = "biff.txt";
    for ($retry = 0; $retry < 5; $retry++) {
        my($faillist) = [];
        foreach $addr (@$addrs) {
            my($email, $pair) = @$addr;
            my($bifffile);

            $args->{to} = $email;
            $args->{_text} = $rawmsg;
            # To be filled in.
            if ($results) {
                my($newatt);
                $newatt = $rawatt;
                $args->{_attachments} = $newatt;

                # See if we want to add the masterpoint collector
                if (masterpointer($email, \@Conf::EMaster)) {
                    push(@$newatt, $headeratt);
                }

                $bifffile = findbifffile($pair, "$Conf::resdir/$dir");
                if ($bifffile) {
                    push(@$newatt,
                         {
                          description => $biffhash,
                          msg => $bifffile,
                          ctype => "text/plain",
                         });
                }
            }
            $ofh->print("Attempting to send email to $email ($pair)\n");
            if (!email($args)) {
                $ofh->print("Failed\n");
                push(@$faillist, $addr);
            } else {
                $ofh->print("Ok\n");
            }
        }
        $addrs = $faillist;
        if (!scalar(@$addrs)) {
            last;
        } else {
            $ofh->print("There were some email failures\n");
            sleep(5);
        }
    }
}

sub findbifffile
{
    my($pair, $search) = @_;
    my($dir) = IO::Dir->new($search);
    my($d);
    my($match) = qr/^biff_$pair\D/;
    if ($dir) {
        while ($d = $dir->read()) {
            if ($d =~ m/$match/) {
                my($fh, $data);
                $fh = IO::File->new();
                if (!$fh->open("$search/$d", "<")) {
                    return ("");
                }
                $data = join("", $fh->getlines());
                $data =~ s/$/\r/mg; # Add the MS-DOS stuff.
                $fh->close();
                return ($data);
            }
        }
    }
    return ("");
}

our($masterlook);
sub masterpointer
{
    my($email, $masterlist) = @_;
    my($m);

    if (!defined($masterlook)) {
        $masterlook = {};
        foreach $m (@$masterlist) {
            $masterlook->{$m} = 1;
        }
    }
    return (exists($masterlook->{$email}));
}


1;

