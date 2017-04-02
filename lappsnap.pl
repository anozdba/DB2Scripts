#!/usr/bin/perl
# --------------------------------------------------------------------
# lappsnap.pl
#
# $Id: lappsnap.pl,v 1.15 2017/03/25 10:19:20 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET SNAPSHOT FOR ALL APPLICATIONS command
#
# Usage:
#   lappsnap.pl <database name> [<app handle> [ONLY]]
#
# $Name:  $
#
# ChangeLog:
# $Log: lappsnap.pl,v $
# Revision 1.15  2017/03/25 10:19:20  db2admin
# 1. add in US date format option
# 2. move the connection date closer to the front of the summary line to allow sorting
#
# Revision 1.14  2014/05/25 22:25:06  db2admin
# correct the allocation of windows include directory
#
# Revision 1.13  2013/09/19 05:49:24  db2admin
# Correct bug where information being displayed when it shouldn't be
#
# Revision 1.12  2013/07/17 01:52:33  db2admin
# if IP address isn't available use machine name
#
# Revision 1.11  2013/05/21 07:01:45  db2admin
# Correct identification of the Process ID
#
# Revision 1.10  2012/02/24 06:10:12  db2admin
# Correct collection of SQL statement
#
# Revision 1.9  2009/11/20 03:54:08  db2admin
# Add in line feed at end of help
#
# Revision 1.8  2009/11/20 03:52:34  db2admin
# add in memory details
#
# Revision 1.7  2009/10/14 22:08:16  db2admin
# Add in information on the command being formatted
#
# Revision 1.6  2009/04/13 22:07:51  db2admin
# change database comparisons to be case insensitive
#
# Revision 1.5  2009/02/22 22:09:38  db2admin
# correct the way that databases were excluded
#
# Revision 1.4  2008/12/16 00:47:19  db2admin
# Remove connect string from script to allow it to run on Windows properly
#
# Revision 1.3  2008/12/16 00:33:56  m08802
# Modify to work on Windows platforms, put in usage information
# and implement better parameter handling
#
# Revision 1.2  2008/10/13 21:14:47  m08802
# Add in additional parameter to limit output to ONLY the selected app handle
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

$ID = '$Id: lappsnap.pl,v 1.15 2017/03/25 10:19:20 db2admin Exp db2admin $';
@V = split(/ /,$ID);
$Version=$V[2];
$Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hso [ONLY] -d <database> [-a <appid>] [-L] [-C] [-M] [-B] [-S] [-v[v]] 

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -o              : Only print out the selected APPLid
       -d              : Database to list
       -a              : APPLID to list out
       -C              : print out CPU related information
       -M              : Print out Memory Pool information
       -B              : Print out Buffer Pool Statistics
       -S              : Print out SQL Statistics
       -L              : Print out Lock information
       -U              : US Date Format
       -v              : set debug level

       NOTE: This script basically formats the ouptut of a 'db2 get snapshot for all applications' command
        
             If none of C, M, B, S, L is entered then all will be displayed
\n" ;
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
$disCPU = "No";
$disMem = "No";
$disBuff = "No";
$disSQL = "No";
$disLock = "No";
$debugLevel = 0;
$usDate = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsovCUMBLSd:a:|^ONLY";

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
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "U"))  {
   $usDate = 1;
   if ( $silent ne "Yes") {
     print "US Date fornat\n";
   }
 }
 elsif (($getOpt_optName eq "C"))  {
   if ( $silent ne "Yes") {
     print "CPU statistics will be displayed\n";
   }
   $disCPU = "Yes";
 }
 elsif (($getOpt_optName eq "L"))  {
   if ( $silent ne "Yes") {
     print "Lock information will be displayed\n";
   }
   $disLock = "Yes";
 }
 elsif (($getOpt_optName eq "M"))  {
   if ( $silent ne "Yes") {
     print "Memory statistics will be displayed\n";
   }
   $disMem = "Yes";
 }
 elsif (($getOpt_optName eq "B"))  {
   if ( $silent ne "Yes") {
     print "Buffer Pool statistics will be displayed\n";
   }
   $disBuff = "Yes";
 }
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "SQL statistics will be displayed\n";
   }
   $disSQL = "Yes";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Applications on database $getOpt_optValue will be listed\n";
   }
   $database = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "a"))  {
   if ( $silent ne "Yes") {
     print "Only Applid $getOpt_optValue will be listed in detail\n";
   }
   $SelProc = $getOpt_optValue;
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = uc($getOpt_optValue);
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

if ( "$disLock$disMem$disCPU$disSQL$disBuff" =~ "Yes" ) {
  # no action - one of the options has been set
}
else {
  if ( $silent ne "Yes") {
    print "All components will be displayed\n";
  }

  $disCPU = "Yes";
  $disMem = "Yes";
  $disBuff = "Yes";
  $disSQL = "Yes";
  $disLock = "Yes";
} 

$zeroes = "00";
$currSection = "";

if (! open (LTSPIPE,"db2 get snapshot for all applications |"))  {
        die "Can't run du! $!\n";
    }

# Print Headings ....
print "Application Snapshot Summary ($Now) .... \n\n";

while (<LTSPIPE>) {
    if ( $debugLevel > 0 ) {  print "$currSection   : $_\n"; }

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    $linein = $_;

    @appsnapinfo = split(/=/,$linein);
    $x = trim($appsnapinfo[0]);
    if ( $debugLevel > 1 ) {  print "$currSection   : $x = $appsnapinfo[1]\n"; }

    if ( trim($appsnapinfo[0]) eq "Application Snapshot") {
      $currSection = "AppSnap";
      $memHeadPrinted = "No";
    }

    if ( trim($appsnapinfo[0]) eq "Database Connection Information") {
      $currSection = "DBConnection";
    }

    if ( trim($appsnapinfo[0]) eq "Memory usage for agent:") {
      $currSection = "Memory";
    }

    if ( trim($appsnapinfo[0]) eq "Application handle") {
      $AppID = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Application status") {
      $AppStatus = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Application name") {
      $AppName = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Connection request start timestamp") {
      $ConnStart = trim($appsnapinfo[1]);
      if ( $usDate ) { # US Date format
        my $tmp_mm = substr($ConnStart,0,2);
        my $tmp_dd = substr($ConnStart,3,2);
        my $tmp_yy = substr($ConnStart,6,4);
        my $tmp_time = substr($ConnStart,11);
        $ConnStart = "$tmp_yy-$tmp_mm-$tmp_dd $tmp_time";
      }
    }
    if ( trim($appsnapinfo[0]) eq "CONNECT Authorization ID") {
      $AuthID = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Client login ID") {
      $ClientID = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Configuration NNAME of client") {
      $ClientMachine = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Inbound communication address") {
      $ClientIP = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Database name") {
      $DBName = uc(trim($appsnapinfo[1]));
    }
    if ( trim($appsnapinfo[0]) eq "Snapshot timestamp") {
      $SnapTime = trim($appsnapinfo[1]);
    }
#    if ( trim($appsnapinfo[0]) eq "Coordinator agent process or thread ID") {
    if ( trim($appsnapinfo[0]) eq "Process ID of client application") {
      $ProcessID = trim($appsnapinfo[1]);

      if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
        if ( ($database eq $DBName ) || ( $database eq "") ) {
          ## output the db details .....
          print "\nDatabase: $DBName App ID: $AppID App Name: $AppName Process ID: $ProcessID  Snapshot Time: $SnapTime\n";

          ## output the client details .....
          printf "\n%-5s %-20s %-20s %-26s %-8s %-8s %-15s %-8s\n",
                 'AppID','App Status','App Name','Connection Start Time','Auth ID','ClientID','Client IP','Machine';
          printf "%-5s %-20s %-20s %-26s %-8s %-8s %-15s %-8s\n",
                 '-----','--------------------','--------------------','--------------------------','--------','--------','---------------','------------------------';
          printf "%-5s %-20s %-20s %-26s %-8s %-8s %-15s %-8s\n",
                 $AppID,$AppStatus,$AppName,$ConnStart,$AuthID,$ClientID,$ClientIP,$ClientMachine;
        }
      }
      else {
        if ( ($database eq $DBName ) || ( $database eq "") ) {
          ## output the db details .....
          if ( $DisHead eq "Yes") {
            if ($ClientIP eq "" ) { $ClientIP = $ClientMachine; }
            print "\nDatabase: $DBName Conn Start: $ConnStart App ID: $AppID App Name: $AppName Process ID: $ProcessID Auth ID: $AuthID Client ID: $ClientID Client IP: $ClientIP\n";
          }
        }
      }
    }
    if ( trim($appsnapinfo[0]) eq "Locks held by application") {
      $LocksHeld = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Blocking cursor") {
      $blocking = trim($appsnapinfo[1]);
      if ( $disLock eq "Yes" ) {
        if ( ($database eq $DBName ) || ( $database eq "") ) {
          if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
            ## output the lock details .....
            if ( $blocking eq "YES" ) {
              print "\nBlocking Cursor = $blocking (AppID=$AppID, App Name=$AppName, Auth ID=$AuthID, Client ID=$ClientID, Machine=$ClientMachine)\n";
            }
            else {
              print "\nBlocking Cursor = $blocking\n";
            }
          }
        }
      }
    }
    if ( trim($appsnapinfo[0]) eq "Lock waits since connect") {
      $LockWaits = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Time application waited on locks (ms)") {
      if ( trim($appsnapinfo[1]) eq "Not Collected" ) {
        $LockWaitTime = "NC";
        $LockWaitTime = trim($appsnapinfo[1]);   # length isn't an issue here
      }
      else {
        $LockWaitTime = trim($appsnapinfo[1]);
      }

      if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")   || ($SelProc eq $AppID)) {
        if ( $disLock eq "Yes" ) {
          if ( ($database eq $DBName ) || ( $database eq "") ) {
            ## output the lock details .....
            print "\nLocks Held: $LocksHeld  Lock Waits: $LockWaits  Lock Wait Time: $LockWaitTime\n";
          }
        }
      }
    }
    if ( $appsnapinfo[1] eq  "Not Collected" ) {
      $appsnapinfo[1] = "NC";
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool data logical reads") {
      $BPDLogReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool data physical reads") {
      $BPDPhysReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool temporary data logical reads") {
      $BPTDLogReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool temporary data physical reads") {
      $BPTDPhysReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool data writes") {
      $BPDDataWrites = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool index logical reads") {
      $BPILogReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool index physical reads") {
      $BPIPhysReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool temporary index logical reads") {
      $BPTILogReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool temporary index physical reads") {
      $BPTIPhysReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Buffer pool index writes") {
      $BPIndexWrites = trim($appsnapinfo[1]);
      
      if ( $disBuff eq "Yes" ) {
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")   || ($SelProc eq $AppID)) {
          if ( $BPIndexWrites ne "NC" ) {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              ## output the buffer Pool details .....
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     '   Data  ','   Data  ','Temp Data','Temp Data','   Data  ','  Index  ','  Index  ','Temp Idx ','Temp Idx ','  Index  ';
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     'Log Reads','PhysReads','Log Reads','PhysReads','  Writes ','Log Reads','PhysReads','Log Reads','PhysReads','  Writes ';
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     '---------','---------','---------','---------','---------','---------','---------','---------','---------','---------';
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     $BPDLogReads,$BPDPhysReads,$BPTDLogReads,$BPTDPhysReads,$BPDDataWrites,$BPILogReads,$BPIPhysReads,$BPTILogReads,$BPTIPhysReads,$BPIndexWrites;
            }
          }
          else {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              print "Buffer Pool information not being collected\n";
            }
          }
        }
      } 
    }
    if ( trim($appsnapinfo[0]) eq "Direct reads") {
      $DirectReads = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Direct writes") {
      $DirectWrites = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Direct reads elapsed time (ms)" ) {
      $DirectReadTime = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Direct write elapsed time (ms)") {
      $DirectWriteTime = trim($appsnapinfo[1]);
      
      if ( $disBuff eq "Yes" ) {
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")   || ($SelProc eq $AppID)) {
          if ( $DirectReads ne "NC" ) {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              ## output the buffer Pool details .....
              printf "%9s %9s %9s %9s\n",
                     '  Direct ','  Direct ','  Direct ','  Direct ';
              printf "%9s %9s %9s %9s\n",
                     '  Reads  ','  Writes ','Read Time','Write Tm ';
              printf "%9s %9s %9s %9s\n",
                     '---------','---------','---------','---------';
              printf "%9s %9s %9s %9s\n",
                     $DirectReads,$DirectWrites,$DirectReadTime,$DirectWriteTime;
            }
          }
          else {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              print "Direct Read/Write information not being collected\n";
            }
          }
        } 
      }
    }
    if ( trim($appsnapinfo[0]) eq "Number of SQL requests since last commit") {
      $NumSQLReqs = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Commit statements") {
      $NumCommits = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Rollback statements") {
      $NumRollbacks = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Select SQL statements executed") {
      $NumSelects = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Update/Insert/Delete statements executed") {
      $NumUpdates = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "DDL statements executed") {
      $NumDDL = trim($appsnapinfo[1]);
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
    if ( trim($appsnapinfo[0]) eq "Rows fetched") {
      $STRowsFetched = trim($appsnapinfo[1]);
      
      if ( $disSQL eq "Yes" ) { 
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")   || ($SelProc eq $AppID)) {
          if ( $RowsWritten ne "NC" ) {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              ## output the buffer Pool details .....
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     '  Number ','   Sort  ','  Number ',' # Rows  ','  Rows   ','  Rows   ','  Rows   ','  Rows   ';
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     'of Sorts ','CPU Time ','Rows Read',' Written ',' Deleted ',' Inserted',' Updated ',' Fetched ';
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     '---------','---------','---------','---------','---------','---------','---------','---------';
              printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                     $STNumSorts,$STSortTime,$STRowsRead,$STRowsWritten,$STRowsDeleted,$STRowsInserted,$STRowsUpdated,$RowsFetched;
            }
          }
          else {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              print "Statement Row information not being collected\n";
            }
          }
        } 
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
      
        if ( $disSQL eq "Yes" ) {
          if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
            if ( $RowsWritten ne "NC" ) {
              if ( ($database eq $DBName ) || ( $database eq "") ) {
                ## output the buffer Pool details .....
                printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                       '   SQL   ','  Number ','  Number ','  Number ','  Number ','  Number ','  Rows   ','  Rows   ','  Rows   ','  Rows   ','  Rows   ','  Rows   ';
                printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                       ' Requests',' Commits ','Rollbacks',' Selects ',' Updates ','   DDL   ',' Deleted ',' Inserted',' Updated ',' Selected','   Read  ',' Written ';
                printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                       '---------','---------','---------','---------','---------','---------','---------','---------','---------','---------','---------','---------';
                printf "%9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s %9s\n",
                       $NumSQLReqs,$NumCommits,$NumRollbacks,$NumSelects,$NumUpdates,$NumDDL,$RowsDeleted,$RowsInserted,$RowsUpdated,$RowsSelected,$RowsRead,$RowsWritten;
              }
            }
            else {
              if ( ($database eq $DBName ) || ( $database eq "") ) {
                print "Row information not being collected\n";
              }
            } 
          }
        }
      }
    }
    if ( trim($appsnapinfo[0]) eq "UOW log space used (Bytes)") {
      $LogSpaceUsed = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Total User CPU Time used by agent (s)") {
      $UserCPUTime = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Total System CPU Time used by agent (s)") {
      $SystemCPUTime = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Workspace Information") {
      $currSection = "WorkspaceInformation";
      
      if ( $disCPU eq "Yes" ) {
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
          if ( ($database eq $DBName ) || ( $database eq "") ) {
            ## output the CPU Time details .....
            printf "%9s %9s %9s\n",
                   '   Log   ','   User  ','  System ';
            printf "%9s %9s %9s\n",
                   'Spc Used ','CPU Time ','CPU Time ';
            printf "%9s %9s %9s\n",
                   '---------','---------','---------';
            printf "%9s %9s %9s\n",
                   $LogSpaceUsed,$UserCPUTime,$SystemCPUTime;
          }
        }
      }
    }
    if ( trim($appsnapinfo[0]) eq "Most recent operation") {
      $MostRecentOp = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Most recent operation start timestamp") {
      $MostRecentOpTime = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Cursor name") {
      $CursorName = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Statement") {
      $Statement = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Statement start timestamp") {
      $StatementStart = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Total Statement user CPU time") {
      $StatementUserCPU = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Total Statement system CPU time") {
      $StatementSystemCPU = trim($appsnapinfo[1]);
      
      if ( $disSQL eq "Yes" ) {
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")   || ($SelProc eq $AppID)) {
          if ( ($database eq $DBName ) || ( $database eq "") ) {
            ## output the Statement details .....
            printf "%-27s %9s %9s %-15s\n",
                   '','   User  ','  System ','';
            printf "%-27s %9s %9s %-15s\n",
                   'Statement Start Time','CPU Time ','CPU Time ','Statement';
            printf "%-27s %9s %9s %-15s\n",
                   '---------------------------','---------','---------','----------------';
            printf "%-27s %9s %9s %-15s\n",
                   $StatementStart,$StatementUserCPU,$StatementSystemCPU,$Statement;
          }
        }
      }
    }
    if ( trim($appsnapinfo[0]) eq "Statement sorts") {
      $STNumSorts = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Total sort time") {
      $STSortTime = trim($appsnapinfo[1]);
    }
    if ($currSection eq "SQLStatement") {
      if ( trim($appsnapinfo[0]) eq "Agent process/thread ID" ) {
        $currSection = "";
      
        if ( $disSQL eq "Yes" ) {
          if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
            if ( ($database eq $DBName ) || ( $database eq "") ) {
              ## output the Statement details .....
              print "SQL Statement:\n";
              print "$SQLStatement\n";
              print "*****END*****\n";
              $SQLStatement = "";
            }
          }
        }
      }
      else {
        $SQLStatement = "$SQLStatement $linein";
      }
    }
    if ( trim($appsnapinfo[0]) eq "Dynamic SQL statement text:") {
      $currSection = "SQLStatement";
      $SQLStatement = "";
    }

    # Memory Pool information
    if ( trim($appsnapinfo[0]) eq "Memory Pool Type") {
      $currPool = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Current size (bytes)" ) {
      $currPoolSize = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "High water mark (bytes)") {
      $currPoolHWM = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Configured size (bytes)") {
      $currPoolConf = trim($appsnapinfo[1]);
      if ( $disMem eq "Yes" ) {
        if ( ($SelProc eq $ProcessID) || ($SelProc eq "ALL")  || ($SelProc eq $AppID) ) {
          if ( ($database eq $DBName ) || ( $database eq "") ) {
            if ( $memHeadPrinted eq "No" ) { 
              $memHeadPrinted = "Yes";
              ## output the Pool details .....
              printf "%-30s %12s %12s %12s\n",
                     'Memory Pool','Current','HWM','Configured';
              printf "%-30s %12s %12s %12s\n",
                     '------------------------------','------------','------------','------------';
            }
            printf "%-30s %12s %12s %12s\n",
                   $currPool,$currPoolSize,$currPoolHWM,$currPoolConf;
          }
        }
      }
    }
}

