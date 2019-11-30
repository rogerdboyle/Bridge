# $Id: Confobj.pm 576 2010-07-25 10:44:24Z root $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.

# We create one of these, and then pass it around to all our
# callback routines, so they can diddle with the data.
# It is just a simple hash, you can call set to update
# a value, get to return a value, or getaddr, to return
# the reference to a variable.

################
package Confobj;
################

use strict;
use warnings;

sub new
{
      my($class) = shift();
      my($self) = {};
      my($myconf) = @_;
      if ($myconf) {
          # Copy it
          $self->{vhash} = {};
          %{$self->{vhash}} = %$myconf;
      } else {
          die("No conf specified\n");
      }
      bless($self, $class);
      return $self;
}

sub get
{
      my($self) = shift();
      my($key) = @_;

      if (!exists($self->{vhash}->{$key})) {
          die("The key ($key) passed to Confobj::get does not exist\n");
      }
      return ($self->{vhash}->{$key});
}

sub set
{
    my($self) = shift();
    my($key, $val) = @_;

    if (!exists($self->{vhash}->{$key})) {
        die("The key ($key) passed to Confobj::set does not exist\n");
    }
    $self->{vhash}->{$key} = $val;
}

sub getref
{
      my($self) = shift();
      my($key) = @_;

      if (!exists($self->{vhash}->{$key})) {
          die("The key ($key) passed to Confobj::getref does not exist\n");
      }
      return (\$self->{vhash}->{$key});
}
1;
