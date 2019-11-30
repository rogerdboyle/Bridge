############
package Sql;
############

use strict;
use warnings;
use DBI;

our($thehandle) = undef();

use constant SB => 0;
use constant MAP => 1;
use constant TRAV => 2;
use constant SCORE => 3;
use constant SETUP => 4;
use constant WEB => 5;
use constant ECATS => 6;

our ($map) = {
              SB    , "scorebridge",
              MAP   , "map",
              TRAV  , "trav",
              SCORE , "score",
              SETUP , "setup",
              WEB   , "web",
              ECATS , "ecats"
             };

our($revmap) = {};
sub GetHandle
{
    my($class) = shift();
    my($fname) = @_;
    my($dbh);
    if (!defined($thehandle)) {
        my($dsn)      = "dbi:SQLite:dbname=$fname";
        my($user)     = "";
        my($password) = "";
        $dbh = DBI->connect($dsn, $user, $password, {
                                                         PrintError       => 1,
                                                         RaiseError       => 0,
                                                         AutoCommit       => 1,
                                                         sqlite_unicode   => 1,
                                                         FetchHashKeyName => 'NAME_lc',});
        if (defined($dbh)) {
            $thehandle = $dbh;
        }
        my($key, $val);
        while (($key, $val) = each(%$map)) {
            $revmap->{$val} = $key;
        }
        $revmap->{"sb"} = SB;
    } else {
        $dbh = $thehandle;
    }
    return($dbh);
}

sub load
{
    my($class) = shift();
    my($tname, $key) = @_;

    my($sqlcmd) = "select json from $map->{$tname} where sess == ?";
    my($sth) = $thehandle->prepare($sqlcmd);
    $sth->execute($key);
    my($json) = $sth->fetchrow();
    $sth->finish();
    return ($json);
}

sub save
{
    my($class) = shift();
    my($t, $key, $json) = @_;
    my($ret);
    my($sth);
    my($sqlcmd);

    $sth = $thehandle->prepare("begin");
    $ret = $sth->execute();
    if (!defined($ret)) {
        print("Failed to begin\n");
        return $ret;
    }
    $ret = $class->load($t, $key);
    if (defined($ret)) {
        if ($ret eq $json) {
            # The data is identical
            $ret = 1;
        } else {
            $sqlcmd = "update $map->{$t} set json=? where sess = ?";
            $sth = $thehandle->prepare($sqlcmd);
            $ret = $sth->execute($json, $key);
        }
    } else {
        $sqlcmd = "insert into $map->{$t} values (?, ?)";
        $sth = $thehandle->prepare($sqlcmd);
        $ret = $sth->execute($key, $json);
    }
    $sqlcmd = "commit";
    $sth = $thehandle->prepare($sqlcmd);
    my($rc) = $sth->execute();
    if (!defined($rc)) {
        return $rc;
    }
    return $ret;
}


sub insert
{
    my($class) = shift();
    my($t, $key, $json) = @_;
    my($ret);
    my($sqlcmd) = "insert into $map->{$t} values (?, ?)";
    my($sth) = $thehandle->prepare($sqlcmd);
    $ret = $sth->execute($key, $json);
    return ($ret);
}


sub del
{
    my($class) = shift();
    my($t, $sess) = @_;
    my($sqlcmd) = "delete from $map->{$t} where sess == ?";
    my($sth) = $thehandle->prepare($sqlcmd);
    my($ret);
    $ret = $sth->execute($sess);
    return $ret;
}

sub keys
{
    my($class) = shift;
    my($t) = @_;
    my($ret);

    my($sqlcmd) = "select sess from $map->{$t}";
    my($sth) = $thehandle->prepare($sqlcmd);
    $ret = $sth->execute();
    if (defined($ret)) {
        $ret = $sth->fetchall_arrayref();
        map({$_ = $_->[0]} @$ret);
    } else {
        $ret = [];
    }
    return $ret;
}

sub keypresent
{
    my($class) = shift();
    my($t, $key) = @_;

    my($ret) = $class->keys($t);
    my($map) = {};
    map({$map->{$_} = 1} @$ret);
    return exists($map->{$key});
}

1;
