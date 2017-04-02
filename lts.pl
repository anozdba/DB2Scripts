#!/usr/bin/perl
# --------------------------------------------------------------------
# lts.pl
#
# $Id: lts.pl,v 1.17 2016/04/15 06:22:57 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST TABLESPACES command
#
# Usage:
#   lts.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lts.pl,v $
# Revision 1.17  2016/04/15 06:22:57  db2admin
# update to use commonFunctions.pm
#
# Revision 1.16  2014/05/25 22:28:46  db2admin
# correct the allocation of windows include directory
#
# Revision 1.15  2013/09/19 05:48:34  db2admin
# increase the length of the tablespace name column
#
# Revision 1.14  2010/02/02 05:33:19  db2admin
# remove code that was preventing space calculations fro system managed tablespaces
#
# Revision 1.13  2010/01/11 01:27:38  db2admin
# Add in usage information on what command is being executed
#
# Revision 1.12  2009/11/12 21:28:26  db2admin
# correct database name in final line of output
#
# Revision 1.11  2009/10/05 21:29:31  db2admin
# added in debug mode
#
# Revision 1.10  2009/07/15 22:33:49  db2admin
# added on the allocated Mb value
#
# Revision 1.9  2009/06/05 01:46:30  db2admin
# correct code so Windows use does not produce an error
#
# Revision 1.8  2009/04/01 03:05:03  db2admin
# Alter tablespace name comparisons to be contains rather equals
#
# Revision 1.7  2009/01/19 05:08:13  db2admin
# initialise $scriptdir directory with a non null value
#
# Revision 1.6  2009/01/19 00:51:17  db2admin
# Add in a check to ensure that database is specified
#
# Revision 1.5  2009/01/18 23:41:05  db2admin
# correct for windows execution
#
# Revision 1.4  2008/12/05 02:21:19  db2admin
# correct timestamp in heading
#
# Revision 1.3  2008/12/05 02:19:25  m08802
# Add in standard parameter and make tablespace checking case insensitive
#
# Revision 1.2  2008/10/23 23:41:30  m08802
# Add code to display offline tablespaces
#
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: lts.pl,v 1.17 2016/04/15 06:22:57 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

my $machine;            # machine name
my $machine_info;       # ** UNIX ONLY ** uname
my @mach_info;          # ** UNIX ONLY ** uname split by spaces
my $OS;                 # OS
my $scriptDir;          # directory where the script is running
my $tmp;

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scrxipts';
    $tmp = rindex($0,'\\');
    if ($tmp -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    $tmp = rindex($0,'/');
    if ($tmp -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
}

use lib "$scriptDir";

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $myDate_debugLevel);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs [-d <database> | -f <Filename>] [-t <tablespace>] [-v[v]]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (in this program only suppesses parameter messages)
       -d              : Database to list
       -t              : Limit output to this tablespace
       -v              : turn on verbose/debug mode
       -f              : Instead of directly accessing the databases use this file as input

       NOTE: This command basically reformats a 'list tablespaces show detail'
\n";

}

my $infile = "";
my $TSName = "ALL";
my $database = "";
my $silent = "No";
my $debugLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsvf:d:t:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug Level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be used as input\n";
   }
   $infile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "DB2 connection will be made to $getOpt_optValue\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "Only Tablespace $getOpt_optValue will be listed\n";
   }
   $TSName = uc($getOpt_optValue);
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "DB2 connection will be made to $database\n";
     }
   }
   elsif ( $TSName eq "ALL" ) {
     $TSName = uc($getOpt_optValue);
     if ( $silent ne "Yes") {
       print "Only tablespace $TSName will be listed\n";
     }
   }
   elsif ( ($infile eq "" ) && (substr($getOpt_optValue,0,5) eq "FILE:") ) {
     $infile = substr($getOpt_optValue,5);
     if ( $silent ne "Yes") {
       print "File $infile will be sued as input\n";
     }
   }
   else {
     usage ("Parameter $getOpt_optName : This parameter is unknown");
     exit;
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
my $month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
my $minute = substr("0" . $minute, length($minute)-1,2);
my $second = substr("0" . $second, length($second)-1,2);
my $month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $NowTS = "$year.$month.$day $hour:$minute:$second";
my $NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
my $date = "$year$month$day";

if ( $database eq "") {
  usage 'A Database must be specified';
  exit;
}

my $TotAlloc = 0;
my $TotUsed = 0;
my $Zeroes = "00";

if (! open(STDCMD, ">ltscmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 connect to $database\n";
if ( $debugLevel > 0 ) { print "To be executed: db2 connect to $database\n"; }
print STDCMD "db2 list tablespaces show detail\n";
if ( $debugLevel > 0 ) { print "To be executed: db2 list tablespaces show detail\n"; }

close STDCMD;

my $pos = "";
if ($OS ne "Windows") {
  my $t = `chmod a+x ltscmd.bat`;
  $pos = "./";
}

if ( $infile eq "" ) {
  if ( $debugLevel > 0 ) { print "Input will be the output of the above commands\n"; }
  if (! open (LTSPIPE,"${pos}ltscmd.bat |"))  {
    die "Can't run ltscmd.bat! $!\n";
  }
}
else {
  open (LTSPIPE,$infile) || die "Unable to open $infile\n"; 
  print "Input will be read from $infile\n";
}

# Print Headings ....
print "Tablespace listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($NowTS) .... \n\n";
printf "%-4s %-18s %-25s %-25s %-6s %9s %9s %9s %9s %5s %9s %9s\n",
       '', '', '', '', '', '', '', '', '', 'Page','';
printf "%-4s %-18s %-25s %-25s %-6s %9s %9s %9s %9s %5s %9s %9s\n",
       'TSID', 'Tablespace Name', 'Type', 'Contents', 'State', 'Total Pgs', 'Used Pgs', 'Free Pgs', 'HWM', 'Size','Used Mb', 'Alloc Mb';
printf "%-4s %-18s %-25s %-25s %-6s %9s %9s %9s %9s %5s %9s %9s\n",
       '----', '----------------', '-------------------------', '-------------------------', '------', '---------', '---------', '---------', '---------', '-----', '---------', '---------';

my $abort = 0;
my $TSID;
my $DefStorage;
my $Type;
my $Name;
my $Contents;
my $TPages;
my $UPages;
my $FPages;
my $HWM;
my $PSize;
my $State;
my $MbAlloc ;
my $MbUsed;

while (<LTSPIPE>) {

    if ( $abort ) { next; }

    if ( $debugLevel > 0 ) { print "Input: $_\n"; }

    if ( $_ =~ /SQL1024N/) {
      if ($database eq "") {
        print "A database connection must be established before running this program - perhaps you forgot to put the database on the command line \n";
        $abort = 1;
      }
      else {
        print "A database connection must be established before running this program - perhaps $database is not the database name \n";
        $abort = 1;
      }
    }

    my @ltsinfo = split(/=/);

    if ( $debugLevel > 0 ) { print "$ltsinfo[0] : $ltsinfo[1]\n"; }

    if ( trim($ltsinfo[0]) eq "Tablespace ID") {
      $TSID = trim($ltsinfo[1]);
      $DefStorage = "";
    }

    if ( trim($ltsinfo[0]) eq "Name") {
      $Name = trim($ltsinfo[1]);
    }

    if ( trim($ltsinfo[0]) eq "Type") {
      $Type = trim($ltsinfo[1]);
    }

    if ( trim($ltsinfo[0]) eq "Contents") {
      $Contents = trim($ltsinfo[1]);
      if ($Contents eq "All permanent data. Regular table space.") {
        $Contents = "All permanent data. RegTS";
      }
      elsif ($Contents eq "All permanent data. Large table space.") {
        $Contents = "All permanent data. LrgTS";
      }
    }

    if ( trim($ltsinfo[0]) eq "Storage may be defined") {
      if ( $DefStorage ne "Def Stor" ) {
        # if this is the case then the wont be any page size info coming .....
        $DefStorage = "Rest Pend";
        $TPages = "N/A";
        $UPages = "N/A";
        $FPages = "N/A";
        $HWM = "N/A";
        $PSize = "N/A";
        if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
          printf "%-4s %-16s %-25s %-25s %-6s %9s %9s %9s %9s %5s %-8s\n",
               $TSID,$Name,$Type,$Contents,$State,$TPages,$UPages,$FPages,$HWM,$PSize,$DefStorage;
        }
      }
    }

    if ( trim($ltsinfo[0]) eq "Storage must be defined") {
      # if this is the case then the wont be any page size info coming .....
      $DefStorage = "Def Stor";
      $TPages = "N/A";
      $UPages = "N/A";
      $FPages = "N/A";
      $HWM = "N/A";
      $PSize = "N/A";
      if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
        printf "%-4s %-18s %-25s %-25s %-6s %9s %9s %9s %9s %5s %-8s\n",
               $TSID,$Name,$Type,$Contents,$State,$TPages,$UPages,$FPages,$HWM,$PSize,$DefStorage;
      }
    }

    if ( trim($ltsinfo[0]) eq "State") {
      $State = trim($ltsinfo[1]);
    }

    if ( trim($ltsinfo[0]) eq "Offline") {
      if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
        printf "%-4s %-18s %-25s %-25s %-6s %9s %9s %9s %9s %5s %9s\n",
               $TSID,$Name,$Type,$Contents,$State,'***','Offline','***      ','','',''; 
      }
    }

    if ( trim($ltsinfo[0]) eq "Total pages") {
      $TPages = trim($ltsinfo[1]);
      if ( $TPages eq "Not applicable" ) {
        $TPages = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "Used pages") {
      $UPages = trim($ltsinfo[1]);
      if ( $UPages eq "Not applicable" ) {
        $UPages = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "High water mark (pages)") {
      $HWM = trim($ltsinfo[1]);
      if ( $HWM eq "Not applicable" ) {
        $HWM = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "Free pages") {
      $FPages = trim($ltsinfo[1]);
      if ( $FPages eq "Not applicable" ) {
        $FPages = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "Page size (bytes)") {
      $PSize = trim($ltsinfo[1]);
      # and now the printout .....

      $MbAlloc = ($TPages * $PSize)/1024/1024;
      my $dig = index($MbAlloc,".",0);
      if ($dig == -1) {
        $dig  = length($MbAlloc) + 1;
        $MbAlloc = $MbAlloc . ".00";
      }
      else {
        $MbAlloc = "$MbAlloc$Zeroes";
      }
     # ----------------------------------------------------------------
     # Not sure what the following code achieved .... time will tell 
     # if ( $FPages eq "N/A" ) {
     #   $MbAlloc = "N/A";
     # }
     # ----------------------------------------------------------------
      $MbAlloc = substr($MbAlloc,0,$dig + 3);
      $TotAlloc = $TotAlloc + $MbAlloc;
      $MbUsed = ($UPages * $PSize)/1024/1024;
      $TotUsed = $TotUsed + $MbUsed;
      my $dig = index($MbUsed,".",0);
      if ($dig == -1) {
        $dig  = length($MbUsed) + 1;
        $MbUsed = $MbUsed . ".00";
      }
      else {
        $MbUsed = "$MbUsed$Zeroes";
      }
      $MbUsed = substr($MbUsed,0,$dig + 3);

      if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
        printf "%-4s %-18s %-25s %-25s %-6s %9s %9s %9s %9s %5s %9s %9s\n",
               $TSID,$Name,$Type,$Contents,$State,$TPages,$UPages,$FPages,$HWM,$PSize,$MbUsed,$MbAlloc; 
        # Not 100% sure that DefStorage can ever appear on this line!
        # printf "%-4s %-16s %-25s %-25s %-6s %9s %9s %9s %9s %5s %9s %-8s\n",
        #        $TSID,$Name,$Type,$Contents,$State,$TPages,$UPages,$FPages,$HWM,$PSize,$MbUsed,$DefStorage; 
      }

    }

}

$TotAlloc = $TotAlloc / 1024;
my $dig = index($TotAlloc,".",0);
if ($dig == -1) {
  $dig  = length($TotAlloc) + 1;
  $TotAlloc = $TotAlloc . ".00";
}
else {
  $TotAlloc = "$TotAlloc";
}
$TotAlloc = substr($TotAlloc,0,$dig + 3);

$TotUsed = $TotUsed / 1024;
$dig = index($TotUsed,".",0);
if ($dig == -1) {
  $dig  = length($TotUsed) + 1;
  $TotUsed = $TotUsed . ".00";
}
else {
  $TotUsed = "$TotUsed";
}
$TotUsed = substr($TotUsed,0,$dig + 3);

print "\nTotal Storage in use for $database is $TotUsed Gb out of $TotAlloc Gb allocated\n\n";

if ($OS eq "Windows" ) {
 `del ltscmd.bat`;
}
else {
 `rm ltscmd.bat`;
}

