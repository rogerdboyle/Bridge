use strict;
use warnings;
use DBI;
sub main
{


    my($dbfile) = "data.db";

    my($dsn)      = "dbi:SQLite:dbname=$dbfile";
    my($user)     = "";
    my($password) = "";
    my($dbh) = DBI->connect($dsn, $user, $password, {
                                                     PrintError       => 0,
                                                     RaiseError       => 1,
                                                     AutoCommit       => 1,
                                                     FetchHashKeyName => 'NAME_lc',});

    if (!defined($dbh)) {
        die("Failed\n");
    }
    my($rc);
    my($sql) = <<'END_SQL';
CREATE TABLE XXX (
  sess   TEXT UNIQUE PRIMARY KEY,
  json   TEXT
);
END_SQL

    my($tblnames, $t);

    $tblnames = [ qw(scorebridge map trav score setup web ecats)];
    foreach $t (@$tblnames) {
        my($sqlcmd) = $sql;
        $sqlcmd =~ s/XXX/$t/;
        $rc = $dbh->do($sqlcmd);
        if ($rc < 0) {
            die("Failed to create table $t\n");
        }
    }
}


main();
exit(0);
