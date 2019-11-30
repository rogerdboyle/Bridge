#
# Store all the info about a movement.
# $Id: Trav.pm 657 2011-02-15 15:41:33Z paulh $


###################
package Move::Trav;
###################

# This represents a traveller for a board (or in our case
# a set of boards. We maintain two structures, a
# hash of all the entry lines for a traveller, and
# the same data in an array. We need the array
# to store the order in which that pair entries
# appear on the travellers.
# The hash key is the north pair number.

use strict;
use warnings;

sub new
{
    my($class) = shift();
    my($self) = {};

    $self->{nhash} = {};
    $self->{ehash} = {};
    $self->{array} = [];

    bless($self, $class);
    return ($self);
}

# Return the hash view of the data.
sub get_nhash
{
    my($self) = shift();
    return ($self->{nhash});
}

sub get_ehash
{
    my($self) = shift();
    return ($self->{ehash});
}


sub get_array
{
    my($self) = shift();
    return ($self->{array});
}

# Checks if we can add this pair entry.
# Return a error string if we can't
sub canadd
{
    my($self) = shift();
    my($ele) = @_;
    my($n) = $ele->{n};
    my($e) = $ele->{e};

    foreach my $hashname ("nhash", "ehash") {
	foreach my $key ($n, $e) {
	    if (exists($self->{$hashname}->{$key})) {
		my($val) = $self->{$hashname}->{$key};
		return ("$n v $e duplicates entry $val->{n} v $val->{e}");
	    }
	}
	
    }
    return ("");
}

# Add an entry
sub add
{
    my($self) = shift();
    my($ele) = @_;

    $self->{nhash}->{$ele->{n}} = $ele;
    $self->{ehash}->{$ele->{e}} = $ele;
    push(@{$self->{array}}, $ele);
}

1;
