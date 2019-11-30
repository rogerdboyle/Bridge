use strict;
use warnings;


################
package Ebufile;
################


sub new
{
    my($class) = shift;
    my($row) = @_;

    bless($row, $class);
    return $row;
}

sub ebuno
{
    my($self) = shift();
    return $self->[0];
}

sub sname
{
    my($self) = shift();
    return $self->[2];
}

sub cname
{
    my($self) = shift();
    return $self->[1];
}

sub county
{
    my($self) = shift();
    return $self->[3];
}

sub loc
{
    my($self) = shift();
    return $self->[4];
}

sub key
{
    my($self) = shift();
    return Ebukeys->key($self->[2]);
}

sub fullkey
{

    my($self) = shift();
    return Ebukeys->full_key($self->[2]),($self->[1]);
}

sub print
{
    my($self) = shift();
    return ($self->sname() . " " . $self->cname() . " " . $self->loc() . " " . $self->ebuno());
}


sub makekey
{
    my($class) = shift();
    my($key) = @_;
    return uc($key);
}
1;

