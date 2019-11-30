
# $Id: Pairmapclient.pm 1644 2016-11-10 11:42:45Z phaff $
# Copyright (c) 2010 Paul Haffenden. All rights reserved.
######################
package Pairmapclient;
######################

use strict;
use warnings;

use IO::File;
use JSON;
use Tk;
use Tk::Pane;

use Conf;
use lib "lib";
use Setup;
use Single;
use Pairmap;
use Lastpairing;

my($donebut);
my($sel) = "**select**";
my($empty) = "Empty";
my($savename) = "pairmap.db";
my($lpfile) = "lastpair.txt";

our(@font) = (-font => "Times 7 bold");


sub main
{
    my($mw, $dir, $goodbye, $rwidth) = @_;

    my($single);
    my($ret);
    my(@ranges);
    my($current);
    my($pm);
    my($setup);
    my($lp);

    $mw->title("Enter player names");
    $current = [0, 0];
    $setup = Setup->new();
    $setup->load($dir);
    @ranges = $setup->range();

    $single = Single->new();
    # pass the 'ignore' inactive entries flag.
    $ret = $single->load("contact.csv");
    if ($ret) {
        die($ret, "\n");
    }

    $lp = Lastpairing->new();
    $lp->load($lpfile);

    my(@rmap);
    my(@lmap);

    my($left_fr);
    my($middle_fr);
    my($right_fr);
    my($bottom_fr);
    my($swidth);  # The height and width of the screen.
    my($sheight);
    my($adata) = {
                  dbuf => "",        # data buffer
                  sel => [],         # a list of possible seletions
                  defcol => undef,   # the default fore and background colours
                 };

    $sheight = $mw->screenheight();
    $swidth = $mw->screenwidth();

    # Bind the keyboard strokes.
    $mw->bind("<Key>", [\&key_pressed, Ev('K'), \@lmap, \@rmap, $current, $single, $adata, $lp]);

    $bottom_fr = $mw->Frame();
    $bottom_fr->pack(-side => "bottom");

    # Create and place the left frame.
    # Give the bottom frame 100 pixels.
    $left_fr = $mw->Scrolled('Frame',
                             -scrollbars => "ow",
                             -height => $sheight - 100,
                            );
    $left_fr->pack(-side => "left");

    $middle_fr = $mw->Frame(-width => 100);
    $middle_fr->pack(-side => "left");

    # Create and place the right frame,
    # Allow it to scroll left or right

    $right_fr = $mw->Scrolled('Frame',
                              -scrollbars => 'os',
                              -width => $swidth - 300,
                             );
    $right_fr->pack(-side => "left");


    $donebut = $bottom_fr->Button(@font, -text => "Done", -command =>
                                 [\&save, \@lmap, \@rmap, $single, $dir, $lp, $goodbye] );
    $donebut->pack();

    # Deal with the right frame first. We need a smallish font,
    # and all the candidates in order.

    my(@names); # an array of sorted names from the contact file
    my($name);
    my(@rbut);
    my($but);
    my($row, $col);
    my($maxcol);
    my($namelen);

    @names = $single->sorted();
    $row = 0;
    $col = 0;
    $maxcol = 28;
    $namelen = $single->maxnamelen();

    my($ind) = 0;
    foreach $name (@names) {
        my($fullname);

        $fullname = $name->sname() . " " . $name->cname();
        $but = $right_fr->Button(@font, -text => $fullname, -width => $namelen,
            -command => [\&rightbut, \@lmap, \@rmap,
          $current, $ind, $adata, $lp ]);
        $but->grid(-row => $row, -column => $col);

        if ($row >= ($maxcol - 1)) {
            $col++;
            $row = 0;
        } else {
            $row++;
        }
        # This maps the name element to the button.
        push(@rmap, [ $name, $but, $name->id(), $ind ]);
        $ind++;
    }

    # Now layout the left frame, which is a grid with 3 columns,
    # 1. the pair id used in the match.
    # 2. the first pair name
    # 3. the second pair name.
    # They start out all blank.
    my($pn);
    my($but2);
    $row = 0;

    my($ctbls);
    $ctbls = $setup->tables();
    # If we have the 'tables' field setup, then we can use
    # that to order our pairnumbers.
    if ($ctbls) {
        @ranges = ();
        foreach my $c (@$ctbls) {
            push(@ranges, $c->[0], $c->[1]);
        }
    }

    foreach $pn (@ranges) {
        # Create an entry for this pairmap.

        my($pntxt);
        my($mytext);

        if ($pn != 0) {
            $pntxt = $pn;
            $mytext = $empty;
        } else {
            $pntxt = "-";
            $mytext = "Missing";
        }
        $but = $left_fr->Button(@font, -text => $pntxt, -width => 4);
        $but->grid(-column => 0, -row => $row);

        $but = $left_fr->Button(@font, -text => $mytext, -width => $namelen,
                                -state => "disabled",
                                -command => [ \&leftbut, \@lmap, \@rmap, $current, $row, 0, $adata ]);
        $but->grid(-column => 1, -row => $row);

        if ($pn == 0) {
            $mytext = "Pair";
        }

        $but2 = $left_fr->Button(@font, -text => $mytext, -width => $namelen,
          -state => "disabled",
          -command => [ \&leftbut, \@lmap, \@rmap, $current, $row, 1, $adata ]);
        $but2->grid(-column => 2, -row => $row);
        push(@lmap, [$pn, $but, $but2, -1, -1 ]);
        $row++;
    }

    # Attempt to load any existing mapfile.
    $pm = Pairmap->new();
    if ($pm->load($dir)) {
        my($pn, $gid, $lele, $id0, $id1, $rele, $fullname);
    GID:
        while (($pn, $gid) = each(%$pm)) {
            foreach $lele (@lmap) {
                if ($lele->[0] eq $pn) {
                    my($fid0, $fid1);
                    $fid0 = 0; # These are set to true if we find the
                               # player in the right hand section
                    $fid1 = 0;
                    # We have an entry.
                    ($id0, $id1) = $single->break($gid);
                    # We have to find out which index this is in the
                    # righthand array.
                    $ind = -1;
                    foreach $rele (@rmap) {
                        $ind++;
                        if ($rele->[0]->id() == $id0) {
                            $fullname = $rele->[0]->cname() . " " .
                              $rele->[0]->sname();
                            $lele->[1]->configure(-text => $fullname,
                                                  -state => "active");
                            $lele->[3] = $ind;
                            $rele->[1]->configure(-state => "disabled");
                            $fid0 = 1;
                        }
                        if ($rele->[0]->id() == $id1) {
                            $fullname = $rele->[0]->cname() . " " .
                              $rele->[0]->sname();
                            $lele->[2]->configure(-text => $fullname,
                                                  -state => "active");
                            $lele->[4] = $ind;
                            $rele->[1]->configure(-state => "disabled");
                            $fid1 = 1;
                        }
                        if ($fid0 && $fid1) {
                            next GID;
                        }
                    }
                    # After searching the right array, we didn't find our id,
                    # So we will have to fix them up.
                    if (!$fid0) {
                        $lele->[1]->configure(-text => "Player $id0",
                                              -state => "active");
                        $lele->[3] = -2;
                        $lele->[5] = $id0;
                    }
                    if (!$fid1) {
                        $lele->[2]->configure(-text => "Player $id1",
                                              -state => "active");
                        $lele->[4] = -2;
                        $lele->[6] = $id1;
                    }
                    next GID;
                }
            }
        }
    }
    findsetcurrent($current, \@lmap);
}
# Determine the lower available entry and mark it
sub findsetcurrent
{
    my($current, $lmap) = @_;
    my($i);
    my($j);
    my($e);
    my($but);

    for ($i = 0; $i < scalar(@$lmap); $i++) {
        $e = $lmap->[$i];
        # This is the missing pair
        if ($e->[0] == 0) {
            next;
        }
        foreach $j (0, 1) {
            if ($e->[3 + $j] == -1) {
                $current->[0] = $i;
                $current->[1] = $j;
                $but = $e->[1 + $j];
                $but->configure(-text => $sel);
                return;
            }
        }
    }
    $current->[0] = -1;
}

sub rightbut
{
    # The lmap is the mapping of the left buttons,
    # the rmap is the list of our righthand buttons.
    # Current gives the index into lmap that is the current selected
    # entry
    # ind is the index into our rmap.
    my($lmap, $rmap, $current, $ind, $aptr, $lp) = @_;

    my($rbut, $lbut);
    my($name);
    my($lent);
    my($fullname);

    if ($current->[0] == -1) {
        # full up.
        return;
    }
    # Find out button, and disable it.
    $rbut = $rmap->[$ind]->[1];
    $name = $rmap->[$ind]->[0];

    $rbut->configure(-state => "disabled");

    # Find the left button.
    $lent = $lmap->[$current->[0]];
    $lbut = $lent->[1 + $current->[1]];
    $fullname = $name->cname() . " " . $name->sname();
    $lbut->configure(-text => $fullname, -state => "active");
    $lent->[3 + $current->[1]] = $ind;
    findsetcurrent($current, $lmap);
    cancelsel($aptr);
    setlastpair($current, $lmap, $rmap, $aptr, $lp);
}

sub leftbut
{
    my($lmap, $rmap, $current, $ind, $subind, $aptr) = @_;

    my($rbut, $lbut);
    my($curbut);
    my($lent, $rent);

    $lent = $lmap->[$ind];
    $lbut = $lent->[1 + $subind];
    $lbut->configure(-text => $sel, -state => "disabled");
    my($ckind) = $lent->[3 + $subind];
    if ($ckind != -2) {
        $rent = $rmap->[$lent->[3 + $subind]];
        $rbut = $rent->[1];
        $rbut->configure(-state => "active");
    }
    $lent->[3 + $subind] = -1;
    if ($current->[0] != -1) {
        $curbut = $lmap->[$current->[0]]->[1 + $current->[1]];
        $curbut->configure(-text => $empty);
    }
    $current->[0] = $ind;
    $current->[1] = $subind;
    cancelsel($aptr);
}

sub save
{
    my($lmap, $rmap, $single, $dir, $lp, $goodbye) = @_;

    # Dump out the pair mapping, one per line as:
    # pairno=global ind.
    # The only tricky part is that we want an unique name,
    # and we use the single module to do this for us.
    my($pn, $gid, $id0, $id1);
    my($ele, $pm);

    $pm = Pairmap->new();

    foreach $ele (@$lmap) {
        $pn = $ele->[0];
        $id0 = $ele->[3];
        next if $id0 == -1;

        if ($id0 == -2) {
            $id0 = $ele->[5];
        } else {
            $id0 = $rmap->[$id0]->[0]->id();
        }
        $id1 = $ele->[4];
        next if $id1 == -1;

        if ($id1 == -2) {
            $id1 = $ele->[6];
        } else {
            $id1 = $rmap->[$id1]->[0]->id();
        }

        $gid = Pairmap->normal($id0, $id1);
        $pm->add($pn, $gid);
    }
    $pm->save($dir);

    # We only want the date in the lastplayer database
    # so trim off anything after the date.
    my($jdate) = $dir;
    $jdate =~ s/_.*$//;
    # This should merge in the current pairmap
    $lp->merge($pm, $jdate);
    # And save it for next time.
    $lp->save($lpfile);
    # Generate the list of valid emails address.
    maillist($lmap, $rmap, $single, $dir);
    # Call the passed in exit function.
    my($func) = shift(@$goodbye);
    &$func(@$goodbye);
}


sub maillist
{
    my($lmap, $rmap, $single, $dir) = @_;
    my(%email, @emails);
    my($fh);
    my($ele);
    my($id, $id0);

    foreach $ele (@$lmap) {
        foreach $id ($ele->[3], $ele->[4]) {
            # We can have people in the database that have an
            # email address, but don't want the result email.
            if (($id != -1) && !$rmap->[$id]->[0]->{noemail}) {
                $id0 = $rmap->[$id]->[0]->{email};
                if ($id0) {
                    if (!exists($email{$id0})) {
                        $email{$id0} = $ele->[0];
                    }
                }
            }
        }
    }

    # add the always want email peoeple
    foreach $ele (@Conf::Ea) {
        if (!exists($email{$ele})) {
            $email{$ele} = 0;
        }
    }
    @emails = sort({$a cmp $b} keys(%email));
    $fh = IO::File->new();
    my($fname);

    $fname = "email.txt";
    if (!$fh->open($fname, ">")) {
        die("Failed to open mailbox for writing $!\n");
    }
    my($json) = JSON->new();
    $json->pretty();
    my($eout) = [];
    foreach $ele (@emails) {
        push(@$eout, [$ele, $email{$ele}]);
    }
    $fh->print($json->encode($eout), "\n");
    $fh->close();
}

sub key_pressed
{
    # We get passed with:
    # $ref - our main window or frame.
    # $key - the key that was pressed
    # $lmap - a ref to the array of the object on the left of the screeen
    # $rmap - a ref to all the name object on the right
    # $single - the player database ref
    # $aptr - A buffer. This is where we store up our key strokes.
    my($ref, $key, $lmap, $rmap, $current, $single, $aptr, $lp) = @_;

    # Turn this in to help debug
    if (0) {
        my($sel);
        my($buf);
        if (defined($aptr->{sel})) {
            $sel = scalar(@{$aptr->{sel}});
        } else {
            $sel = 0;
        }
        $buf = $aptr->{dbuf};
        print("I've been called with: ($key) sel ($sel) buf ($buf)\n");
    }

    if ($key eq "BackSpace") {
        cancelsel($aptr);
        return;
    } elsif ($key eq "Return") {
        # TODO If we have a single item selected, then chosse
        # that and clear the buffer
        # If we don't have just one entry, then do nothin.
        if (defined($aptr->{sel})) {
            if (scalar(@{$aptr->{sel}}) == 1) {
                # we have only one choice, so pick it.
                rightbut($lmap, $rmap, $current, $aptr->{sel}->[0]->[3],
                        $aptr, $lp);
            }
        }
        return;
    } elsif (length($key) > 1) {
        # This is a control character, do nothing
        return;
    }

    if (length($aptr->{dbuf}) == 0) {
        if (defined($aptr->{sel})) {
            cancelsel($aptr);
        }
        # We can't search on a single letter.
        $aptr->{dbuf} = lc($key);
        return;
    }
    $aptr->{dbuf} .= lc($key);

    # We now have two letters, and can search the right hand map for
    # entries that map the first letter to the start of the first
    # name, and the second letter to the first letter in the surname.
    my($r);
    my($i) = substr($aptr->{dbuf}, 0, 1);
    my($surname) = substr($aptr->{dbuf}, 1);
    my($keylength) = length($surname);
    my($shortlist) = 0;
    my($map);
    my($newmap);
    my($yes);

    if ($keylength > 1) {
        $shortlist = 1;
        $map = $aptr->{sel};
    } else {
        $shortlist = 0;
        $map = $rmap;
    }
    foreach $r (@$map) {

        $yes = 0;
        # The third item in the map is the player id
        my($id) = $r->[2];
        # Lookup the entry.
        my($ent) = $single->entry($id);
        my($sname) = substr($ent->sname(), 0, $keylength);
        my($cname) = substr($ent->cname(), 0, 1);
        if ($sname) {
            $sname = lc($sname);
        }
        if ($cname) {
            $cname = lc($cname);
        }
        if (($i eq $cname) && ($surname eq $sname)) {
            if ($r->[1]->cget(-state) ne "disabled") {
                if (!$shortlist) {
                    if (!defined($aptr->{defcol})) {
                        # save the current colors so we can put them back.
                        $aptr->{defcol} = [];
                        $aptr->{defcol}->[0] = $r->[1]->cget(-activeforeground);
                        $aptr->{defcol}->[1] = $r->[1]->cget(-activebackground);
                        $aptr->{defcol}->[2] = $r->[1]->cget(-foreground);
                        $aptr->{defcol}->[3] = $r->[1]->cget(-background);
                    }
                    # Change the colour.
                    $r->[1]->configure(-activeforeground => "red",
                                       -activebackground => "white",
                                      -foreground => "red",
                                      -background => "white");
                }
                $yes = 1;
                push(@$newmap, $r);
            }
        }
        # If we are using the shortlist, the entries
        # are already highligthed, so if the selection
        # now fails we have to unselect them.
        if (!$yes && $shortlist) {
            $r->[1]->configure(
               -activeforeground => $aptr->{defcol}->[0],
               -activebackground => $aptr->{defcol}->[1],
               -foreground => $aptr->{defcol}->[2],
               -background => $aptr->{defcol}->[3]);
        }
    }
    $aptr->{sel} = $newmap;
    if (defined($Conf::Bell) && $Conf::Bell && defined($newmap) && (scalar(@$newmap) == 1)) {
        # Go bing if only one entry, i.e. "Return" would work.
        $ref->bell();
    }
}

# Uncolor all the current selected entries, and ditch the
# seletion list and input buffer.
sub cancelsel
{
    my($aptr) = @_;
    my($r);
    if (defined($aptr->{sel})) {
        foreach $r (@{$aptr->{sel}}) {
            $r->[1]->configure(
               -activeforeground => $aptr->{defcol}->[0],
               -activebackground => $aptr->{defcol}->[1],
               -foreground => $aptr->{defcol}->[2],
               -background => $aptr->{defcol}->[3]);
        }
        $aptr->{sel} = undef;
    }
    $aptr->{dbuf} = "";
}

# When we fill in a player in column 0, and column
# 1 is empty, see if we can determine who was the
# last active player.
sub setlastpair
{
    my($current, $lmap, $rmap, $aptr, $lp) = @_;


    if ($current->[0] == -1) {
        # No entries are spare.
        return;
    }

    if ($current->[1] == 0) {
        # We are not selecting the column 1 player
        # so do nothing.
        return;
    }
    # Ok, lets get the currently selected player in
    # column 0.

    # A 'left' enrty contains:
    # 0 pn - the sessin pairnumber.
    # 1 but - the button of the first player.
    # 2 but2 - the button of the second player.
    # 3 ind - index into the rmap for the first player of the pair
    # 4 ind2 - index into the rmap for the second player of the pair.
    my($rent) = $rmap->[$lmap->[$current->[0]]->[3]];

    # A 'right' entry contains:
    # 0 the single entry for this player.
    # 1 the button pointer for this player
    # 2 the player's global id
    # 3 the lmap index


    my($map) = $lp->map();
    if (!exists($map->{$rent->[2]})) {
        # We don't have a known last partner.
        return;
    }
    my($othernum) = $map->{$rent->[2]}->other();
    # Now search the rmap for this number.
    $rent = undef;
    foreach my $r (@$rmap) {
        if ($r->[2] == $othernum) {
            $rent = $r;
            last;
        }
    }
    if (!defined($rent)) {
        # My partner is not in the rmap (so can't be active)
        return;
    }

    # We can't select a previously selected name
    if ($rent->[1]->cget(-state) eq "disabled") {
        return;
    }
    if (!defined($aptr->{defcol})) {
        # save the current colors so we can put them back.
        $aptr->{defcol} = [];
        $aptr->{defcol}->[0] = $rent->[1]->cget(-activeforeground);
        $aptr->{defcol}->[1] = $rent->[1]->cget(-activebackground);
        $aptr->{defcol}->[2] = $rent->[1]->cget(-foreground);
        $aptr->{defcol}->[3] = $rent->[1]->cget(-background);
    }

    # Change the colour.
    $rent->[1]->configure(-activeforeground => "red",
                          -activebackground => "white",
                          -foreground => "red",
                          -background => "white");
    $aptr->{sel} = [ $rent ];
}

1;

