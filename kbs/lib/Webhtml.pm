#
# Construct the start and end parts of a webpage.

use strict;
use warnings;

################
package Webhtml;
################


# Some magic strings
#
# Magic html5 declaration
our($declare) = <<EOF;
<!DOCTYPE HTML>
<html>
<head>
<meta charset="UTF-8">

EOF

our($title) = <<EOF;
<title>##title##</title>
EOF

our($jquery) = <<EOF;
<script language="javascript" type="text/javascript" src="jquery-2.1.0.min.js"></script>
EOF

our($flot) = <<EOF;
<script language="javascript" type="text/javascript" src="jquery.flot.min.js"></script>
EOF

our($stack) = <<EOF;
<script language="javascript" type="text/javascript" src="jquery.flot.stack.js"></script>
EOF

our($tool) = <<EOF;
<script language="javascript" type="text/javascript" src="jquery.flot.tooltip.min.js"></script>
EOF

our($mongraph) = <<EOF;
<script language="javascript" type="text/javascript" src="mongraph.js"></script>
EOF

our($endofjs) = <<EOF;
</head>
EOF

our($body) = <<EOF;
<body>
EOF


our($h1) = <<EOF;
<h1>##title##</h1>
EOF

our($postamble) = <<EOF;
</body>
</html>
EOF

our($jsmap) = {
               JQUERY => \$jquery,
               FLOT => \$flot,
               TOOL => \$tool,
               MONGRAPH => \$mongraph,
               STACK => \$stack,
};

sub new
{
    my($class) = shift();
    my($self) = {};
    bless($self, $class);
    return ($self);
}

sub preamble
{
    my($self) = shift;
    my($title_in, $head_in, $stylesheet, $jsopts, $opt) = @_;
    my($retstr) = "";
    my($workstr);
    my($js);
    my($js_seen) = {};

    $retstr .= $declare;
    $workstr = $title;
    $workstr =~ s/##title##/$title_in/g;
    $retstr .= $workstr;
    foreach $js (@$jsopts) {
        if (exists($js_seen->{$js})) {
            die("The javascript key ($js) has already been specifed\n");
        }
        if (exists($jsmap->{$js})) {
            $retstr .= ${$jsmap->{$js}};
            $js_seen->{$js} = 1;
        } else {
            die("I don't grok the javascript key ($js)\n");
        }
    }
    $retstr .= $stylesheet;
    $retstr .= $endofjs;
    $retstr .= $body;
    if (length($head_in) > 0) {
        $workstr = $h1;
        $workstr =~ s/##title##/$head_in/g;
        $retstr .= $workstr;
    }
    return ($retstr);
}

sub postamble
{
    my($self) = @_;
    my($retstr) = "";
    $retstr .= $postamble;
    return $retstr;
}

1;
