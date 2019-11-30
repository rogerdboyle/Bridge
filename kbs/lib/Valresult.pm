# Class to validate a traveller line input string.
# This only gets called when the parsing fails,
# and this is called to report on why the parse has
# failed. Helping the user work out what to correct.

##################
package Valresult;
##################

use strict;
use warnings;

# Implemented as a state machine, the engine will be is a
# partiuclar state which defines a set of characters that
# are allowed to be the next character in the sequence.
# When a state is matched a routine is called that checks that
# the next char matches, and then based on that char,
# what the next state is. As each char is matched it is removed
# from the input string.

use constant STATE => 0;
use constant LIST => 1;
use constant MESSAGE => 2;

use constant PAT => 0;
use constant NEWSTATE => 1;


use constant EFINISH     => 64;
use constant START       => 0;
use constant STARTPAIR   => 1;
use constant PRETWOPAIR  => 2;
use constant TWOPAIR     => 3;
use constant PRECONTRACT => 4;
use constant CONTRACT    => 5;
use constant PRESCORE    => 21;
use constant SCORE       => 6   + EFINISH;
use constant SPECIAL     => 7;
use constant SPECIAL1    => 8;
use constant SCORECON    => 9   + EFINISH;
use constant CON         => 10;
use constant UNDER       => 11;
use constant PREOVER     => 12;
use constant OVER        => 13;
use constant DOUBLE      => 14;
use constant REDOUBLE    => 15;
use constant PREBY       => 16;
use constant BY          => 17  + EFINISH;
use constant PRELEAD     => 18;
use constant LEADRANK    => 19;
use constant FINISH      => 20;


our($state_lookup) =
  {
   START       => "START",
   STARTPAIR   => "STARTPAIR",
   PRETWOPAIR  => "PRETWOPAIR",
   TWOPAIR     => "TWOPAIT",
   PRECONTRACT => "PRECONTRACT",
   CONTRACT    => "CONTRACT",
   SCORE       => "SCORE",
   PRESCORE    => "PRESCORE",
   SPECIAL     => "SPECIAL",
   SPECIAL1    => "SPECIAL1",
   SCORECON    => "SCORECON",
   CON         => "CON",
   UNDER       => "UNDER",
   PREOVER     => "PREOVER",
   OVER        => "OVER",
   DOUBLE      => "DOUBLE",
   REDOUBLE    => "REDOUBLE",
   PREBY       => "PREBY",
   BY          => "BY",
   PRELEAD     => "PRELEAD",
   LEADRANK    => "LEADRANK",
   FINISH      => "FINISH",
};

use constant PAT_SPACE         => qr/\s/;
use constant PAT_DIGIT         => qr/\d/;
use constant PAT_MINUS         => qr/[-]/;
use constant PAT_PLUS          => qr/[+]/;
use constant PAT_STAR          => qr/[*]/;
use constant PAT_PASS          => qr/[pP]/;
use constant PAT_IGNORE        => qr/#/;
use constant PAT_BY            => qr/[nsewNSEW]/;
use constant PAT_CONTRACT_SUIT => qr/[cdhsnCDHSN]/;
use constant PAT_LEAD_RANK     => qr/[2-9tjqkaTJQKAxX]/;
use constant PAT_LEAD_SUIT     => qr/[cdhsCDHS]/;
use constant PAT_AVERAGE       => qr/[aA]/;
use constant PAT_AV_CHAR       => qr/[+-=]/;


sub new
{
    my($class) = shift();
    my($instr) = @_;
    my($it);
    my($self) = {};
    $self->{instr} = $instr;
    $self->{map} = {};
    bless($self, $class);
    return ($self);
}

sub setup
{
    my($self) = shift();
    my($aref);


    $aref = [];
    addstate($aref, START);
    addpat($aref, PAT_SPACE, START);
    addpat($aref, PAT_DIGIT, STARTPAIR);
    addmess($aref, "Looking for space or digit");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, STARTPAIR);
    addpat($aref, PAT_SPACE, PRETWOPAIR);
    addpat($aref, PAT_DIGIT, STARTPAIR);
    addmess($aref, "Looking for space to indicate the end of the first pair or extra digit of pair number");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, PRETWOPAIR);
    addpat($aref, PAT_SPACE, PRETWOPAIR);
    addpat($aref, PAT_DIGIT, TWOPAIR);
    addmess($aref, "Looking for spaces between pairs, or first digit of second pair");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, TWOPAIR);
    addpat($aref, PAT_SPACE, PRECONTRACT);
    addpat($aref, PAT_DIGIT, TWOPAIR);
    addmess($aref, "Looking for space to indicate the end of the second pair or extra digit of pair number");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, PRECONTRACT);
    addpat($aref, PAT_SPACE, PRECONTRACT);
    addpat($aref, PAT_DIGIT, SCORECON);
    addpat($aref, PAT_MINUS, PRESCORE);
    addpat($aref, PAT_PASS, FINISH);
    addpat($aref, PAT_IGNORE, FINISH);
    addpat($aref, PAT_AVERAGE, SPECIAL);
    addmess($aref, "Looking for the score, contract or special. One of (-0123456789pPaA#)");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, PRESCORE);
    addpat($aref, PAT_DIGIT, SCORE);
    addmess($aref, "Looking for a digit as part of a negative score");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, SCORECON);
    addpat($aref, PAT_DIGIT, SCORE);
    addpat($aref, PAT_CONTRACT_SUIT, CON);
    addmess($aref, "Looking for more of the score, or the contract suit");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, SCORE);
    addpat($aref, PAT_DIGIT, SCORE);
    addmess($aref, "Only looking for more of the score");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, SPECIAL);
    addpat($aref, PAT_AV_CHAR, SPECIAL1);
    addmess($aref, "Looking for an average modifier. One of (-+=)");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, CON);
    addpat($aref, PAT_MINUS, UNDER);
    addpat($aref, PAT_PLUS, PREOVER);
    addpat($aref, PAT_DIGIT, OVER);
    addpat($aref, PAT_STAR, DOUBLE);
    addpat($aref, PAT_SPACE, PREBY);
    addpat($aref, PAT_BY, BY);
    addmess($aref, "Looking for an average modifier. One of (-+=)");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, SPECIAL1);
    addpat($aref, PAT_AV_CHAR, FINISH);
    addmess($aref, "Looking for last average modifier. One of (-+=)");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, UNDER);
    addpat($aref, PAT_DIGIT, OVER);
    addmess($aref, "Looking for a digit for the undertricks.");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, PREOVER);
    addpat($aref, PAT_DIGIT, OVER);
    addmess($aref, "Looking for a digit for the overtricks.");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, OVER);
    addpat($aref, PAT_DIGIT, OVER);
    addpat($aref, PAT_SPACE, PREBY);
    addpat($aref, PAT_BY, BY);
    addmess($aref, "Looking for a digit for under/overtricks or a space or by field");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, DOUBLE);
    addpat($aref, PAT_MINUS, UNDER);
    addpat($aref, PAT_PLUS, PREOVER);
    addpat($aref, PAT_DIGIT, OVER);
    addpat($aref, PAT_STAR, REDOUBLE);
    addpat($aref, PAT_SPACE, PREBY);
    addpat($aref, PAT_BY, BY);
    addmess($aref, "Looking for a digit for under/overtricks, * for a redouble or a space or by field");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, PREBY);
    addpat($aref, PAT_SPACE, PREBY);
    addpat($aref, PAT_BY, BY);
    addmess($aref, "Looking for more spaces or the by field");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, REDOUBLE);
    addpat($aref, PAT_MINUS, UNDER);
    addpat($aref, PAT_PLUS, PREOVER);
    addpat($aref, PAT_DIGIT, OVER);
    addpat($aref, PAT_SPACE, PREBY);
    addpat($aref, PAT_BY, BY);
    addmess($aref, "Looking for a digit for under/overtricks or a space or by field");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, BY);
    addpat($aref, PAT_SPACE, PRELEAD);
    addpat($aref, PAT_LEAD_RANK, LEADRANK);
    addmess($aref, "Looking for a space or the lead rank");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, PRELEAD);
    addpat($aref, PAT_SPACE, PRELEAD);
    addpat($aref, PAT_LEAD_RANK, LEADRANK);
    addmess($aref, "Looking for a space or lead rank");
    $self->addmap($aref);

    $aref = [];
    addstate($aref, LEADRANK);
    addpat($aref, PAT_LEAD_SUIT, FINISH);
    addmess($aref, "Looking for a lead suit");
    $self->addmap($aref);


    $aref = [];
    addstate($aref, FINISH);
    addmess($aref, "Extra unneeded input detected");
    $self->addmap($aref);

}

sub addstate
{
    my($aref, $state) = @_;
    $aref->[STATE] = $state;
}

sub addpat
{
    my($aref, $pat, $newstate) = @_;
    push(@{$aref->[LIST]}, [ $pat, $newstate ]);
}

sub addmess
{
    my($aref, $mess) = @_;
    $aref->[MESSAGE] = $mess;
}

sub addmap
{
    my($self) = shift();
    my($aref) = @_;
    my($map) = $self->{map};

    if (exists($map->{$aref->[STATE]})) {
        die("The input list has the same keys specified twice $aref->[STATE]\n");
    }
    $map->{$aref->[STATE]} = $aref;
}

sub run
{
    my($self) = shift();

    my($map) = $self->{map};
    my($state) = START;
    my($ind) = 0;
    my($len) = length($self->{instr});


    $self->{message} = "";
    $self->{matched} = "";
    $self->{state} = $state;
    $self->{char} = "";
    $self->{engine} = [];
    my($condigit) = "";
 CHAR:
    for ($ind = 0; $ind < $len; $ind++) {
        if (!exists($map->{$state})) {
            die("I don't have a map entry for $state\n");
        }
        my($it) = $map->{$state};
        my($i);
        my($ch) = substr($self->{instr}, $ind, 1);

        $self->{char} = $ch;
        push(@{$self->{engine}}, [ $state, $ch ]);


        my($ok) = 0;
        foreach $i (@{$it->[LIST]}) {
            if ($ch =~ $i->[PAT]) {
                $state = $i->[NEWSTATE];
                $self->{state} = $state;

                if ($state == CON) {
                    if ($condigit !~ m/[1-7]/) {
                        $ind--;
                        $self->{char} = $condigit;
                        last;
                    }
                }

                if ($state == SCORECON) {
                    $condigit = $ch;
                }
                $ok = 1;
                next CHAR;
            }
        }
        if (!$ok) {
            $self->{matched} = substr($self->{instr}, 0, $ind);
            $self->{message} = $it->[MESSAGE];
            return 1;
        }
    }
    if (($state != FINISH) && (($state & EFINISH) == 0)) {
        $self->{matched} = substr($self->{instr}, 0, $ind);
        $self->{message} = "There is missing input";
        return 2;
    }
    return (0);
}
1;
