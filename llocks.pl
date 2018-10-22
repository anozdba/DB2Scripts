#!/usr/bin/perl
# --------------------------------------------------------------------
# llocks.pl
#
# $Id: llocks.pl,v 1.18 2018/10/21 21:01:50 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET SNAPSHOT FOR LOCKS ON <DB> command
#
# Usage:
#   llocks.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: llocks.pl,v $
# Revision 1.18  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.17  2018/10/18 22:58:51  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.16  2018/10/17 01:13:31  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.15  2017/07/03 05:14:38  db2admin
# modify so that only processes in LOCK-WAIT will be thought of as being blocked
#
# Revision 1.14  2017/05/28 02:15:52  db2admin
# add in option to exclude the monitor threads
#
# Revision 1.13  2014/05/25 22:27:17  db2admin
# correct the allocation of windows include directory
#
# Revision 1.12  2010/06/10 00:53:26  db2admin
# changed the way blocked/blocking are treated
#
# Revision 1.11  2010/06/09 22:09:35  db2admin
# initialise the lock detail variables
#
# Revision 1.10  2009/12/08 22:30:04  db2admin
# remove windows CR/LF
#
# Revision 1.9  2009/12/08 22:29:02  db2admin
# Adjust 'Abbreviated' locks mode to cope withj row level locking
#
# Revision 1.8  2009/12/08 05:31:57  db2admin
# Add in 'abbreviate' option to reduce repetition
#
# Revision 1.7  2009/10/19 00:45:17  db2admin
# Improve details on help panel
#
# Revision 1.6  2009/03/16 06:08:11  db2admin
# improve lock blocking report
#
# Revision 1.5  2009/03/11 05:45:49  db2admin
# Add in code to read the locks info from a file
#
# Revision 1.4  2009/03/03 00:12:27  db2admin
# Improve error checking
#
# Revision 1.3  2008/12/14 22:13:05  db2admin
# remove debug line and correct bug
#
# Revision 1.2  2008/12/14 22:08:24  m08802
# Add in new parameter subroutine and convert to allow Windows execution
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

my $ID = '$Id: llocks.pl,v 1.18 2018/10/21 21:01:50 db2admin Exp db2admin $';
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
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $myDate_debugLevel $getOpt_diagLevel $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime $datecalc_debugLevel displayMinutes timeDiff timeAdd timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsSb [BLOCKERS] [SUMMARY] -d <database> [-a <appid>] [-f <filename>] [-z] [-A] [-X]

       Script to format the output of a GET SNAPSHOT FOR LOCKS ON <DB> command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -b or BLOCKERS  : Synonym for Summary
       -S or SUMMARY   : Only print a summary
       -f              : file to read info from
       -s              : Silent mode (dont produce the report)
       -d              : Database to list 
       -a              : APPLID to list out 
       -z              : ignore entries not holding locks
       -X              : ignore entries for event monitors (db2fw*)
       -A              : abbreviated listing

       Note: This script formats the output of a 'db2 get snapshot for locks on <db>' command
       \n ";
}

# Set default values for variables

$silent = "No";
$PrtDet = "Y";
$APPID = "ALL";
$DBName_Sel = "";
$inFile = "";
$ignoreZero = "No";
$abbrev = "No";
$excludeFW = 0;
$inFWThread = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hszAXf:Sb:d:a:|^BLOCKERS|^SUMMARY";

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
 elsif (($getOpt_optName eq "S") || ($getOpt_optName eq "b") || ($getOpt_optName eq "SUMMARY") || ($getOpt_optName eq "BLOCKERS") )  {
   if ( $silent ne "Yes") {
     print "Only produce a Summary Report\n";
   }
   $PrtDet = "N";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "Locks will be read from file $getOpt_optValue\n";
     print " File should have been generated using 'db2 get snapshot for locks on $DBName_Sel'\n";
   }
   $inFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Locks on database $getOpt_optValue will be listed\n";
   }
   $DBName_Sel = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "A"))  {
   if ( $silent ne "Yes") {
     print "Lock listing will be in abbreviated format\n";
   }
   $abbrev = "Yes";
 }
 elsif (($getOpt_optName eq "a"))  {
   if ( $silent ne "Yes") {
     print "Only Applid $getOpt_optValue will be listed\n";
   }
   $APPID = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print "Event Monitor threads will not be displayed\n";
   }
   $excludeFW = 1;
 }
 elsif (($getOpt_optName eq "z"))  {
   if ( $silent ne "Yes") {
     print "Only Applications holding locks will be listed\n";
   }
   $ignoreZero = "Yes";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $DBName_Sel eq "" ) {
     $DBName_Sel = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Locks on database $DBName_Sel will be listed\n";
     }
   }
   elsif ( $APPID eq "" ) {
     $APPID = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Only Applid $APPID will be listed\n";
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

if ( $inFile eq "" ) {
  if ($DBName_Sel eq "") {
    usage ("A database must be provided");
    exit;
  }
}

if ( $inFile ne "" ) {
  if (! open (LOCKPIPE,"<$inFile"))  { 
    die "Can't open $inFile $!\n"; 
  }
}
else {
  if (! open (LOCKPIPE,"db2 get snapshot for locks on $DBName_Sel |"))  { 
    die "Can't run du! $!\n";
  }
}

$zeroLockCount = 0;
$APPprt = "N";
$LOCKprt = "N";
$Gloss = "\nGlossary:\n";

# Print Headings ....
print "Lock listing from $DBName_Sel  ($Now) .... \n";

while (<LOCKPIPE>) {
    # print "Processing $_\n";

    # parse the db2 list tablespaces show detail

  #             Database Lock Snapshot
  #
  # Database name                              = EAITRKU1
  # Database path                              = /opt/db2/dbpath/eaihin1u/NODE0000/SQL00002/
  # Input database alias                       = EAITRKU1
  # Locks held                                 = 47
  # Applications currently connected           = 11
  # Agents currently waiting on locks          = 0
  # Snapshot timestamp                         = 09-01-2008 11:46:27.191344
  #
  # Application handle                         = 932
  # Application ID                             = GA188A4C.H2F3.080109004206
  # Sequence number                            = 0024
  # Application name                           = db2jcc_application
  # CONNECT Authorization ID                   = EAIHIN1U
  # Application status                         = UOW Waiting
  # Status change time                         = Not Collected
  # Application code page                      = 1208
  # Locks held                                 = 39
  # Total wait time (ms)                       = Not Collected
  #
  # List Of Locks
  #  Lock Name                   = 0x000200090002FF090000000052
  #  Lock Attributes             = 0x00000020
  #  Release Flags               = 0x40000000
  #  Lock Count                  = 1
  #  Hold Count                  = 0
  #  Lock Object Name            = 180233
  #  Object Type                 = Row
  #  Tablespace Name             = USERSPACE1
  #  Table Schema                = EAIHIN1U
  #  Table Name                  = EXPLAIN_STREAM
  #  Mode                        = X

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }
    elsif ( $_ =~ /SQL1427N/ ) {
      die "An instance connection has not been made.\nCHeck to ensure that the Database connection is for a local (indirect) database and not remote\n";
    }
    elsif ( $_ =~ /SQL1390C/ ) {
      die "The instance specified in DB2INSTANCE is invalid.\n";
    }

    @lockinfo = split(/=/);

    # for early version of HPUX/perl looks like leading spaces generate a NULL in the first array element on SPLIT
    # so we need to identify the offsets to check ....

    if ( trim($lockinfo[0]) eq "Locks held") {
      $LocksHeld = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Applications currently connected") {
      $NumApp = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "ID of agent holding lock") {
      $lockingApp = trim($lockinfo[1]);
      if ( defined($BLOCKED{$lockingApp}) ) {
        $BLOCKED{$lockingApp} = $BLOCKED{$lockingApp} . " " . $AppHandle;
      }
      else {
        $BLOCKED{$lockingApp} = $AppHandle;
      }
      $BLOCKING{$lockingApp} = $lockingApp;
    }

    if ( trim($lockinfo[0]) eq "Agents currently waiting on locks") {
      $AppWaiting = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Snapshot timestamp") {
      $SnapTime = trim($lockinfo[1]);
      print "\n$NumApp Apps connected, $LocksHeld Locks held, $AppWaiting Apps waiting on locks\n";
    }

    if ( trim($lockinfo[0]) eq "Application handle") {
      $AppHandle = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Application name") {
      $AppName = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "CONNECT Authorization ID") {
      $AuthID = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Application status") {
      $Status = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Total wait time (ms)") {
      # Dump some app stuff ....
      if ( ( $ignoreZero ne "Yes") || (( $ignoreZero eq "Yes" ) && ( $LocksHeld > 0))  ) {
        if ( ($APPID eq $AppHandle) || ($APPID eq "ALL") ) {
          if ( $AppName =~ /db2fw/ ) { $inFWThread = 1; }
          else { $inFWThread = 0; }
          if ( ( $excludeFW && ($AppName !~ /db2fw/)) || ! $excludeFW  ) { # dont print event handlers
            $APPDETAILS{$AppHandle} = sprintf "%5s %-20s %-10s %-20s %6s\n",
                   $AppHandle,$AppName,$AuthID,$Status,$LocksHeld;
            if ($PrtDet eq "Y") {
              if ($APPprt eq "N") {
                printf "\n %5s %-20s %-10s %-20s %6s\n",
                       'AppID','Application Name','AuthID','Status','Num Locks';
                printf "%5s %-20s %-10s %-15s %6s\n",
                       '-----','--------------------','---------','--------------------','---------';
                $LOCKprt = "N";
                $APPprt = "Y";
              }
              printf "%5s %-20s %-10s %-20s %6s\n",
                     $AppHandle,$AppName,$AuthID,$Status,$LocksHeld;
            }
          }
        }
      }
      else {
        $zeroLockCount++;
      }
    }

    if ( trim($lockinfo[0]) eq "Lock Name") {
      $LockName = trim($lockinfo[1]);
      # initialise some of the following fields 
      $TabShema = "";
      $TSName = "";
      $TabName = "";
      $LockAttr = "";
      $RelFlags = "";
      $LockCnt = "";
      $HoldCnt = "";
      $LockObjName = "";
      $ObjType= "";
      $Mode = "";
    }

    if ( trim($lockinfo[0]) eq "Lock Attributes") {
      $LockAttr = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Release Flags") {
      $RelFlags = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Lock Count") {
      $LockCnt = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Hold Count") {
      $HoldCnt = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Lock Object Name") {
      $LockObjName = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Object Type") {
      $ObjType= trim($lockinfo[1]);
      if ( $ObjType eq 'Internal Variation Lock') {
        if ( $Gloss =~ /is INTVL/) {
          $ObjType = "INTVL";
        }
        else {
          $Gloss = $Gloss . "\n$ObjType is ";
          $ObjType = "INTVL";
          $Gloss = $Gloss . "$ObjType";
        }
      }
      elsif ( $ObjType eq 'Internal' ) {
        if ( $Gloss =~ /is INTNL /) {
          $ObjType = "INTNL";
        }
        else {
          $Gloss = $Gloss . "\n$ObjType is ";
          $ObjType = "INTNL";
          $Gloss = $Gloss . "$ObjType ";
        }
      }
      elsif ( $ObjType eq 'Internal Plan Lock' ) {
        if ( $Gloss =~ /is INTPL/) {
          $ObjType = "INTPL";
        }
        else {
          $Gloss = $Gloss . "\n$ObjType is ";
          $ObjType = "INTPL";
          $Gloss = $Gloss . "$ObjType";
        }
      }
      elsif ( $ObjType eq 'Internal Catalog Cache Lock' ) {
        if ( $Gloss =~ /is INTCL/) {
          $ObjType = "INTCL";
        }
        else {
          $Gloss = $Gloss . "\n$ObjType is ";
          $ObjType = "INTCL";
          $Gloss = $Gloss . "$ObjType";
        }
      }
    }

    if ( trim($lockinfo[0]) eq "Tablespace Name") {
      $TSName = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Table Schema") {
      $TabSchema = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Table Name") {
      $TabName = trim($lockinfo[1]);
    }

    if ( trim($lockinfo[0]) eq "Mode") {
      $Mode = trim($lockinfo[1]);
      $APPprt = "N";

      if ( $HoldCnt == 0 ) {
        if ( ($Status eq 'Lock-wait') ) { 
          if ( defined($BLOCKED{$LockName}) ) {
            $BLOCKED{$LockName} = $BLOCKED{$LockName} . " " . $AppHandle;
          }
          else {
            $BLOCKED{$LockName} = $AppHandle;
          }
        }
      }
      else {
        if ( defined($BLOCKING{$LockName}) ) {
          $BLOCKING{$LockName} = $BLOCKING{$LockName} . " " . $AppHandle;
        }
        else {
          $BLOCKING{$LockName} = $AppHandle;
        }
      }

      # Dump some lock stuff ....
      if ( ($APPID eq $AppHandle) || ($APPID eq "ALL") ) {
        if ( (! $excludeFW) || ( $excludeFW && ! $inFWThread) ) {
          $LOCKDETAILS{$AppHandle . $LockName} = sprintf "LOCK: %5s %-28s %-10s %-10s %3s %3s %7s %-4s %-5s %-15s %-8s %-20s\n",
                 $AppHandle,$LockName,$LockAttr,$RelFlags,$LockCnt,$HoldCnt,$LockObjName,$Mode,$ObjType,$TSName,$TabSchema,$TabName;
          if ($PrtDet eq "Y") {
            if ($LOCKprt eq "N") {
              printf "\n    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-5s %-15s %-8s %-20s\n",
                     'AppID','Lock Name','Lock Attr','Rlse Flags','#LK','#HD','LockObj','Mode','Type','Tablespace Name','Schema','Table Name';
              printf "    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-5s %-15s %-8s %-20s\n",
                     '-----','----------------------------','----------','----------','---','---','----------','----','-----','---------------','--------','--------------------';
              $LOCKprt = "Y";
              $currKey = "";
              $dupCnt = 0;
            }
            if ( $abbrev eq "Yes" ) {
              if ( $ObjType eq "Row" ) {
                $TestKey = "$AppHandle,$LockAttr,$RelFlags,$Mode,$ObjType,$TSName,$TabSchema,$TabName" ;
              }
              else {
                $TestKey = "$AppHandle,$LockAttr,$RelFlags,$LockObjName,$Mode,$ObjType,$TSName,$TabSchema,$TabName" ;
              }
  
              if ( $currKey ne $TestKey ) {
                if ( $dupCnt > 0 ) {
                  $dupCnt++;
                  print "                  Above line repeated $dupCnt times (though $lockLit may have differed)\n";
                }
                else { # first time for this record 
                  printf "LK: %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-5s %-15s %-8s %-20s\n",
                         $AppHandle,$LockName,$LockAttr,$RelFlags,$LockCnt,$HoldCnt,$LockObjName,$Mode,$ObjType,$TSName,$TabSchema,$TabName;
                }
                $dupCnt = 0;
              }
              else {
                $dupCnt++;
              }
            }
            else {
              printf "LK: %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-5s %-15s %-8s %-20s\n",
                     $AppHandle,$LockName,$LockAttr,$RelFlags,$LockCnt,$HoldCnt,$LockObjName,$Mode,$ObjType,$TSName,$TabSchema,$TabName;
            }
   
            if ( $ObjType eq "Row" ) {
              $currKey = "$AppHandle,$LockAttr,$RelFlags,$Mode,$ObjType,$TSName,$TabSchema,$TabName";
              $lockLit = "Lockname and Lock Object Name";
            }
            else {
              $currKey = "$AppHandle,$LockAttr,$RelFlags,$LockObjName,$Mode,$ObjType,$TSName,$TabSchema,$TabName";
              $lockLit = "Lockname";
            }
          }
        }
      }
    }
}

if ( $abbrev eq "Yes" ) {
  if ( $dupCnt > 0 ) {
    $dupCnt++;
    print "                  Above line repeated $dupCnt times (though $lockLit may have differed)\n";
  }
}

if ($ignoreZero eq "Yes" ) {
  print "\n\nNOTE: $zeroLockCount applications threads were ignored as they had zero locks\n\n";
}
print "$Gloss\n\nLock Summary (Blockers only):\n\n";

# Print out lock conflicts only

foreach $key (sort by_key keys %BLOCKED ) {
  @BlockingList = split(/\s+/,$BLOCKING{$key});
  foreach $blockingapp (@BlockingList) {
    printf "               %5s %-20s %-10s %-20s %6s\n",
           'AppID','Application Name','AuthID','Status','Num Locks';
    printf "               %5s %-20s %-10s %-15s %6s\n",
           '-----','--------------------','---------','--------------------','---------';
    printf "           %5s %-28s %-10s %-10s %3s %3s %7s %-4s %-5s %-15s %-8s %-20s\n",
           'AppID','Lock Name','Lock Attr','Rlse Flags','#LK','#HD','LockObj','Mode','Type','Tablespace Name','Schema','Table Name';
    printf "           %5s %-28s %-10s %-10s %3s %3s %7s %-4s %-5s %-15s %-8s %-20s\n",
           '-----','----------------------------','----------','----------','---','---','-------','----','-----','---------------','--------','--------------------';
    print "## Lock Holder $APPDETAILS{$blockingapp}";
    print "     $LOCKDETAILS{$blockingapp . $key}";
    @BlockedList = split(/\s+/,$BLOCKED{$key});
    foreach $blockedapp (@BlockedList) {
      print ">>>>>> Blocked $APPDETAILS{$blockedapp}";
      print "     $LOCKDETAILS{$blockedapp . $key}";
    }
  }
}

print "\n";

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

