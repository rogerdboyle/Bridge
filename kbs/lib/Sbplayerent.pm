use strict;
use warnings;


####################
package Sbplayerent;
####################


sub new
{
    my($class) = shift;
    my($row) = @_;

    bless($row, $class);
    return $row;
}

sub sname
{
    my($self) = shift();
    return $self->[1];
}

sub cname
{
    my($self) = shift();
    return $self->[0];
}

sub ebuno
{
    my($self) = shift();
    return $self->[6];
}

sub key
{
    my($self) = shift();
    return uc($self->sname());
}


sub fullkey
{

    my($self) = shift();
    return uc($self->sname()) . "|" . uc($self->cname());
}


sub makekey
{
    my($class) = shift();
    my($key) = @_;
    return uc($key);
}
1;

