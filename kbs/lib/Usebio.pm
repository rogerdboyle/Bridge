# This is the support routine used to
# create an Ebu format xml file for the
# new pay to play scheme. Its mostly pointless
# me writing this as our club is going to disaffiliate
# but I'm keen to fiddle with an AUTOLOAD class

# $Id: Usebio.pm 741 2011-07-05 09:11:32Z Root $

# This is Copyright 2009 Paul Haffenden

###############
package Usebio;
###############
use strict;
use warnings;
use Encode;
use IO::File;
use Conf;
use Sdate;
use Xmlgen;

our($version) = "1.0";

our(@ISA) = qw(Xmlgen);
our(@Validtags) = qw(
  USEBIO
  CLUB
  CLUB_NAME
  EVENT
  FULL_NAME
  EMAIL
  TELEPHONE
  WINNER_TYPE
  MASTER_POINT_SCALE
  MASTER_POINT_TYPE
  SESSION_COUNT
  SECTION_COUNT
  P2P_CHARGE_RATE
  MPS_AWARDED_FLAG
  CONTACT
  PARTICIPANTS
  PAIR
  PAIR_NUMBER
  PERCENTAGE
  PLACE
  MASTER_POINTS_AWARDED
  PLAYER
  PLAYER_NAME
  NATIONAL_ID_NUMBER
  BOARD
  BOARD_NUMBER
  NS_PAIR_NUMBER
  EW_PAIR_NUMBER
  SCORE
  NS_MATCH_POINTS
  EW_MATCH_POINTS
  TRAVELLER_LINE
  PROGRAM_NAME
  PROGRAM_VERSION
  CLUB_ID_NUMBER
  DATE
  NOTES
);

sub new
{
    my($class) = shift();
    my($flat) = @_;
    return $class->SUPER::new(\@Validtags,
     qq/<!DOCTYPE USEBIO SYSTEM "usebio_v1_0.dtd">/,
     $version, $flat);
}

sub generate
{
    my($me) = shift();
    my($file, $sp, $trs, $single, $anon) = @_;

    # $file is the session id, normally YYYYMMDD.
    # is the position table.
    # $trs is the hash of the travllers.
    # $single provides the player names.
    # $anon requests that we don't generate player info.

    # Lets get started.
    $me->usebio({Version => "1.0"});
    $me->club();
    $me->club_id_number0($Ecats::clubebunumber);
    $me->club_();

    # Now the event.
    $me->event({EVENT_TYPE => "MP_PAIRS"});
    # Plop in the program name and version
    my($year, $month, $day) = splitdate($file);
    $me->date0("$day/$month/$year");
    # Now do the participants
    $me->participants();
    my($outer, $inner);
    my($playerlist) = [];
    foreach $outer (@{$sp->{array}}) {
        foreach $inner (@$outer) {
            push(@$playerlist, $inner);
        }
    }
    # Now sort the play list by name.
    $playerlist = [ sort( { $a->{matchpair} <=> $b->{matchpair} }
      @$playerlist) ];

    foreach $inner (@$playerlist) {
        $me->pair();
        my($master) = $inner->{master};
        if ($master) {
            $me->master_points_awarded0($master);
        }
        # If we don't include the NGS/travellers, then
        # the match pair is useless
        if ($Ebu::enable_ngs) {
            $me->pair_number0(convert_pairno($inner->{matchpair}));
        }
        my(@players) = $single->break($inner->{pair});
        my($p);
        foreach $p (@players) {
            $me->player();
            my($idstr) = $single->refnum($p);
            if (!$idstr) {
                # this is the magic 'guest' number specifed
                # by the EBU.
                $idstr = "88888888";
            }
            $me->national_id_number0($idstr);
            $me->player_();
        }
        $me->pair_();
    }
    $me->participants_();
    if ($Ebu::enable_ngs) {
        my($bn);
        my($top) = scalar(@{$trs->boards()});
        for ($bn = 1; $bn <= $top; $bn++) {
            my($travs) = $trs->boards()->[$bn - 1];
            if (defined($travs)) {
                $me->board();
                $me->board_number0($bn);
                my($t);
                foreach $t (@$travs) {
                    $me->traveller_line();
                    $me->ns_pair_number0(convert_pairno($t->n()));
                    $me->ew_pair_number0(convert_pairno($t->e()));
                    $me->ns_match_points0($t->nsp());
                    $me->ew_match_points0($t->ewp());
                    $me->traveller_line_();
                }
                $me->board_();
            }
        }
    }
    $me->event_();
    $me->usebio_();

    # Write the file, using the club name, convert spaces into '-'
    my($fh) = IO::File->new();
    my($fname) = $Conf::Club;
    # turn spaces into dash.
    $fname =~ s/ /-/g;
    my($fileyear) = substr($year, 2);

    $fname .= "_$fileyear$month${day}_.XML";
    if (!$fh->open($fname, ">:encoding(utf8)")) {
        die("I've failed to open the $fname file for writing $!\n");
    }
    $fh->print($me->_retstr());
    $fh->close();
}

# Convert the pair number into a session/pair no combo.
our($pair_no_conv) = [
  "i",
  "ii",
  "iii",
  "iv",
  "v",
  "vi",
  "vii",
  "viii",
  "ix",
  "x",
  "xi",
  "xii",
  "xiii",
  "xiv",
  "xv",
  "xvi",
  "xvii",
  "xviii",
  "xix",
  "xx",
  "xxi",
  "xxii",
  "xxiii",
  "xxiv",
  "xxv",
  "xxvi",
  "xxvii",
  "xxviii",
  "xxix",
  "xxx",
  "xxxi",
  "xxxii",
  "xxxiii",
  "xxxiv",
  "xxxv",
  "xxxvi",
  "xxxvii",
  "xxxviii",
  "xxxix",
  "xxxx",
];
sub convert_pairno
{
    my($pn, $session) = @_;
    if (!defined($session)) {
        $session = 1;
    }
    return "$session" . "-" . $pair_no_conv->[$pn - 1];
}


1;

