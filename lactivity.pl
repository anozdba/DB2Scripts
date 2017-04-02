#!/usr/bin/perl
# --------------------------------------------------------------------
# lactivity.pl
#
# $Id: lactivity.pl,v 1.4 2014/05/25 22:24:31 db2admin Exp db2admin $
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

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hso -d <database> [-n <number> [-D <delay>]]  [-a <applid>] [-c]
       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to list
       -a              : APPLID to list out
       -c              : Only print entries that are changing (the 1st 'total' entry will not be displayed
       -n              : number of iteration
       -D              : delay between each iteration (secs)
       \n ";
}

if ( $^O eq "MSWin32") {
  $machine = `hostname`;
  $OS = "Windows";
  BEGIN {
    $scriptDir = 'c:\udbdba\scripts';
    $tmp = rindex($0,"\\");
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}
else {
  $machine = `uname -n`;
  $machine_info = `uname -a`;
  @mach_info = split(/\s+/,$machine_info);
  $OS = $mach_info[0] . " " . $mach_info[2];
  BEGIN {
    $scriptDir = "c:\udbdba\scripts";
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}

require "commonFunctions.pl";

# Set default values for variables

$silent = "No";
$database = "";
$SelProc = "ALL";
$DisHead = "Yes";
$iterations = 1;
$delay = 1;
$changeOnly = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hscoD:n:d:a:";

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt($getOpt_opt) ) {
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
          die "Can't run du! $!\n";
      }

  while (<LTSPIPE>) {
      # print "$CurrSection   : Processing $_\n";
      # parse the db2 get snapshot for all applications response

      if ( $_ =~ /SQL1024N/) {
        die "A database connection must be established before running this program\n";
      }

      $linein = $_;

      @appsnapinfo = split(/=/,$linein);

      if ( trim($appsnapinfo[0]) eq "Application Snapshot") {
        $CurrSection = "AppSnap";
      }

      if ( trim($appsnapinfo[0]) eq "Database Connection Information") {
        $CurrSection = "DBConnection";
      }

      if ( trim($appsnapinfo[0]) eq "Application handle") {
        $AppID = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "CONNECT Authorization ID") {
        $AuthID = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Database name") {
        $DBName = trim($appsnapinfo[1]);
      }
      if ( trim($appsnapinfo[0]) eq "Snapshot timestamp") {
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
        
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
          if ( ($database eq $DBName ) || ( $database eq "") ) {
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

