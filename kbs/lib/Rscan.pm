#
# A file to scan the results directories.

##############
package Rscan;
##############



use strict;
use warnings;

use Scorepositions;
use Sql;

sub new
{
    my($class) = shift();
    my($resdir, $sdate, $edate, $obj) = @_;
    my($self) = {};
    $self->{resdir} = $resdir;
    $self->{sdate} = $sdate;
    $self->{edate} = $edate;
    $self->{obj} = $obj;
    bless($self, $class);
    Sql->GetHandle($Conf::Dbname);
    return $self;
}

sub scan
{
    my($self) = shift();

    my($sdate) = $self->{sdate};
    my($edate) = $self->{edate};
    my($resdir) = $self->{resdir};
    my($obj) = $self->{obj};

#    print("Start $sdate end date $edate\n");

    my($files) = Sql->keys(Sql::SCORE);
    my($file);
    my(@sps);
    my($sp);
    my($lowdate) = $edate;
    my($lowdatestr);

    foreach $file (@$files) {
        # basename it
        my($dateext);
        ($dateext) = $file =~ m/^(\d\d\d\d\d\d\d\d)/;
        if (!defined($dateext)) {
            print("Bad format, excluding ($dateext)\n");
        }
        if ($dateext <= $sdate) {
            next;
        }
        if ($dateext > $edate) {
            next;
        }
        if ($dateext < $lowdate) {
            $lowdate = $dateext;
        }
        next if !$obj->filename($file);

        $sp = Scorepositions->new();
        $sp->load($file);
        $obj->load($sp);
        my($outer);
        my($pent);
        foreach $outer (@{$sp->{array}}) {
            $obj->startinner($outer);
            foreach $pent (@$outer) {
                $obj->entry($pent);
            }
            $obj->endinner(scalar(@$outer));
        }
        $obj->endfilename(scalar(@{$sp->{array}}));
    }
    $obj->end();
}
1;
