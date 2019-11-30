####################
package Scorebridge;
####################


# code to save and load a scorebridge file.
use strict;
use warnings;


use JSON;
use Encode qw(decode);


use Sql;

sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    return $self;
}


# Load the json'ed data, returning the full structure/
sub jload
{
    my($self) = shift();
    my($key) = @_;
    my($data);
    my($jdata);
    my($json);

    $json = JSON->new();
    $jdata = Sql->load(Sql::SB, $key);
    $data = $json->decode($jdata);
    return $data;
}


sub load
{
    my($self) = shift();
    my($key) = @_;

    my($data) = $self->jload($key);
    return($data->{contents}, $data->{sbname});
}



sub save
{
    my($self) = shift();
    my($key, $sbname, $data) = @_;


    # This is a nasty hack. The original file uses cp1252 character encoding.
    # With string in the file like "3/4 Howell" in the movement description
    # section. Where 3/4 is replaced with a single byte 0xbe. When
    # this data comes back from the db we have the utf8_on flag set to true,
    # but it isn't valid utf8 and so barfs when we try to json encode it.
    # (This might be a problem with how the Sql is returning its data).
    # We have the choice to either convert the file to utf8, or leaving
    # it as is. I've gone for the later so we preserve the saved file exactly.
    # We turn the utf8 flag off by hand here.
    Encode::_utf8_off($data);

    my($jdata) = {
                  sbname => $sbname,
                  contents => $data
                 };
    my($json) = JSON->new();
    my($jstr) = $json->encode($jdata);
    my($ret) = Sql->insert(Sql::SB, $key, $jstr);

    if (!defined($ret)) {
        die("Failed to save $key in scorebridge file\n");
    }
}


sub convertall
{
    my($self) = shift();
    my($keys) = Sql->keys(Sql::SB);
    my($key);

    foreach $key (@$keys) {
        my($cdata) = Sql->load(Sql::SB, $key);
        if (!defined($cdata)) {
            die("Failed to load $key\n");
        }
        print("The key is ($key)\n");
        my($newkey) = $self->sb2kbskey($key);
        $self->save($newkey, $key, $cdata);
        Sql->del(Sql::SB, $key);
    }
}


# Mostly a class function

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

sub sb2kbskey
{
    my($class) = shift();
    my($sbname) = @_;
    my($dir);

    $sbname =~ s:.*/::;
    my($y, $mon, $d) = $sbname =~ m/(\d\d\d\d)(\D\D\D)(\d+)/;
    if (!exists($mlookup->{$mon})) {
        die("I can't translate the month $mon from ($sbname)\n");
    }
    if (length($d) == 1) {
        $d = "0" . $d;
    }
    $dir = $y . $mlookup->{$mon} . $d;
    return ($dir);
}

