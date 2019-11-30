use strict;
use warnings;

use IO::File;

use Conf;
use Sql;




sub main
{
    my($ret) = Sql->GetHandle($Conf::Dbname);
    my($cmd) = shift(@ARGV);
    my($tbl) = shift(@ARGV);
    my($key) = shift(@ARGV);
    my($data);
    my($sqlcmd);
    my($sth);
    my($t);
    my($fh);

    if ($cmd eq "list") {
        $t = $Sql::revmap->{$tbl};
        if (!defined($t)) {
            die("I don't know that table $tbl. Only ", join(" ", keys(%$Sql::revmap)), "\n");
        }
        $data = Sql->keys($t);
        print(join("\n", @$data), "\n");
    } elsif ($cmd eq "cat") {
        $t = $Sql::revmap->{$tbl};
        if (!defined($t)) {
            die("I don't know that table $tbl. Only ", join(" ", keys(%$Sql::revmap)), "\n");
        }
        $data = Sql->load($t, $key);
        if (!defined($data)) {
            die("No key $key\n");
        }
        $fh = IO::File->new();
        if (!$fh->open($key, ">")) {
            die("Failed to open $key $!\n");
        }
        $fh->print($data);
        $fh->close();
    } elsif ($cmd eq "del") {
        $t = $Sql::revmap->{$tbl};
        $data = Sql->del($t, $key);
        if (!defined($data)) {
            die("The delete has failed\n");
        }
    } elsif ($cmd eq "display") {
        $t = $Sql::revmap->{$tbl};
        if (!defined($t)) {
            die("I don't know that table $tbl. Only ", join(" ", keys(%$Sql::revmap)), "\n");
        }
        $data = Sql->load($t, $key);
        print($data, "\n");
    } else {
        die("I don't grok your command '$cmd'\n");
    }
}


main();
exit(0);
