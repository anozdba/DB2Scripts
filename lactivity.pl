#!/usr/bin/perl
# --------------------------------------------------------------------
# lactivity.pl
#
# $Id: lactivity.pl,v 1.9 2019/02/07 04:18:54 db2admin Exp db2admin $
#
# Description:
# Script to show activity on the system
#
# Usage:
#   lactivity.pl -h 
#
# $Name:  $
#
# ChangeLog:
# $Log: lactivity.pl,v $
# Revision 1.9  2019/02/07 04:18:54  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.8  2019/01/25 03:12:40  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.7  2018/10/21 21:01:49  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.6  2018/10/18 22:58:50  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.5  2018/10/15 23:53:26  db2admin
# 1. convert from commonFunction.pl to commonFunctions.pm
# 2. add in some debug displays
#
# Revision 1.4  2014/05/25 22:24:31  db2admin
# correct the allocation of windows include directory
#
# Revision 1.3  2009/03/05 02:54:40  db2admin
# remove unneeded code
#
# Revision 1.2  2009/03/05 02:41:32  db2admin
# add option to not prit out unchanged entries
#
# Revision 1.1  2009/03/05 02:25:16  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------"

my $ID = '$Id: lactivity.pl,v 1.9 2019/02/07 04:18:54 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

# Global Variables

my $debugLevel = 0;
my $machine;   # machine we are running on
my $OS;        # OS running on
my $scriptDir; # directory the script ois running out of
my $tmp ;
my $machine_info;
my @mach_info;
my $logDir;
my $dirSep;
my $tempDir;
my $currentRoutine = 'Main';
my $debugLevel = 0;

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scripts';
    my $tmp = rindex($0,'\\');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $logDir = 'logs\\';
    $tmp = rindex($0,'\\');
    $dirSep = '\\';
    $tempDir = 'c:\temp\\';
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    my $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $logDir = `cd; pwd`;
    chomp $logDir;
    $logDir .= '/logs/';
    $dirSep = '/';
    $tempDir = '/var/tmp/';
  }
}
use lib "$scriptDir";
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hso -d <database> [-n <number> [-D <delay>]]  [-a <applid>] [-c] [-v[v]]

       Script to show activity on the system

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to list
       -a              : APPLID to list out
       -c              : Only print entries that are changing (the 1st 'total' entry will not be displayed
       -n              : number of iteration
       -D              : delay between each iteration (secs)
       \n ";
}

sub printDebug {

  # ------------------------------------------------------------------------------
  # Routine to print out debug information
  # ------------------------------------------------------------------------------

  my $routine = shift;   # routine calling for debug print
  my $level = shift;     # debug level at whic1G/timeDiffh to print
  my $test = shift;      # message

  my $timestamp = getCurrentTimestamp;
  $routine = substr("$routine                    ",0,20);

  if ( $debugLevel >= $level ) {    # print it if the debug level is correct
    print "$timestamp - $routine - $test\n";
  }
}

# Set default values for variables

my $silent = "No";
my $database = "";
my $SelProc = "ALL";
my $DisHead = "Yes";
my $iterations = 1;
my $delay = 1;
my $changeOnly = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hscoD:n:d:a:v") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "o") || ($getOpt_optName eq "ONLY") )  {
   if ( $silent ne "Yes") {
     print "Only selected Applications will be displayed - no Application Summary will be produced\n";
   }
   $DisHead = "No";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Applications on database $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( $silent ne "Yes") {
     print "Only changing entries will be displayed\n";
   }
   $changeOnly = 1;
 }
 elsif (($getOpt_optName eq "a"))  {
   if ( $silent ne "Yes") {
     print "Only Applid $getOpt_optValue will be listed in detail\n";
   }
   $SelProc = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "n"))  {
   @t = ( $getOpt_optValue =~ /([0-9]*).*/) ;
   if ($t[0] ne "" ) {
     $iterations = $t[0];
   }
   if ( $silent ne "Yes") {
     print "$iterations iterations will be performed\n";
     if ( $iterations ne $getOpt_optValue ) {
       usage ( "There seems to be a problem with the -n parameter ($getOpt_optValue). Is it correct?");
       exit;
     }
   }
 }
 elsif (($getOpt_optName eq "D"))  {
   @t = ( $getOpt_optValue =~ /([0-9]*).*/) ;
   if ($t[0] ne "" ) {
     $delay = $t[0];
   }
   if ( $silent ne "Yes") {
     print "A delay of $delay seconds will be generated between iterations\n";
     if ( $delay ne $getOpt_optValue ) {
       usage ( "There seems to be a problem with the -D parameter ($getOpt_optValue). Is it correct?");
       exit;
     }
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Applications on database $database will be listed\n";
     }
   }
   elsif ( $APPID eq "" ) {
     $SelProc = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Only Applid $SelProc will be listed\n";
     }
   }
   else {
     usage ("Parameter $getOpt_optName : Will be ignored");
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------


chomp $machine;
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
$day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
$Now = "$year.$month.$day $hour:$minute:$second";

$zeroes = "00";
$lines = 0;
$CurrSection = "";

printDebug($currentRoutine, 1, "Starting run");

while ( $iterations > 0 ) {
  $iterations--;

  # Print Headings ....
  if ( $lines % 30 == 0 ) {
    printf "%5s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %7s %7s\n",
           'AppID','  AuthID','    Time','PhysRead','  Writes','NumSelct','NumUpdts','Rows Del','Rows Ins','Rows Upd','Rows Sel','RowsRead','RowsWrtn','   UCPU','   SCPU';
  }
  printf "%5s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %7s %7s\n",
         '-----','--------','--------','--------','--------','--------','--------','--------','--------','--------','--------','--------','--------','-------','-------';
  $lines++;

  if (! open (LTSPIPE,"db2 get snapshot for all applications |"))  {
          die "Can't run db2 get snapshot! $!\n";
      }

  while (<LTSPIPE>) {
      chomp;
      # parse the db2 get snapshot for all applications response
      printDebug($currentRoutine, 2, "$CurrSection - Processing: $_");

      if ( $_ =~ /SQL1024N/) {
        die "A database connection must be established before running this program\n";
      }

      $linein = $_;

      @appsnapinfo = split(/=/,$linein);

      if ( trim($appsnapinfo[0]) eq "Application Snapshot") {
        printDebug($currentRoutine, 1, "$CurrSection - Change of section");
        $CurrSection = "AppSnap";
      }

      if ( trim($appsnapinfo[0]) eq "Database Connection Information") {
        printDebug($currentRoutine, 1, "$CurrSection - Change of section");
        $CurrSection = "DBConnection";
      }

      if ( trim($appsnapinfo[0]) eq "Application handle") {
        printDebug($currentRoutine, 1, "$CurrSection - APPLID = $AppID");
        $AppID = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "CONNECT Authorization ID") {
        printDebug($currentRoutine, 1, "$CurrSection - AuthID = $AuthID");
        $AuthID = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Database name") {
        printDebug($currentRoutine, 1, "$CurrSection - DBName = $DBName");
        $DBName = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Snapshot timestamp") {
        printDebug($currentRoutine, 1, "$CurrSection - SnapTime = $SnapTime");
        $SnapTime = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Buffer pool data physical reads") {
        $BPDPhysReads = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Buffer pool data writes") {
        $BPDDataWrites = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Select SQL statements executed") {
        $NumSelects = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Update/Insert/Delete statements executed") {
        $NumUpdates = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Rows deleted") {
        if ($currSection eq  "WorkspaceInformation") {
          $STRowsDeleted = trim($appsnapinfo[1]);
        }
        else {
          $RowsDeleted = trim($appsnapinfo[1]);
        }
      }
      if ( trim($appsnapinfo[0]) eq "Rows inserted") {
        if ($currSection eq  "WorkspaceInformation") {
          $STRowsInserted = trim($appsnapinfo[1]);
        }
        else {
          $RowsInserted = trim($appsnapinfo[1]);
        }
      }
      if ( trim($appsnapinfo[0]) eq "Rows updated") {
        if ($currSection eq  "WorkspaceInformation") {
          $STRowsUpdated = trim($appsnapinfo[1]);
        }
        else {
          $RowsUpdated = trim($appsnapinfo[1]);
        }
      }
      if ( trim($appsnapinfo[0]) eq "Rows selected") {
        $RowsSelected = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Rows read") {
        if ($currSection eq  "WorkspaceInformation") {
          $STRowsRead = trim($appsnapinfo[1]);
        }
        else {
          $RowsRead = trim($appsnapinfo[1]);
        }
      }
      if ( trim($appsnapinfo[0]) eq "Rows written") {
        if ($currSection eq  "WorkspaceInformation") {
          $STRowsWritten = trim($appsnapinfo[1]);
        }
        else {
          $RowsWritten = trim($appsnapinfo[1]);
        }
      }
      if ( trim($appsnapinfo[0]) eq "Total User CPU Time used by agent (s)") {
        $UserCPUTime = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Total System CPU Time used by agent (s)") {
        $SystemCPUTime = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Workspace Information") {
        $CurrSection = "WorkspaceInformation";
        printDebug($currentRoutine, 1, "$CurrSection - Change of section");
        
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
          if ( (uc($database) eq uc($DBName) ) || ( $database eq "") ) {
            ## output the CPU Time details .....
            if (! defined( $lastValues{$AppID} ) ) {
              if ( $changeOnly == 0 ) { 
                $lines++;
                printf "%5s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %7.1f %7.1f\n",
                     $AppID,$AuthID,substr($SnapTime,11,8),$BPDPhysReads,$BPDDataWrites,$NumSelects,$NumUpdates,$RowsDeleted,$RowsInserted,$RowsUpdated,$RowsSelected,$RowsRead,$RowsWritten,$UserCPUTime,$SystemCPUTime;
              }
            }
            else { # just show the difference
              @last = split(/\|/,$lastValues{$AppID});
              $totChange = $BPDPhysReads-$last[3]+$BPDDataWrites-$last[4]+$NumSelects-$last[5]+$NumUpdates-$last[6]+$RowsDeleted-$last[7]+$RowsInserted-$last[8]+$RowsUpdated-$last[9]+$RowsSelected-$last[10]+$RowsRead-$last[11]+$RowsWritten-$last[12]+$UserCPUTime-$last[13]+$SystemCPUTime-$last[14];
              if ( ($totChange > 0) || ($changeOnly == 0 ) ) {
                $lines++;
                printf "%5s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %7.1f %7.1f\n",
                     $AppID,$AuthID,substr($SnapTime,11,8),$BPDPhysReads-$last[3],$BPDDataWrites-$last[4],$NumSelects-$last[5],$NumUpdates-$last[6],$RowsDeleted-$last[7],$RowsInserted-$last[8],$RowsUpdated-$last[9],$RowsSelected-$last[10],$RowsRead-$last[11],$RowsWritten-$last[12],$UserCPUTime-$last[13],$SystemCPUTime-$last[14];
              }
            }
            $lastValues{$AppID} = "$AppID|$AuthID|$SnapTime|$BPDPhysReads|$BPDDataWrites|$NumSelects|$NumUpdates|$RowsDeleted|$RowsInserted|$RowsUpdated|$RowsSelected|$RowsRead|$RowsWritten|$UserCPUTime|$SystemCPUTime";
          }
        }
      }
  }
  if ( $iterations > 0 ) {
    sleep ($delay);
  }
}

