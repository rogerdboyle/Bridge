#
# A support module used to help generate XML output.
# Used by Usebio.pm
#

# $Id: Xmlgen.pm 741 2011-07-05 09:11:32Z Root $
# This is Copyright 2009 Paul Haffenden

###############
package Xmlgen;
###############
use strict;
use warnings;
use Conf;

our($AUTOLOAD);
our($header) = <<EOF;
<?xml version="1.0" encoding="UTF8"?>
#doc#
<!--
   The contents of this file are Copyright by $Conf::Club.
   Permission is granted for use by the EBU solely
   for the purpose of calculating Pay to Play fees.

   Any other use is forbidden without written permission
   of $Conf::Club, please see the club web site for contact details.

   Knave Bridge Scorer Xmlgen/Usebio module Version: #ver#
-->
EOF
sub new
{
    my($class) = shift;
    my($valtags, $doc, $version, $flat, $nouc) = @_;
    my($self) = {};
    $header =~ s/#ver#/$version/;
    $header =~ s/#doc#/$doc/;
    $self->{str} = $header;
    $self->{ind} = 0;
    bless($self, $class);
    my($tags);
    $self->{tags} = { map({$_ => 1} @$valtags) };
    $self->{version} = $version;
    $self->{flat} = $flat;
    $self->{nouc} = $nouc;
    return $self;
}

sub AUTOLOAD
{
    my($self) = shift();
    my($hash) = @_;

    my($name);
    my($term) = 0;
    my($attrstr) = "";

    $name = $AUTOLOAD;
    $name =~ s/.*:://; # just the name.

    # If it starts with an "_" it is illegal (those are reserved for
    # the internal routines.
    if (substr($name, 0, 1) eq "_") {
	die("Function $name not available\n");
    }
    # If it ends in a '0', it needs to be expanded into
    # the start tag, the first arg placed into the str,
    # and then terminated with the end tag.
    my($n) = $name =~ m/(.*)0$/;
    if (defined($n)) {
	$self->$n($_[1]);
	$self->_str($_[0]);
	$n .= "_";
	$self->$n();
	return;
    }
	


    # If it ends with an "_", then this is a terminating tag.
    if ($name =~ m/_$/) {
	if (defined($hash)) {
	    die("A terminating tag ($name) has been specified with attribute ",
		"arguments\n");
	}
	$term = 1;
	$name =~ s/.$//;
    }

    if (!$self->{nouc}) {
	$name = uc($name);
    }
    if (!exists($self->{tags}->{$name})) {
	my(@x) = caller();
	die("Invalid tag $name ($x[0] $x[1] $x[2])\n");
    }
    if (!$term) {
	my($key, $val);

	while (($key, $val) = each(%$hash)) {
	    if ($attrstr) {
		$attrstr .= " ";
	    }
	    $attrstr .= "$key=\"$val\"";
	}
    } else {
	$self->{ind} -= 2;
	if ($self->{ind} < 0) {
	    die("Too many closing tags for /$name\n");
	}
    }
    # See if we want decorations
    if (!$self->{flat}) {
	# The last tag was a terminator, so we need to indent.
	if ($self->{last}) {
	    $self->{str} .= " " x $self->{ind};
	} else {
	    if (!$term) {
		$self->{str} .= "\n" . " " x $self->{ind};
	    }
	}
    }
    $self->{str} .= "<";
    if ($term) {
	$self->{str} .= "/";
    }
    $self->{str} .= $name;
    if ($attrstr) {
	$self->{str} .= " $attrstr";
    }
    $self->{str} .= ">";
    if ($term) {
	if (!$self->{flat}) {
	    $self->{str} .= "\n";
	}
    } else {
	$self->{ind} += 2;
    }
    $self->{last} = $term;
}

# Return the constructed xml string
sub _retstr
{
    my($self) = shift();
    return $self->{str};
}

# Escape any xml entities, and write the data into
# the output string.
sub _str
{
    my($self) = shift();
    my($str);
    if (scalar(@_) && defined($_[0])) {
	$str = join(" ", @_);
	# xml escape processing
	$str =~ s/&/\&amp;/g;
	$str =~ s/</\&lt;/g;
	$str =~ s/>/\&gt;/g;
	$self->{str} .= $str;
    }
}

# Have to have this, or we will try to generate a "DESTROY"
# tag when the object is garbage collected.
sub DESTROY
{
}
1;
