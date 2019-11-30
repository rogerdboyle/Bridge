# $Id: Confload.pm 1302 2014-06-09 15:54:34Z paulh $
# Copyright (c) 20 Paul Haffenden. All rights reserved.


# Load up the COnf object, using a JSON data file

#################
package Confload;
#################

use strict;
use warnings;
use IO::File;
use JSON;
use Hide;

our($conffile) = "Conf.txt";

sub load
{
    my($no_namespace_load) = @_;
    my($fh);
    my($json);
    my($hide) = Hide->new();

    $json = JSON->new();
    $fh = IO::File->new();
    if (!$fh->open($conffile, "<")) {
        if ($no_namespace_load) {
            return "";
        }
        die("I can't open the config file $conffile $!\n");
    }
    my($jstr) = join("", $fh->getlines());
    my($jdata) = $json->decode($jstr);

    if (exists($jdata->{Conf}->{Eauthpwd}) && $jdata->{Conf}->{Eauthpwd}->{val}) {
        my($out) = $hide->decodestr($jdata->{Conf}->{Eauthpwd}->{val});
        $jdata->{Conf}->{Eauthpwd}->{val} = $out;
    }
    if (exists($jdata->{Conf}->{BWpassword}) && $jdata->{Conf}->{BWpassword}->{val}) {
        my($out) = $hide->decodestr($jdata->{Conf}->{BWpassword}->{val});
        $jdata->{Conf}->{BWpassword}->{val} = $out;
    }

    if ($no_namespace_load) {
        return $jdata;
    }
    my($key, $val);
    while (($key, $val) = each(%$jdata)) {
        loadnamespace($key, $val);
    }
    $fh->close();

}

sub loadnamespace
{
    my($namespace, $ref) = @_;
    my($key, $val);
    while (($key, $val) = each(%$ref)) {
        no strict 'refs';
        my($refname) = ref($val->{val});
        my($name) = $namespace . "::" . $key;
        if ($refname eq "ARRAY") {
            undef(@$name);
            @$name = @{$val->{val}};
        } elsif ($refname eq "HASH") {
            undef(%$name);
            %$name = %{$val->{val}};
        } else {
            undef($$name);
            $$name = $val->{val};
        }
    }
}

sub save
{
    my($data) = @_;
    my($tmp) = $conffile;
    $tmp =~ s/\.txt/.tmp/;
    my($fh);
    my($hide) = Hide->new();
    $fh = IO::File->new();
    if (!$fh->open($tmp, ">")) {
        die("I can't open the new configuration data file $tmp $!\n");
    }
    # Convert the plain text passwords into crypt.
    if (exists($data->{Conf}->{Eauthpwd}) && length($data->{Conf}->{Eauthpwd}->{val})) {
        my($out) = $hide->codestr($data->{Conf}->{Eauthpwd}->{val});
        $data->{Conf}->{Eauthpwd}->{val} = $out;
    }
    if (exists($data->{Conf}->{BWpassword}) && length($data->{Conf}->{BWpassword}->{val})) {
        my($out) = $hide->codestr($data->{Conf}->{BWpassword}->{val});
        $data->{Conf}->{BWpassword}->{val} = $out;
    }
    my($json) = JSON->new();
    $json->canonical(1);
    $json->pretty();
    $fh->print($json->encode($data), "\n");
    $fh->close();
    rename($tmp, $conffile);
}


1;

