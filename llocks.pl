#!/usr/bin/perl
# --------------------------------------------------------------------
# llocks.pl
#
# $Id: llocks.pl,v 1.24 2019/04/16 21:18:13 db2admin Exp db2admin $
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
# Revision 1.24  2019/04/16 21:18:13  db2admin
# reorder the ingestData parms
#
# Revision 1.23  2019/03/14 00:22:19  db2admin
# 1. Alter the way that the silent variable is used
# 2. Use the default DB if no database is presented
#
# Revision 1.22  2019/03/05 22:21:20  db2admin
# Add in some descriptive notes
#
# Revision 1.21  2019/03/05 22:11:55  db2admin
# completely revamp the script
# 1. start using ingestdata to read the command output
# 2. improve blocking reporting
# 3. add in option -c to only display those keys that appear in multiple applications
#
# Revision 1.20  2019/02/07 04:18:55  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.19  2019/01/25 03:12:41  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
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

use strict; 

my $ID = '$Id: llocks.pl,v 1.24 2019/04/16 21:18:13 db2admin Exp db2admin $';
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
use commonFunctions qw(displayDebug ingestData trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel  $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

# Global variables

my $silent = 0;
my $debugLevel = 0;
my $printDetail = 1;
my $APPID = "All";
my $DBName_Sel = "";
my $inFile = "";
my $ignoreZero = 0;
my $abbrev = 0;
my $excludeFW = 0;
my $inFWThread = 0;
my %data = ();     # the array to hold the ingested data
my @blockedQ;
my %indent;
my $currentRoutine = 'main';
my $printAllLocks = 1;

###############################################################################
# Subroutines and functions ......                                            #

sub checkForDuplicate {
  # -----------------------------------------------------------
  #  check for duplicate locks
  # -----------------------------------------------------------

  my $currentRoutine = 'checkForDuplicate';

  my $currAppl = shift;     # current application ID - locks on this applid will not be checked
  my $lockname = shift;     # lock name to check for

  my $ret = 0;
  foreach my $appl ( sort by_key keys %data) {       # looping through each of the application records
    if ( $appl ne $currAppl ) {
      # check if this application has a lockname that matches
      if ( exists($data{$appl}{$lockname}) ) {
        if ( $data{$appl}{"Application status"} eq 'Lock-wait' ) { $ret = 1; } # cant be certain this one is the culprit
        else {
          return $appl;    # once you find a non-waiting duplicate it is probably the blocker
        }
      }
    }
  }

  return $ret; # no match found

} # end of checkForDuplicate

sub lookForBlocked {

  # ----------------------------------------------------------
  # Loop through the data structure and identify those applids
  # that are currently waiting on the passed applid
  # ----------------------------------------------------------

  my $parent = shift;
  my $currentID = shift;
  my $level = shift;

  push ( @blockedQ, "$parent|$currentID" ) ;
  $indent{$currentID} = $level;                      # retain the indent level for this entry
  foreach my $appl ( sort by_key keys %data) {       # looping through each of the application records
    if ( $data{$appl}{"ID of agent holding lock"} eq $currentID ) {  # this applid is blocking other threads
      lookForBlocked ( $currentID, $appl, $level+4);  # check to see if the child is a blocker
    }

  }

} # end of lookForBlocked

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsSb [BLOCKERS] [SUMMARY] -d <database> [-a <appid>] [-f <filename>] [-c] [-z] [-A] [-X] [-v[v]]

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
       -c              : only show conflicted locks (locks being used by more than 1 applID)
       -v              : debug level

       Note: This script formats the output of a 'db2 get snapshot for locks on <db>' command
       \n ";
} # end of usage

sub processParameters {

  # ----------------------------------------------------
  # -- Start of Parameter Section
  # ----------------------------------------------------

  while ( getOpt(":?hszvcAXf:Sb:d:a:|^BLOCKERS|^SUMMARY") ) {
    if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
      usage ("");
      exit;
    }
    elsif (($getOpt_optName eq "s"))  {
      $silent = 1;
    }
    elsif (($getOpt_optName eq "S") || ($getOpt_optName eq "b") || ($getOpt_optName eq "SUMMARY") || ($getOpt_optName eq "BLOCKERS") )  {
      if ( ! $silent ) {
        print "Only produce a Summary Report\n";
      }
      $printDetail = 0;
    }
    elsif (($getOpt_optName eq "f"))  {
      if ( ! $silent ) {
        print "Locks will be read from file $getOpt_optValue (File should have been generated using 'db2 get snapshot for locks on $DBName_Sel')\n";
      }
      $inFile = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "d"))  {
      if ( ! $silent ) {
        print "Locks on database $getOpt_optValue will be listed\n";
      }
      $DBName_Sel = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "c"))  {
      if ( ! $silent ) {
        print "Only locks being used by more than 1 application ID will be displayed\n";
      }
      $printAllLocks = 0;
    }
    elsif (($getOpt_optName eq "A"))  {
      if ( ! $silent ) {
        print "Lock listing will be in abbreviated format\n";
      }
      $abbrev = 1;
    }
    elsif (($getOpt_optName eq "a"))  {
      if ( ! $silent ) {
        print "Only Applid $getOpt_optValue will be listed\n";
      }
      $APPID = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "v"))  {
      $debugLevel++;
      if ( ! $silent ) {
        print "debug level set to $debugLevel\n";
      }
    }
    elsif (($getOpt_optName eq "X"))  {
      if ( ! $silent ) {
        print "Event Monitor threads will not be displayed\n";
      }
      $excludeFW = 1;
    }
    elsif (($getOpt_optName eq "z"))  {
      if ( ! $silent ) {
        print "Only Applications holding locks will be listed\n";
      }
      $ignoreZero = 1;
    }
    elsif ( $getOpt_optName eq ":" ) {
      usage ("Parameter $getOpt_optValue requires a parameter");
      exit;
    }
    else { # handle other entered values ....
      if ( $DBName_Sel eq "" ) {
        $DBName_Sel = $getOpt_optValue;
        if ( ! $silent ) {
          print "Locks on database $DBName_Sel will be listed\n";
        }
      }
      elsif ( $APPID eq "" ) {
        $APPID = $getOpt_optValue;
        if ( ! $silent ) {
          print "Only Applid $APPID will be listed\n";
        }
      }
      else {
        usage ("Parameter $getOpt_optName : Will be ignored");
      }
    }
  }
} # end of processparameters

# End of Subroutines and functions ......                                     #
###############################################################################

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
my $date = "$year.$month.$day";

# set variables based on parameters
processParameters();

$cF_debugLevel = $debugLevel;

if ( $inFile eq "" ) {
  if ($DBName_Sel eq "") {
    my $tmpDB = $ENV{'DB2DBDFT'};
    if ( ! defined($tmpDB) ) {
      usage ("A database must be provided");
      exit;
    }
    else {
      if ( ! $silent ) {
        print "Database defaulted to $tmpDB\n";
      }
      $DBName_Sel = $tmpDB;
    }
  }
}

my $lockpipe;
if ( $inFile ne "" ) {
  displayDebug("Lock report will be read from $inFile",1,$currentRoutine);
  if ( $inFile eq 'STDIN' ) {
    if (! open ($lockpipe,"-"))  { die "Can't open STDIN for input $!\n"; }
  }
  else {
    if (! open ($lockpipe,"<","$inFile"))  { die "Can't open $inFile for input$!\n"; }
  }
}
else {
  displayDebug("Issuing: db2 get snapshot for locks on $DBName_Sel",1,$currentRoutine);
  if (! open ($lockpipe,"db2 get snapshot for locks on $DBName_Sel |"))  { 
    die "Can't run du! $!\n";
  }
}

# entries to be gathered form the lock list

my %valid_entries = (
  "Agents currently waiting on locks" => 1,
  "Application handle"                => 1,
  "Application ID"                    => 1,
  "Application name"                  => 1,
  "Application status"                => 1,
  "Applications currently connected"  => 1,
  "CONNECT Authorization ID"          => 1,
  "Hold Count"                        => 1,
  "ID of agent holding lock"          => 1,
  "Lock Name"                         => 1,
  "Lock name"                         => 1,
  "Lock Object Name"                  => 1,
  "Locks held"                        => 1,
  "Lock attributes"                   => 1,
  "Lock Attributes"                   => 1,
  "Lock Count"                        => 1,
  "Lock mode requested"               => 1,
  "Lock Object Name"                  => 1,
  "Lock object type"                  => 1,
  "Mode"                              => 1,
  "Object Type"                       => 1,
  "Release flags"                     => 1,
  "Release Flags"                     => 1,
  "Snapshot timestamp"                => 1,
  "Table Name"                        => 1,
  "Table Schema"                      => 1,
  "Tablespace Name"                   => 1
);

# load the report data into aninternal data structure
ingestData ($lockpipe, '=', \%valid_entries, \%data, '', 'Application handle','','Lock Name','');

# close the input file

close $inFile;

# now print out the loaded data

my $zeroLockCount = 0;
my $firstApplInfo = 1;      # flag for printing headings for app data
my $firstLockInfo = 1;      # flag for printing headings for lock data
my $currentLock = '';       # current lock value to look for duplicates in an 'abbreviated' report
my $testLock = '';          # test lock value to look for duplicates in an 'abbreviated' report
my $duplicateCount = 0;     
my $lockLit = 'Lockname';   

if ( $printDetail ) { # print out the lock detail
  foreach my $appl ( sort by_key keys %data) { # looping through each of the application records

    displayDebug("Application ID $appl being processed",1, $currentRoutine);

    if ( $appl eq 'root' ) { next; } # skip root entry

    if ( $ignoreZero && ( $data{$appl}{"Locks held"} == 0) ) { # zero locks and requested to ignore zero locks
      $zeroLockCount++;
      next;
    }

    if ( ($APPID ne "All") && ( $appl ne $APPID ) ) { # only a specific ApplID is to be displayed
      next;
    }
    if ( $excludeFW && ( $data{$appl}{"Application name"} =~ /db2fw/ ) ) { # FW (evmon) threads are to be excluded
      next;
    }

    if ( $firstApplInfo ) {
      printf "\n %5s %-20s %-10s %-20s %9s\n", 'AppID','Application Name','AuthID','Status','Num Locks';
      printf " %5s %-20s %-10s %-20s %9s\n", '-----','--------------------','---------','--------------------','---------';
      $firstApplInfo = 0;
    }

    printf " %5s %-20s %-10s %-20s %9s\n", $appl,$data{$appl}{"Application name"},$data{$appl}{"CONNECT Authorization ID"},$data{$appl}{"Application status"},$data{$appl}{"Locks held"};

    # print out any requested but blocked locks .....

    my $firstLockInfo = 1;
    if ( exists($data{$appl}{"ID of agent holding lock"}) ) { # we have a lock holder
      printf "\n    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
             'Block', 'Lock Name','Lock Attr','Rlse Flags','#LK','#HD','LockObj','Mode','Tablespace Name','Schema','Table Name','Type';
      printf "    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
             '-----', '----------------------------','----------','----------','---','---','----------','----','---------------','--------','--------------------','------------------------------';
      $firstLockInfo = 0;
      $firstApplInfo = 1;

      printf " RQ %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
             $data{$appl}{"ID of agent holding lock"}, $data{$appl}{"Lock name"}, $data{$appl}{"Lock Attributes"}, $data{$appl}{"Release Flags"}, '0', '0',
             ' ', $data{$appl}{"Lock mode requested"}, ' ',
             ' ', ' ', $data{$appl}{"Lock object type"};

    }

    if ( $debugLevel > 0 ) { # print out the available keys
      foreach my $key ( sort keys %{$data{$appl}} ) { # looping through the 'Lock Name records'
        displayDebug("Key: $key",1,$currentRoutine);
      }
    }

    # Loop through the locks here .......

    foreach my $lock ( sort keys %{$data{$appl}} ) { # looping through the 'Lock Name records'
      my $lockDupl = '    ';      # initially assume lock is not duplicated
      if ( $lock =~ 'Lock Name:' ) {
        if ( $firstLockInfo ) {
          printf "\n    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
                 'Block', 'Lock Name','Lock Attr','Rlse Flags','#LK','#HD','LockObj','Mode','Tablespace Name','Schema','Table Name','Type';
          printf "    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
                 '-----', '----------------------------','----------','----------','---','---','----------','----','---------------','--------','--------------------','------------------------------';
          $firstLockInfo = 0;
          $firstApplInfo = 1;
        }

        my $checkDup = checkForDuplicate($appl, $lock);
        if ( $checkDup ) { # lock is duplicated elsewhere
          if ( $checkDup eq '1' ) {
            $lockDupl = 'DUPL';
          }
          else {
            $lockDupl = $checkDup;  # return value was the ID holding the lock
          }
        }

        my $lname = substr($lock,10);

        if ( $abbrev ) { # abbreviated report - dont print duplicate lock records
          if ( $data{$appl}{$lock}{"Object Type"} eq 'Row' ) { # row lock
            $currentLock = $appl . '|' .  $data{$appl}{$lock}{"Lock Attributes"} . '|' . $data{$appl}{$lock}{"Release Flags"} . '|' . $data{$appl}{$lock}{"Mode"} .
                           $data{$appl}{$lock}{"Object Type"} . '|' . $data{$appl}{$lock}{"Tablespace Name"} . '|' . $data{$appl}{$lock}{"Table Schema"} . '|' . $data{$appl}{$lock}{"Table Name"};
          }
          else {
            $currentLock = $appl . '|' .  $data{$appl}{$lock}{"Lock Attributes"} . '|' . $data{$appl}{$lock}{"Release Flags"} . '|' . $data{$appl}{$lock}{"Lock Object Name"} . '|' . $data{$appl}{$lock}{"Mode"} .
                           $data{$appl}{$lock}{"Object Type"} . '|' . $data{$appl}{$lock}{"Tablespace Name"} . '|' . $data{$appl}{$lock}{"Table Schema"} . '|' . $data{$appl}{$lock}{"Table Name"};
          }
          if ( $currentLock ne $testLock ) { # not a duplicate line so print it
            if ( $duplicateCount > 0 ) { # there were duplicates ....
              $duplicateCount++;         
              print "                  Above line repeated $duplicateCount times (though $lockLit may have differed)\n";
            }
            if ( $printAllLocks || ($lockDupl ne '    ') ) {
              printf "    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
                     $lockDupl, $lname, $data{$appl}{$lock}{"Lock Attributes"}, $data{$appl}{$lock}{"Release Flags"}, $data{$appl}{$lock}{"Lock Count"}, $data{$appl}{$lock}{"Hold Count"},
                     $data{$appl}{$lock}{"Lock Object Name"}, $data{$appl}{$lock}{"Mode"}, $data{$appl}{$lock}{"Tablespace Name"},
                     $data{$appl}{$lock}{"Table Schema"}, $data{$appl}{$lock}{"Table Name"}, $data{$appl}{$lock}{"Object Type"};
            }
            $duplicateCount = 0;          # start the count again
            $testLock = $currentLock;     # change the 'testing' lock
            if ( $data{$appl}{$lock}{"Object Type"} eq 'Row' ) { # row lock
              $lockLit = 'Lockname and Lock Object Name';   
            }
            else {
              $lockLit = 'Lockname';   
            }
          }
          else { # the locks are the same so just increment the count
            $duplicateCount++;
          }
        }
        else { # not an abbreviated report
          if ( $printAllLocks || ($lockDupl ne '    ') ) {
            printf "    %5s %-28s %-10s %-10s %3s %3s %10s %-4s %-15s %-8s %-20s %-30s\n",
                   $lockDupl, $lname, $data{$appl}{$lock}{"Lock Attributes"}, $data{$appl}{$lock}{"Release Flags"}, $data{$appl}{$lock}{"Lock Count"}, $data{$appl}{$lock}{"Hold Count"},
                   $data{$appl}{$lock}{"Lock Object Name"}, $data{$appl}{$lock}{"Mode"}, $data{$appl}{$lock}{"Tablespace Name"},
                   $data{$appl}{$lock}{"Table Schema"}, $data{$appl}{$lock}{"Table Name"}, $data{$appl}{$lock}{"Object Type"};
          }
        }
      }
    }
  }

  print "\n\nNOTE: Entries in the Block column indicate that the lock is shared with that applicatiion - not that it is blocking\n";
  print "      A RQ to the left of a lock indicates that it is a blocked lock request. In this case the entry in the block column is the blocking Appl ID\n";
  if ( $ignoreZero ) {
    print "      $zeroLockCount applications threads were ignored as they had zero locks\n\n";
  }

}

print "\n\nLock Summary (Blockers only):\n\n";

# Print out lock conflicts

# identify the non-locked blockers first and save them to an array ( this will also make each selected ID unique) ......
%indent = ();                      # indent level for each applID
my %activeLockHolders = ();           # array of applids of active lock holders
foreach my $appl ( sort by_key keys %data) {       # looping through each of the application records
  if ( exists($data{$appl}{"ID of agent holding lock"}) ) { # we have a lock holder
    my $lockHolder = $data{$appl}{"ID of agent holding lock"};
    if ( $data{$lockHolder}{"Application status"} ne 'Lock-wait' ) {    # not waiting so it is active
      $activeLockHolders{$lockHolder} = 1;
    }
  }
}

# gather blocking information for each of the active threads
foreach my $lh (sort keys %activeLockHolders ) {
  lookForBlocked( 0, $lh, 0) ;  
}

# print out the locking hierachy

my $currentParent = '0';
my $currentIndent = 0;

foreach my $entry ( @blockedQ ) {
  my ( $parent, $child ) = split (/\|/, $entry);

  $currentIndent = ' ' x $indent{$child};
  print $currentIndent . "Applid: $child, " . $data{$child}{"CONNECT Authorization ID"} . " (" . $data{$child}{"Application status"} . ")\n";

}

print "\n";

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

