# Copyright (c) 2011 Paul Haffenden. All rights reserved.
# $Id$
#
# Code to handle web interaction with Bridewebs.

###################
package Bridgewebs;
###################


use strict;
use warnings;
use JSON;

use LWP;
use IO::File;
use Data::Dumper;
use Scorebridge;
use Sql;

our($bridgewebs_path) = "http://www.bridgewebs.com";
#our($path) = "/cgi-bin/upload/exchange.cgi";
our($path) = "/cgi-bin/bwx/api.cgi";

sub new
{
    my($class) = shift();

    my($self) = {trace => 0};
    bless($self, $class);
    return $self;
}

sub trace
{
    my($self) = shift();
    $self->{trace} = @_;
}

sub action
{
    my($self) = shift;
    my($club, $passwd, $filename, $type, $transfer, $altfile, $retdata) = @_;

    my($data);
    my($fh);
    my($ua);
    my($noread) = 0;

    if ($type eq "upload") {
        my($rfile);
        if (defined($altfile)) {
            if (ref($altfile)) {
                $noread = 1;
            } else {
                $rfile = $altfile;
            }
        } else {
            $rfile = $filename;
        }
        if ($noread) {
            $data = $$altfile;
        } else {
            $fh = IO::File->new();
            if (!$fh->open($rfile, "<")) {
                return("I can't open $rfile $!\n");
            }
            $data = join("", $fh->getlines());
            $fh->close();
        }
    }

    # That's got the data loaded.

    $ua = LWP::UserAgent->new();
    my($posta) = []; # the post arguments.
    my($res);
    push(@$posta,
         club => $club,
         type => $type,
         password => $passwd,
         filename => $filename);

    if (length($transfer)) {
        push(@$posta, transfer => $transfer);
    }


    if ($type eq "upload") {
        push(@$posta,
         data => $data,
            );
    }
    my($fullpath) = $bridgewebs_path . $path . "?club=$club";

    $res = $ua->post($fullpath, $posta);
    if ($res->is_success()) {
        if (defined($retdata)) {
            $$retdata = $res->content();
        }
        return ("");
    } else {
        return ("Failed " .  $res->status_line() . "\n");
    }
}

sub upload
{
    my($self) = shift();
    my($club, $passwd, $filelist, $fh) = @_;
    my($i);
    my($ret);
    my($failure) = 0;

    for ($i = 0; $i < scalar(@$filelist); $i += 2) {
        $fh->print("Attempting ", $filelist->[$i + 1], "\n");
        $ret = $self->action($club, $passwd, $filelist->[$i + 1], "upload",
                             "doc", $filelist->[$i]);
        if ($ret) {
            $failure = 1;
            $fh->print("Failed upload of ", $filelist->[$i + 1], " ($ret)\n");
        }
    }
    if ($failure) {
        return ("At least one of the uploads has failed\n");
    }
    return ("");
}


sub resultname
{
    my($self) = shift();
    my($club, $password, $date, $resnameref) = @_;
    my($res);
    my($ua);
    my($resname);

    $ua = LWP::UserAgent->new();

    my($posta) = [
                  club => $club,
                  password => $password,
                  transfer => "events",
                  date => $date
                 ];

    $res = $ua->post($bridgewebs_path . $path, $posta);

    STDERR->print("The content is (", $res->content(), ")\n") if $self->{trace};
    if ($res->is_success()) {
        ($resname) = $res->content() =~ m/~([ \S]+)~$/m
    } else {
        return("Failed to get resultname ", $res->status_line(), "\n");
    }
    $$resnameref = $resname;
    return "";
}


sub convert_download_key
{
    my($self) = shift;
    my($fname) = @_;

    $fname =~ s/ /_/g;
    $fname =~ s/&/_/g;
    return $fname;
}

sub save_result_to_file
{
    my($self) = shift();
    my($club, $password, $resultid, $resultfile) = @_;
    my($res, $data);

    if (!ref($resultfile)) {
        Sql->GetHandle($Conf::dbname);
    }

    $res = $self->action($club,
                         $password,
                         $resultid,
                         "download",
                         "res",
                         undef,
                         \$data);

    if ($res) {
        return $res;
    }
    STDERR->print("Downloaded data ($data)\n") if $self->{trace};
    ($data) = $data =~ m/data = (.*)$/m;
    $data =~ s/~/\n/g;
    $data =~ s/&amp;/\&/g;
    $data =~ s/&lt;/</g;
    $data =~ s/&gt;/>/g;
    # add a newline if we don't have one at the end.
    if (substr($data, -1, 1) ne "\n") {
        $data .= "\n";
    }
    if (ref($resultfile)) {
        $$resultfile = $data;
    } else {
        my($key) = Scorebridge->sb2kbskey($resultid);
        $res = Scorebridge->save($key, $resultid, $data);
        if (!defined($res)) {
            return("Record $resultid already exists\n");
        }
    }
    return ("");
}

sub calendar
{
    my($self) = shift();
    my($club, $password, $refdata, $year) = @_;
    my($res, $data);

    my($json) = JSON->new();

    my($ua) = LWP::UserAgent->new();
    my($posta) = [
                  club => $club,
                  password => $password,
                  transfer => "cal"
                 ];
    if (defined($year)) {
        push(@$posta, year => $year);
    }
    $res = $ua->post($bridgewebs_path . $path, $posta);
    if ($res->is_success()) {

        STDERR->print($res->content(), "\n") if $self->{trace};

        ($data) = $res->content() =~ /json = (.*)/;
        my($jdata) = $json->decode($data);
        $$refdata = $jdata->{events};
        return "";
    } else {
        return("Call failed with " . $res->status_line());
    }
}

1;

