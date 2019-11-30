#
# Program to edit the club configuration file
# $Id: Configclient.pm 869 2012-03-01 17:34:19Z phaff $
#####################
package Configclient;
#####################

use strict;
use warnings;
use Tk;
use Confload;


sub main
{
    my($mw, $goodbye) = @_;
    my($cl) = Confload::load(1);
    my($row);
    my($lab, $ent);
    if (!$cl) {
        die("I don't have a config file to load\n");
    }
    my($club) = $cl->{Conf}->{Club};

    my($font) = $mw->fontCreate(-family => "helvetica", -size => 12, -weight => "bold");
    my(@font) = ("-font", $font);


    $mw->title("Configuration editor");
    $row = 0;


    $lab = $mw->Label(-text => "$club->{comment} :", @font);
    $lab->grid(-column => 0, -row => $row);

    $ent = $mw->Entry(-textvariable => \$club->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Input scores without trailing 0", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Checkbutton(-variable => \$cl->{Conf}->{Div10}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;


    $lab = $mw->Label(-text => "Sort travellers", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Checkbutton(-variable => \$cl->{Conf}->{Travsort}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Contracts not entered on travellers", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Checkbutton(-variable => \$cl->{Conf}->{short_scores}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Ring the bell when a single player is available for selection", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Checkbutton(-variable => \$cl->{Conf}->{Bell}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;


    my($BW_elements) = [];
    my($state) = "normal";
    if (!$cl->{Conf}->{bridgeweb_scores}->{val}) {
        $state = "disabled";
    }
    $lab = $mw->Label(-text => "Generate result file for Bridgewebs", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Checkbutton(
                            -variable => \$cl->{Conf}->{bridgeweb_scores}->{val},
                            -command => [ \&bwstate, $cl->{Conf}->{bridgeweb_scores}, $BW_elements ], @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Bridgeweb club identifier", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{BWclub}->{val}, -state => $state, @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$BW_elements, $ent);
    $row++;

    $lab = $mw->Label(-text => "Bridgeweb club password", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{BWpassword}->{val}, -show => "*", -state => $state, @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$BW_elements, $ent);
    $row++;

    $lab = $mw->Label(-text => "Ecats Club name", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{clubname}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;


    $lab = $mw->Label(-text => "Ecats Town", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{town}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Ecats County", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{county}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Ecats Country", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{country}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;


    $lab = $mw->Label(-text => "Ecats Contact name", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{contactname}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Ecats Contact telephone number", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{contactphone}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Ecats Contact email address", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{contactemail}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "Ebu club number", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Ecats}->{clubebunumber}->{val}, @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;



    my($MAIL_elements) = [];
    $state = "normal";
    if (!$cl->{Conf}->{Email}->{val}) {
        $state = "disabled";
    }
    $lab = $mw->Label(-text => "Enable sending of result email", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Checkbutton(
                            -variable => \$cl->{Conf}->{Email}->{val},
                            -command => [ \&bwstate, $cl->{Conf}->{Email}, $MAIL_elements ], @font);
    $ent->grid(-column => 1, -row => $row);
    $row++;

    $lab = $mw->Label(-text => "The 'From' address to appear in the result email", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{Efrom}->{val}, -state => $state, @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$MAIL_elements, $ent);
    $row++;

    $lab = $mw->Label(-text => "The SMTP host used to send the result email", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{Esmtphost}->{val}, -state => $state, @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$MAIL_elements, $ent);
    $row++;

    $lab = $mw->Label(-text => "Authentication scheme used by the SMTP host", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{Eauth}->{val}, -state => $state, @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$MAIL_elements, $ent);
    $row++;

    $lab = $mw->Label(-text => "Authenticated user for SMTP host", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{Eauthid}->{val}, -state => $state, @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$MAIL_elements, $ent);
    $row++;

    $lab = $mw->Label(-text => "Authenticated password for SMTP host", @font);
    $lab->grid(-column => 0, -row => $row);
    $ent = $mw->Entry(-textvariable => \$cl->{Conf}->{Eauthpwd}->{val}, -state => $state, -show => "*", @font);
    $ent->grid(-column => 1, -row => $row);
    push(@$MAIL_elements, $ent);
    $row++;

    $ent = $mw->Button(-text => "Exit without saving",
                       -command => $goodbye, @font);
    $ent->grid(-column => 0, -row => $row);

    # The Save and cancel buttons.
    $ent = $mw->Button(-text => "Save configuration",
                       -command => [ \&save, $cl, $goodbye ], @font);
    $ent->grid(-column => 1, -row => $row);

    MainLoop();
}


sub save
{
    my($cl, $goodbye) = @_;
    Confload::save($cl);
    my($func) = shift(@$goodbye);
    &$func(@$goodbye);
}

sub quit
{
    my($goodbye) = @_;
    &$goodbye();
}

# Wiggle the bridgeweb entry boxes.
sub bwstate
{
    my($cl, $ele) = @_;

    my($state) = "normal";
    if (!$cl->{val}) {
        $state = "disabled";
    }
    my($e);
    foreach $e (@$ele) {
        $e->configure(-state => $state);
    }
}

1;
