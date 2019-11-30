# $Id: Score.pm 836 2012-01-08 18:11:37Z phaff $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.


##############
package Score;
##############
use constant NT => 40;
use constant MAJOR => 30;
use constant MINOR => 20;
use integer;


sub new
{
    my($class) = shift();
    my($in, $vul) = @_;

    my($self) = {};
    my($level, $suit, $double, $redouble, $tricks);
    my($game, $slam, $over);
    my($insult);
    my($points);



    ($level, $suit, $double, $tricks) = $in =~
      m/([1-7])([nNHhCcSsDd])(\*{0,2})(([+-]?\d+){0,1})$/;

    if (!defined($level)) {
        return (undef);
    }

    if (!$tricks) {
        $tricks = 0;
    }

    $redouble = 0;
    if (length($double) == 2) {
        $redouble = 1;
        $double = 0;
    } elsif (length($double) == 1) {
        $double = 1;
    } else {
        $double = 0;
    }
    # Normalise the suit.
    $suit = uc($suit);
    $game = 0;
    $slam = 0;
    $over = 0;
    $insult = 0;

    # Did we make the contract?
    if ($tricks >= 0) {
        if ($tricks > 0) {
            # Add the + symbol back
            $tricks = "+" . ( $tricks + 0 );
        }
        # Calculate the points for the bid.
        if ($suit eq "N") {
            $points = NT;
            $points += ($level - 1) * MAJOR;
        } elsif (($suit eq "H") || ($suit eq "S")) {
            $points = $level * MAJOR;
        } else {
            $points = $level * MINOR;
        }

        if ($redouble) {
            $points *= 4;
            $insult = 100; # Insult
        } elsif ($double) {
            $points *= 2;
            $insult = 50;  # Insult
        }

        # Calculate game bonus;
        if ($points >= 100) {
            if ($vul) {
                $game = 500;
            } else {
                $game = 300;
            }
        } else {
            $game = 50;  # Part score bonus
        }
        if ($level == 7) {
            if ($vul) {
                $slam = 1500;
            } else {
                $slam = 1000;
            }
        } elsif ($level == 6) {
            if ($vul) {
                $slam = 750;
            } else {
                $slam = 500;
            }
        }

        # Now any over tricks.
        if ($redouble) {
            if ($vul) {
                $over = 400 * $tricks;
            } else {
                $over = 200 * $tricks;
            }
        } elsif ($double) {
            if ($vul) {
                $over = 200 * $tricks;
            } else {
                $over = 100 * $tricks;
            }
        } else {
            if (($suit eq "C") || ($suit eq "D")) {
                $over = MINOR * $tricks;
            } else {
                $over = MAJOR * $tricks;
            }
        }
    } else {
        # Failure....
        my($td) = $tricks * -1;
        my($first, $t3, $sub, $t3t, $subt);
        $t3 = 0;
        $sub = 0;
        if ($redouble) {
            if ($vul) {
                $first = 400;
                $t3 = 600;
                $sub = 600;
            } else {
                $first = 200;
                $t3 = 400;
                $sub = 600;
            }
        } elsif ($double) {
            if ($vul) {
                $first = 200;
                $t3 = 300;
                $sub = 300;
            } else {
                $first = 100;
                $t3 = 200;
                $sub = 300;
            }
        } else {
            if ($vul) {
                $first = 100;
                $t3 = 100;
                $sub = 100;
            } else {
                $first = 50;
                $t3 = 50;
                $sub = 50;
            }
        }
        #Calculate the number of 2 and 3 tricks,
        # and the subsequent tricks
        $t3t = $td - 1;
        if ($t3t > 2) {
            $subt = $t3t - 2;
            $t3t = 2;
        } else {
            $subt = 0;
        }
        $points = $first + ($t3 * $t3t) + ($sub * $subt);
        $points *= -1;
    }
                
    if ($redouble) {
        $self->{doublestr} = "**";
    } elsif ($double) {
        $self->{doublestr} = "*";
    } else {
        $self->{doublestr} = "";
    }
    $self->{in} = $in;
    $self->{level} = $level;
    $self->{suit} = $suit;
    $self->{points} = $points + $game + $slam  + $over + $insult;
    $self->{tricks} = $level + $tricks + 6;
    $self->{contricks} = $tricks;

    bless($self, $class);
    return ($self);
}
sub instr
{
    my($self) = shift();
    return ($self->{in});
}
sub level
{
    my($self) = shift();
    return ($self->{level});
}
sub suit
{
    my($self) = shift();
    return ($self->{suit});
}
sub points
{
    my($self) = shift();
    return ($self->{points});
}
sub contricks
{
    my($self) = shift();
    return ($self->{contricks});
}
sub tricks
{
    my($self) = shift();
    return ($self->{tricks});
}
sub double
{
    my($self) = shift();
    return ($self->{doublestr});
}

1;
