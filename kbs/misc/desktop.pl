#
# Add the required desktop shortcuts for kbs.pl
#

use strict;
use warnings;
use IO::Handle;
use Win32::Shortcut;
use Dir::Self;

sub main
{

    my($link) = Win32::Shortcut->new();
    my($ppath);
    # Get the save location.
    my($dtop) = $ENV{USERPROFILE};
    if (!defined($dtop)) {
        die("The environmant variable USERPROFILE is not set. I can't determnien the path to your desktop\n");
    }
    $dtop .= "\\Desktop";
    $ppath = $^X;

    $link->{Path} = $ppath;
    $link->{Arguments} = "..\\kbs.pl";
    $link->{WorkingDirectory} = __DIR__ . "\\club";
    $link->{ShowCmd} = SW_SHOWMINNOACTIVE;
    $link->{Description} = "Knave Bridge Scorer";
    $link->{IconLocation} = __DIR__ . "\\kbs.ico";
    $link->{IconNumber} = 0;

    $link->Save($dtop . "\\KBS.lnk");
    $link->Close();

    # Now one to the club directory
    $link = Win32::Shortcut->new();
    $link->{Path} = __DIR__ . "\\club";
    $link->Save($dtop . "\\KBSCLUB.lnk");
    $link->Close();
}

eval {
    main();
};
if ($@) {
    print("Error detected: $@\n");
}

print("\nPress enter to exit\n");
STDIN->getline();
exit(0);
