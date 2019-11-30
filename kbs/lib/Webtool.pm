# This is the tool to generate the web result interogator
#
#

################
package Webtool;
################

# $Id: Webtool.pm 1648 2016-11-11 15:19:09Z phaff $
# Copyright (c) 2011 Paul Haffenden. All rights reserved.

use strict;
use warnings;
use IO::File;
use JSON;
use Conf;
use Rscan;
use Webhtml;


# The javascript code
our($js) = <<'EOF';
var pjh = (function() {
   var p1 = -1; // the first player's id
   var p2 = -1; // the second player's id
   var dash; // Number of dashes to pad out the selection boxes
   var table = []; // the selected results to be placed in the html table
   var namelist;
   var results;

   // The function calls start here..
   var startup = function() {
     var maxname = 0;

     // Find the max length of a name.
     for (var nameindex in namelist) {
       var n;
       for (var sname in namelist[nameindex]) {
         n = sname;
       }
       if (n.length > maxname) {
         maxname = n.length;
       }
     }
     maxname *= 1.5;
     dash = "";
     for (var i = 0; i < maxname; i++) {
       dash += "-";
     }
     var sel = $("#playerone");
     sel.append("<option value='" + -1 + "'>" + dash + "</option>");
     for (var nameindex in namelist) {
       var n;
       for (var sname in namelist[nameindex]) {
         n = sname;
       }
       sel.append("<option value='" + nameindex + "'>" + n + "</option>");
     }

     sel = $("#playertwo");
     sel.append("<option value='" + -1 + "'>" + dash + "</option>");

     // set the onchange action for both drop down menus.
     $("#playerone").change(changeplayer1);
     $("#playertwo").change(changeplayer2);
     $("#b1").click(sortbypos);
     $("#b2").click(sortbypercent);
     $("#b3").click(sortbywilson);
     $("#b4").click(sortbytto);
     $("#b5").click(sortbydate);
     $("#b6").click(sortbyname);
   };

   var changeplayer1 = function() {
     var id = this.value;
     var sel =  $("#playertwo");

     zaptable();
     sel.empty();
     sel.append("<option value='" + -1 + "'>" + dash + "</option>");

     if (id == -1) {
       return;
     }
     sel.append("<option value='" + -2 + "'>" + "All" + "</option>");
     var p1id;

     var playerobj = namelist[id];
     for (var i in playerobj) {
       p1id = i;
     }
     p1id = playerobj[p1id];
     p1 = p1id;
     // look through all the results looking for someone that
     // matches me
     var otherpair = {};
     for (var result in results) {
       var pair = results[result]['pair'];
       var p = pair.split("_", 2);
       if (p == null) {
         alert("Bad split from pair " + pair + " id was " + id);
         break;
       }
       if (p[0] == p1id) {
         otherpair[p[1]] = 1;
       } else {
         if (p[1] == p1id) {
           otherpair[p[0]] = 1;
         }
       }
     }
     // loop through the player list
     for (var nameindex in namelist) {
       var n;
       for (var sname in namelist[nameindex]) {
         n = sname;
       }
       p1id = namelist[nameindex][n];
       if (otherpair[p1id]) {
           sel.append("<option value='" + nameindex + "'>" + n + "</option>");
       }
     }
   };

   var sortby_percent = function(a, b) {
     var floata = parseFloat(a.percent);
     var floatb = parseFloat(b.percent);

     return (floatb - floata);
   };

   var sortby_wilson = function(a, b) {
     var inta;
     var intb;

     if (a.mp == null) {
       inta = 0;
     } else {
       inta = parseInt(a.mp);
     }
     if (b.mp == null) {
       intb = 0;
     } else {
       intb = parseInt(b.mp);
     }
     return (intb - inta);
   };

   var sortby_tto = function(a, b) {
     var floata;
     var floatb;

     if (a.tto == null) {
       floata = 0.0;
     } else {
       floata = parseFloat(a.tto);
     }
     if (b.tto == null) {
       floatb = 0.0;
     } else {
       floatb = parseFloat(b.tto);
     }
     return (floatb - floata);
   };


   var sortby_date = function(a, b) {
     var inta = parseInt(a.date);
     var intb = parseInt(b.date);
     return (intb - inta);
   };

   var sortby_pos_percent = function(a, b) {
     if (a.sortpos < b.sortpos) {
       return -1;
     }
     if (a.sortpos > b.sortpos) {
       return 1;
     }
     if (a.sortpercent < b.sortpercent) {
       return 1;
     }
     if (a.sortpercent > b.sortpercent) {
       return -1;
     }
     return 0;
   };

   var sortby_name = function(a, b) {
     if (a.partner < b.partner) {
       return -1;
     }

     if (a.partner > b.partner) {
       return 1;
     }
     // If the names are equal then sort by percent.
     var floata = parseFloat(a.percent);
     var floatb = parseFloat(b.percent);
     return (floatb - floata);
   };


   var changeplayer2 = function() {
     var p1id;
     var ind;
     var partnername;
     var id = this.value;
     // Try some table
     zaptable();
     table = [];
     if (id == -1) {
       // The dashed lines
       return;
     }
     p1 = parseInt(p1);

     if (id != -2) {
       var playerobj = namelist[id];
       for (var i in playerobj) {
         p1id = i;
       }
       partnername = p1id;

       p1id = playerobj[p1id];
       p2 = p1id;

       var keystr;
       p2 = parseInt(p2);
       if (p1 < p2) {
         keystr = p1 + "_" + p2;
       } else {
         keystr = p2 + "_" + p1;
       }
     }

     ind = 0;
     for (var item in results) {
       var paircheck = 0;
       var other;
       var partnetname;
       if (id == -2) {
         var p;
         p = results[item].pair.split("_", 2);
         parseInt(p[0]);
         parseInt(p[1]);
         // split the pair in the result
         if (p[0] == p1) {
           paircheck = 1;
           other = p[1];
         } else if (p[1] == p1) {
           paircheck = 1;
           other = p[0];
         }
       } else {
         paircheck = (results[item].pair == keystr);
       }
       if (paircheck) {
         table[ind] = results[item];
         var pos = "" + table[ind].pos;
         pos.replace(/=/, "");
         if (pos == table[ind].outof) {
           table[ind].sortpos = parseInt(pos);
         } else {
           table[ind].sortpos = parseInt(pos) / table[ind].outof;
         }
         table[ind].sortpercent = parseFloat(table[ind].percent);
         if (id == -2) {
           partnername = "";
           var eol = 0;
           for (var player in namelist) {
             var playerobj = namelist[player];
             for (var key in playerobj) {
               if (playerobj[key] == other) {
                 partnername = key;
                 eol = 1;
               }
             }
             if (eol) {
               break;
             }
           }
         }
         table[ind].partner = partnername;
         ind++;
       }
     }
     table = table.sort(sortby_pos_percent);
     drawtable();
   };

   var sortbypos = function() {
     // Try some table
     zaptable();

     table = table.sort(sortby_pos_percent);
     drawtable();
   };

   var sortbydate = function() {
     // Try some table
     zaptable();

     table = table.sort(sortby_date);
     drawtable();
   };


   var sortbypercent = function() {
     // Try some table
     zaptable();

     table = table.sort(sortby_percent);
     drawtable();
   };

   var sortbyname = function() {
     zaptable();

     table = table.sort(sortby_name);
     drawtable();
   };


   var sortbywilson = function() {
     zaptable();

     table = table.sort(sortby_wilson);
     drawtable();
   };


   var sortbytto = function() {
     zaptable();

     table = table.sort(sortby_tto);
     drawtable();
   };


   var drawtable = function() {
     var frag = document.createDocumentFragment();

     for (var item in table) {
       var row = document.createElement("tr");
       var cell;
       var celltext;
       var ddate;

       cell = document.createElement("td");
       celltext = document.createTextNode(table[item].pos + "/" + table[item].outof);
       cell.appendChild(celltext);
       row.appendChild(cell);

       cell = document.createElement("td");
       celltext = document.createTextNode(table[item].percent);
       cell.appendChild(celltext);
       row.appendChild(cell);

       cell = document.createElement("td");
       if (table[item].mp == null) {
         celltext = document.createTextNode("");
       } else {
         celltext = document.createTextNode(table[item].mp);
       }
       cell.appendChild(celltext);
       row.appendChild(cell);

       cell = document.createElement("td");
       if (table[item].tto == null) {
         celltext = document.createTextNode("");
       } else {
         celltext = document.createTextNode(table[item].tto);
       }
       cell.appendChild(celltext);
       row.appendChild(cell);

       cell = document.createElement("td");
       ddate = table[item].date;
       celltext = document.createTextNode(ddate.substring(0,4) + "-" + ddate.substring(4,6) + "-" + ddate.substring(6));
       cell.appendChild(celltext);
       row.appendChild(cell);

       cell = document.createElement("td");
       celltext = document.createTextNode(table[item].partner);
       cell.appendChild(celltext);
       row.appendChild(cell);

       frag.appendChild(row);
     }
     $("#t1").append(frag);
   };

   var zaptable = function() {
       $("#t1 tr:gt(0)").remove();
   };

   var setnamelist = function(list) {
     namelist = list;
   };

   var setresults = function(list) {
     results = list;
   };
   ret = {
     "startup" : startup,
     "setnamelist" : setnamelist,
     "setresults" : setresults
   };
   return ret;
})();

$(document).ready(pjh.startup);
EOF


sub new
{
    my($class) = shift();

    my($self) = {};
    bless($self, $class);
    return $self;
}

sub generate
{
    my($self) = shift();
    my($single, $outfile, $list, $ypairs) = @_;
    my($fh);
    my($wh) = Webhtml->new();

    # Generate a javascript hash of all the active names.
    my($namelist) = [];
    my($id, $val);

    while (($id, $val) = each(%$ypairs)) {
        my($ent) = $single->entry($id);
        next if $ent->png();
        if (defined($ent)) {
            push(@$namelist, {$ent->sname() . " " . $ent->cname() => $id + 0} );
        } else {
            push(@$namelist, {"Unknown $id" => $id + 0} );
        }
    }
    $namelist = [ sort( {(keys(%{$a}))[0] cmp (keys(%{$b}))[0] } @$namelist) ];
    my($ofh) = IO::File->new();
    if (!$ofh->open($outfile, ">")) {
        die("I can't open the output file for writing $outfile $!\n");
    }
    my($stylesheet) = <<EOF;
<style type="text/css">
h1 {
        color: blue;
        text-align: center;
}

body {
        font-family: "Verdana";
        background: #cccccc;
        text-align:center;
}
td, th {
        border: 2px solid;
}

table.center {
        margin-left: auto;
        margin-right: auto;
        box-shadow: 15px 15px 15px #888;
        -webkit-box-shadow: 15px 15px 15px #888;
        border-collapse: collapse;
}

</style>
EOF
    # Generate some html to load
    $ofh->print($wh->preamble("$Conf::Club result analysis",
                              "$Conf::Club result analysis",
                              $stylesheet,
                              [ qw(JQUERY) ],
                              {}));

    $ofh->print(<<EOF);
<div>
<select id="playerone">
</select>
<select id="playertwo">
</select>
</div>
<table id="t1" class="center">
<tr>
<th><button type="button" id="b1">Position</button></th>
<th><button type="button" id="b2">Percentage</button></th>
<th><button type="button" id="b3">Wilsons</button></th>
<th><button type="button" id="b4">WPS</button></th>
<th><button type="button" id="b5">Date</button></th>
<th><button type="button" id="b6">Partner</button></th>
</tr>
</table>
<script type="text/javascript">
EOF
    $ofh->print($js, "pjh.setresults(");
    $ofh->print(to_json($list), ");\n");

    $ofh->print("pjh.setnamelist(");
    $ofh->print(to_json($namelist), ");\n");

    $ofh->print(<<EOF);
</script>
EOF
    $ofh->print($wh->postamble());
}

1;
