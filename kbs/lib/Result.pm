# $Id: Result.pm 1332 2014-08-09 13:18:52Z root $
# Copyright (c) 2007 Paul Haffenden. All rights reserved.


###############
package Result;
###############
use strict;
use warnings;

use Score;
use Valresult;

our($c_pair) = qr(\d+);
our($c_level) = qr([1-7]);
our($c_suit) = qr([cCdDhHsSnN]);
our($c_double) = qr(\*{0,2});
our($c_result) = qr(-?\d*);
our($c_by)     = qr([nNeEsSwW]);
our($c_rank)   = qr([aAkKqQjJtT2-9xX]);
our($c_lsuit)   = qr([cCdDhHsS]);
our($c_specialstr) = qr([pP#]|[aA][+-=]{0,2});


our($c_pairpre) = qr/($c_pair)\s+($c_pair)\s+/;

our($c_full) = qr/$c_pairpre($c_level$c_suit$c_double$c_result)\s*($c_by)\s*($c_rank$c_lsuit)?$/;

our($c_special) = qr/$c_pairpre($c_specialstr)$/;
our($c_score) = qr/$c_pairpre(-?\d+)$/;

sub new
{
    my($class) = shift();

    my($instr, $nsvul, $ewvul, $infoptr, $div10) = @_;
    my($n, $e, $con, $by, $lead);
    my($vul);
    my($score);
    my($ptsmul);
    my($special);
    my($contxt);
    my($points);
    my($ignored);
    my($averaged);
    my($passedout);
    my($nsaverage);
    my($ewaverage);
    my($self)  = {};

    bless($self, $class);

    # Indicate the 'special' results.
    $ignored = 0;
    $averaged = 0;
    $passedout = 0;
    $nsaverage = 0;
    $ewaverage = 0;

    ($n, $e, $con) = $instr =~ $c_score;
    if (!defined($n)) {
        ($n, $e, $con) = $instr =~ $c_special;
        if (!defined($n)) {
            ($n, $e, $con, $by, $lead) = $instr =~ $c_full;
            $special = 0;
        } else {
            $special = 1;
            $con = uc($con);
            $by = "";
            $lead = "";
        }
    } else {
        if (defined($div10) && $div10) {
            # The user is dropping the trailing '0' off of each entry
            $instr .= "0";
            $con *= 10;
        }
        # Here we need to check that the points score entered
        # is valid for the current vulnerabilities
        if (validscore($con, $nsvul, $ewvul)) {
            $special = 0;
            $points = $con;
            $con = "";
            $by = "";
            $lead = "";
        } else {
            $$infoptr = "That is not a valid score ($con) for this board";
            return undef;
        }
    }

    if (!defined($n)) {
        my($pc) = Valresult->new($instr);
        $pc->setup();
        my($ret) = $pc->run();
        if ($ret > 0) {
            my($msg) = qq/Parsed "$pc->{matched}"./;
            if ($ret > 1) {
                $msg .= " More input needed";
            } else {
                $msg .= qq/ Bad character "$pc->{char}"/;
            }
            $$infoptr = $msg;
        } else {
            $$infoptr = "The parse decode didn't spot the error!";
        }
        return undef;
    } else {
        $by = uc($by);
        if (defined($lead)) {
            $lead = uc($lead);
        } else {
            $lead = "";
        }
        $$infoptr = "Parse ok $n v $e";
    }
    if ($special == 0) {
        # $by is null if we just entered the points.
        if ($by) {
            if (($by eq "N") || ($by eq "S")) {
                $vul = $nsvul;
                $ptsmul = 1;
            } else {
                $vul = $ewvul;
                $ptsmul = -1;
            }
            $score = Score->new($con, $vul);
            if (ref($score)) {
                $$infoptr = "Points: " . $score->points();
            } else {
                $$infoptr = "Failed to parse the contract string $con ($instr)";
                return (undef);
            }
            $points = $score->points() * $ptsmul;
        }
        $self->{special} = "";
    } else {
        $self->{special} = $con; # Special scoring required
        $points = 0;
        my($first) = substr($con, 0, 1);
        if ($first eq "#") {
            $ignored = 1;
        } elsif ($first eq "P") {
            $passedout = 1;
        } elsif ($first eq "A") {
            $averaged = 1;
            my(@avs) = Result->averagestring($con, 1);
            $nsaverage = $avs[0];
            $ewaverage = $avs[1];
        }
    }
    $self->{n} = $n;
    $self->{e} = $e;
    $self->{by} = $by;
    $self->{lead} = $lead;
    $self->{score} = $score;
    $self->{nsp} = 0;
    $self->{ewp} = 0;
    $self->{instr} = $instr;
    $self->{points} = $points;
    $self->{passedout} = $passedout;
    $self->{ignored} = $ignored;
    $self->{nsaverage} = $nsaverage;
    $self->{ewaverage} = $ewaverage;
    $self->{averaged} = $averaged;
    if ($special) {
        if ($special eq "P") {
            $contxt = "Passed";
        } else {
            $contxt = $self->{special};
        }
    } else {
        if ($by) {
            $contxt = $score->level() . $score->suit() . $score->double();
            if ($score->contricks()) {
                $contxt .= $score->contricks();
            }
        } else {
            $contxt = "";
        }
    }
    $self->{contxt} = $contxt;
    return ($self);
}

sub n
{
    my($self) = shift();
    return ($self->{n});
}
sub e
{
    my($self) = shift();
    return ($self->{e});
}
sub by
{
    my($self) = shift();
    return ($self->{by});
}
sub lead
{
    my($self) = shift();
    return ($self->{lead});
}
sub score
{
    my($self) = shift();
    return ($self->{score});
}

# Traveller contract output string
sub contxt
{
    my($self) = shift();
    return ($self->{contxt});
}

sub special
{
    my($self) = shift();
    return ($self->{special});
}

sub ignored
{
    my($self) = shift();
    return ($self->{ignored});
}

sub passedout
{
    my($self) = shift();
    return ($self->{passedout});
}

sub averaged
{
    my($self) = shift();
    return ($self->{averaged});
}

sub nsaverage
{
    my($self) = shift();
    return ($self->{nsaverage});
}

sub ewaverage
{
    my($self) = shift();
    return ($self->{ewaverage});
}

sub instr
{
    my($self) = shift();
    return ($self->{instr});
}

# This is what is output at the bottom of the display,
# not in the traveller output.
sub condisplay
{
    my($self) = shift();
    my($txt);


    if ($self->{special}) {
        return ($self->{special});
    }
    if ($self->{by}) {
        my($score) = $self->{score};

        $txt = $score->{level} . $score->suit();
        if ($score->contricks()) {
            $txt .= $score->contricks();
        }
    } else {
        $txt = $self->{points};
    }
    return ($txt);
}

sub points
{
    my($self) = shift();
    return ($self->{points});
}

sub nsp
{
    my($self) = shift();
    return ($self->{nsp});
}

sub ewp
{
    my($self) = shift();
    return ($self->{ewp});
}
sub tricks
{
    my($self) = shift();
    if (!defined($self->{score})) {
        return ("");
    } else {
        return ($self->{score}->{tricks});
    }
}

sub dblstr
{
    my($self) = shift();
    return ($self->{score}->{doublestr});
}

sub resetpts
{
    my($self) = shift();
    $self->{nsp} = 0;
    $self->{ewp} = 0;
}


sub calculatescores
{
    my($class) = shift();
    my($hr) = @_;
    my($ntot, $etot);

    my($out, $in);

    foreach $out (@$hr) {
        $ntot = 0;
        $etot = 0;
        next if $out->averaged();
        next if $out->ignored();

        foreach $in (@$hr) {
            next if $out == $in;
            next if $in->averaged();
            next if $in->ignored();

            if ($out->{points} > $in->{points}) {
                $ntot += 2;
            } elsif ($out->{points} == $in->{points}) {
                $ntot += 1;
                $etot += 1;
            } else {
                $etot += 2;
            }
        }
        $out->{nsp} = $ntot;
        $out->{ewp} = $etot;
    }
}

sub resetscore
{
    my($class) = shift();
    my($hr) = @_;
    my($val, @vals);

    @vals = values(%$hr);
    foreach $val (@vals) {
        $val->resetpts();
    }
}

# NOT a method.
# Check that the score in valid given the current board
# vulnerability.
# return true for valid, 0 for a problem.

# We calculate all the valid scores once (if needed) for
# all vulnerabilities.
our($validmap);
sub validscore
{
    my($score, $nsvul, $ewvul) = @_;

    if (!defined($validmap)) {
        createvalidmap();
    }
    my($ind) = 0;
    if ($nsvul) {
        $ind++;
    }
    if ($ewvul) {
        $ind += 2;
    }
    if (exists($validmap->[$ind]->{$score})) {
        return 1;
    }
    return 0;
}

sub createvalidmap
{
    my($posv, $posn, $negv, $negn);
    $posv = [];
    $posn = [];
    $negv = [];
    $negn = [];
    poss($posv, 1);
    poss($posn, 0);
    neg($negv, 1);
    neg($negn, 0);

    # Create the hashes from the temp data structures.

    # Both ns and ew are non-vulnerable
    $validmap->[0] = {
                      %{$posn->[0]},
                      %{$negn->[0]},

                      %{$posn->[1]},
                      %{$negn->[1]}
                     };
    # ns are vulnerable, ew not.
    $validmap->[1] = {
                      %{$posv->[0]},
                      %{$negv->[0]},
                      %{$posn->[1]},
                      %{$negn->[1]},
                     };
    # ns are non vulnerable, ew are.
    $validmap->[2] = {
                      %{$posn->[0]},
                      %{$negn->[0]},
                      %{$posv->[1]},
                      %{$negv->[1]},
                     };
    $validmap->[3] = {
                      %{$posv->[0]},
                      %{$negv->[0]},

                      %{$posv->[1]},
                      %{$negv->[1]},
                     };
    return $validmap;
}




# Do the positive scores.
sub poss
{
    my($arr, $vul) = @_;

    my($level);
    my($suit);
    my($top);
    my($over);
    my($pen);
    my($instr);
    my($score);

    # NS scores.
    $arr->[0] = {};
    # EW scores.
    $arr->[1] = {};
    foreach $level (1, 2, 3, 4, 5, 6, 7) {
        foreach $suit ("C", "H", "N") {
            foreach $pen ("", "*", "**") {
                my($top) = 7 - $level;
                for ($over = 0; $over <= $top; $over++) {
                    $instr = "$level$suit$pen";

                    if ($over) {
                        $instr .= "$over";
                    }
                    $score = Score->new($instr, $vul);
                    $arr->[0]->{$score->points()} = 1;
                    $arr->[1]->{$score->points() * -1} = 1;
                }
            }
        }
    }
}

sub neg
{
    my($arr, $vul) = @_;
    my($under);
    my($pen);
    my($base) = "7n";
    my($score);

    $arr->[0] = {};
    $arr->[1] = {};
    for ($under = 1; $under < 14; $under++) {
        foreach $pen ("", "*", "**") {
            $score = Score->new("$base$pen-$under", $vul);
            $arr->[0]->{$score->points()} = 1;
            $arr->[1]->{$score->points() * -1} = 1;
        }
    }
}

# this is a class method.
sub averagestring
{
    my($class) = shift();
    my($str, $plain) = @_;
    my(@reta);
    my($reta);
    my($ind);
    if ($str eq "A") {
        $str = "A==";
    }

    $reta = "A";
    foreach $ind ( 1, 2 ) {
        my($c) = substr($str, $ind, 1);
        if ($c eq "=") {
            if ($plain) {
                push(@reta, 50);
            } else {
                push(@reta, "50%");
            }
            $reta .= "50";
        } elsif ($c eq "+") {
            if ($plain) {
                push(@reta, 60);
            } else {
                push(@reta, "60%");
            }
            $reta .= "60";
        } elsif ($c eq "-") {
            if ($plain) {
                push(@reta, 40);
            } else {
                push(@reta, "40%");
            }
            $reta .= "40";
        } else {
            push(@reta, "??%");
            $reta .= "??";
        }
    }
    if (wantarray) {
        return (@reta);
    } else {
        return ($reta);
    }
}

1;
