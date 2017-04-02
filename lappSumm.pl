#!/usr/bin/perl
# --------------------------------------------------------------------
# lappSumm.pl
#
# $Id: lappSumm.pl,v 1.5 2014/05/25 22:25:26 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET SNAPSHOT FOR ALL APPLICATIONS command
# to provide a summary of activity for the instance
#
# Usage:
#   lappSumm.pl <database name> 
#
# $Name:  $
#
# ChangeLog:
# $Log: lappSumm.pl,v $
# Revision 1.5  2014/05/25 22:25:26  db2admin
# correct the allocation of windows include directory
#
# Revision 1.4  2013/05/28 21:53:15  db2admin
# Correct spelling mistake in message
#
# Revision 1.3  2013/05/28 21:51:54  db2admin
# alter jdbc message
#
# Revision 1.2  2013/05/28 06:20:40  db2admin
# Add in some detail of the processes
#
# Revision 1.1  2013/05/24 02:43:13  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

$ID = '$Id: lappSumm.pl,v 1.5 2014/05/25 22:25:26 db2admin Exp db2admin $';
@V = split(/ /,$ID);
$Version=$V[2];
$Changed="$V[3] $V[4]";

sub by_key {
  $a cmp $b ;
}

sub noteApp {

  $tempName = $_[0];
  $tempName_0_5 = substr($tempName,0,5);
  if ( $tempName_0_5 eq "db2fw" ) { # monitor fast write
    $key = $tempName_0_5 ;
  }
  elsif ( $tempName_0_5 eq "db2bm" ) { # Backup and restore buffer manipulator
    $key = $tempName_0_5 ;
  }
  elsif ( substr($tempname,0,6) eq "db2med" ) { # backup and restore media controller
    $key = substr($tempname,0,6) ;
  }
  elsif ( substr($tempname,0,6) eq "db2evm" ) { # event monitor process
    $key = substr($tempname,0,6) ;
  }
  else { # just use the app Name
    $key = $tempName ;
  }

  if ( $debugLevel > 0 ) { print "App $tempName identified as $key\n"; }
  if ( defined($apps{$key} ) ) { # app already registered
    $apps{$key}++; 
  }
  else {
    $apps{$key} = 1; 
  }
}

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs -d <database> [-v[v]] [-c] [-C] [-U|-S|-A] [-z]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to list
       -c              : delta values are cummulative from first run
       -C              : start accumulating again
       -U              : user cpu time will be displayed
       -S              : system cpu time will be displayed
       -A              : system and user cpu time will be added together and displayed
       -z              : only display entries that have had a CPU or DB Call change
       -v              : set debug level

       NOTE: This script basically formats the ouptut of a 'db2 get snapshot for all applications' command

             The command db2pd -edus may show more details about what is happening

             Options -u, -s and -a are mutually exlusive - the last one on the command line will be used (-a is the default)

       DB2 Processes:
         Listeners : Are used to initiate contact with the database. 
                     db2ipccm - listener for IPC connect requests
                     db2tcpcm - listener for TCP connect requests
                     db2tcpdm - listener for TCP Discovery Tools connect requests
         Agents    : Are used to perform task for a client
                     db2agent   - coordinating client. For partitioned tables and parallelism will coordinate other agents
                     db2agntp   - partitioned call agent
                     db2agnts   - intraquery parallelism
                     db2agnti   - process to run event monitors
                     db2agnsc   - subcoordinator agent used to parallelize db restart
                     db2agentg  - gateway agent
                     db2agntgp  - pooled gateway agent (pooled agent for a remote database)
                     db2agentdp - pooled database agent (pooled agent for a local database)
          Fenced   : Are used to run stored procedures and user defined functions to isolate them from
                             database code and memory structures
                     db2fmp
          Vendor   : Executes vendor code on behalf of an EDU (i.e. log archiving)     
                     db2vend
          Database EDUs :
                     db2dlock - for deadlock detection
                     db2glock - for deadlock detection in a partitioned database environment
                     db2fwX   - an event monitor fast writer (used for event monitor) thread where 'X' identifies the thread number
                     db2hadrp - the high availability disaster recovery (HADR) primary server thread
                     db2hadrs - the HADR standby server thread
                     db2lfr   - for log file readers that process individual log files
                     db2loggr - for manipulating log files to handle transaction processing and recovery
                     db2loggw - for writing log records to the log files
                     db2logmgr- for the log manager. Manages log files for a recoverable database
                     db2logts - for tracking which table spaces have log records in which log files
                     db2lused - for updating object usage
                     db2pfchr - for buffer pool prefetchers
                     db2pclnr - for buffer pool page cleaners
                     db2redom - for the redo master. During recovery, it processes redo log records and assigns log records to redo workers for processing.
                     db2redow - for the redo workers. During recovery, it processes redo log records at the request of the redo master.
                     db2shred - for processing individual log records within log pages
                     db2stmm  - for the self-tuning memory management feature
                     db2taskd - for the distribution of background database tasks to db2taskp tasks
                     db2taskp - background database task
                     db2wlmd  - for automatic collection of workload management statistics
                     db2evmXYZ- event monitor tasks
                     db2bm.X.Y- backup and restore buffer manipulato
                     db2med.%X.%Y - backup and restore media controller
          Database Server Threads :
                     db2acd    - an autonomic computing daemon that hosts the health monitor, automatic maintenance utilities, 
                                 and the administrative task scheduler. This process was formerly known as db2hmon.
                     db2aiothr - manages asynchronous I/O requests for a database partition (UNIX only)
                     db2alarm  - notifies EDUs when their requested timer has expired (UNIX only)
                     db2cart   - for archiving log files (when the userexit database configuration parameter is enabled)
                     db2disp   - the client connection concentrator dispatcher
                     db2fcms   - the fast communications manager sender daemon
                     db2fcmr   - the fast communications manager receiver daemon
                     db2fmd    - the fault monitor daemon
                     db2fmtlg  - for formatting log files (when the logretain database configuration parameter is enabled 
                                 and the userexit database configuration parameter is disabled)
                     db2licc   - manages installed DB2 licenses
                     db2panic  - the panic agent, which handles urgent requests after agent limits have been reached
                     db2pdbc   - the parallel system controller, which handles parallel requests from remote database partitions
                     db2resync - the resync agent that scans the global resync list
                     db2sysc   - the main system controller EDU; it handles critical DB2 server events
                     db2thcln  - recycles resources when an EDU terminates (UNIX only)
                     db2wdog   - the watchdog on UNIX and Linux operating systems that handles abnormal terminations

        
\n" ;
}

$msg{'db2ipccm'} = 'db2ipccm - listener for IPC connect requests';
$msg{'db2tcpcm'} = 'db2tcpcm - listener for TCP connect requests';
$msg{'db2tcpdm'} = 'db2tcpdm - listener for TCP Discovery Tools connect requests';
$msg{'db2agent'} = 'db2agent - coordinating client. For partitioned tables and parallelism will coordinate other agents';
$msg{'db2agntp'} = 'db2agntp - partitioned call agent';
$msg{'db2agnts'} = 'db2agnts - intraquery parallelism';
$msg{'db2agnti'} = 'db2agnti - process to run event monitors';
$msg{'db2agnsc'} = 'db2agnsc - subcoordinator agent used to parallelize db restart';
$msg{'db2agent'} = 'db2agentg - gateway agent';
$msg{'db2agntg'} = 'db2agntgp - pooled gateway agent (pooled agent for a remote database)';
$msg{'db2agent'} = 'db2agentdp- pooled database agent (pooled agent for a local database)';
$msg{'db2fmp'} = 'db2fmp - fenced process running stored procedure or user defined function';
$msg{'db2vend'} = 'db2vend - vendor code runningon behalf of an EDU (perhaps log archiving)';
$msg{'db2dlock'} = 'db2dlock - for deadlock detection';
$msg{'db2glock'} = 'db2glock - for deadlock detection in a partitioned database environment';
$msg{'db2fw'} = 'db2fw? - an event monitor fast writer (used for event monitor) thread where \'X\' identifies the thread number';
$msg{'db2hadrp'} = 'db2hadrp - the high availability disaster recovery (HADR) primary server thread';
$msg{'db2hadrs'} = 'db2hadrs - the HADR standby server thread';
$msg{'db2lfr'} = 'db2lfr - for log file readers that process individual log files';
$msg{'db2loggr'} = 'db2loggr - for manipulating log files to handle transaction processing and recovery';
$msg{'db2loggw'} = 'db2loggw - for writing log records to the log files';
$msg{'db2logmg'} = 'db2logmgr - for the log manager. Manages log files for a recoverable database';
$msg{'db2logts'} = 'db2logts - for tracking which table spaces have log records in which log files';
$msg{'db2lused'} = 'db2lused - for updating object usage';
$msg{'db2pfchr'} = 'db2pfchr - for buffer pool prefetchers';
$msg{'db2pclnr'} = 'db2pclnr - for buffer pool page cleaners';
$msg{'db2redom'} = 'db2redom - for the redo master. During recovery, it processes redo log records and assigns log records to redo workers for processing.';
$msg{'db2redow'} = 'db2redow - for the redo workers. During recovery, it processes redo log records at the request of the redo master.';
$msg{'db2shred'} = 'db2shred - for processing individual log records within log pages';
$msg{'db2stmm'} = 'db2stmm - for the self-tuning memory management feature';
$msg{'db2taskd'} = 'db2taskd - for the distribution of background database tasks to db2taskp tasks';
$msg{'db2taskp'} = 'db2taskp - background database task';
$msg{'db2wlmd'} = 'db2wlmd - for automatic collection of workload management statistics';
$msg{'db2evm'} = 'db2evmXYZ - event monitor tasks';
$msg{'db2bm'} = 'db2bm.?.? - backup and restore buffer manipulator';
$msg{'db2med'} = 'db2med.?.?- backup and restore media controller';
$msg{'db2acd'} = 'db2acd - an autonomic computing daemon that hosts the health monitor, automatic maintenance utilities,';
$msg{'and the'} = 'and the administrative task scheduler. This process was formerly known as db2hmon.';
$msg{'db2aioth'} = 'db2aiothr - manages asynchronous I/O requests for a database partition (UNIX only)';
$msg{'db2alarm'} = 'db2alarm - notifies EDUs when their requested timer has expired (UNIX only)';
$msg{'db2cart'} = 'db2cart - for archiving log files (when the userexit database configuration parameter is enabled)';
$msg{'db2disp'} = 'db2disp - the client connection concentrator dispatcher';
$msg{'db2fcms'} = 'db2fcms - the fast communications manager sender daemon';
$msg{'db2fcmr'} = 'db2fcmr - the fast communications manager receiver daemon';
$msg{'db2fmd'} = 'db2fmd - the fault monitor daemon';
$msg{'db2fmtlg'} = 'db2fmtlg - for formatting log files (when the logretain database configuration parameter is enabled and the userexit database configuration parameter is disabled)';
$msg{'db2licc'} = 'db2licc - manages installed DB2 licenses';
$msg{'db2panic'} = 'db2panic - the panic agent, which handles urgent requests after agent limits have been reached';
$msg{'db2pdbc'} = 'db2pdbc - the parallel system controller, which handles parallel requests from remote database partitions';
$msg{'db2resyn'} = 'db2resync - the resync agent that scans the global resync list';
$msg{'db2sysc'} = 'db2sysc - the main system controller EDU; it handles critical DB2 server events';
$msg{'db2thcln'} = 'db2thcln - recycles resources when an EDU terminates (UNIX only)';
$msg{'db2wdog'} = 'db2wdog - the watchdog on UNIX and Linux operating systems that handles abnormal terminations';
$msg{'db2jcc_application'} = 'db2jcc_application - remote db2 java connection using JDBC type 4 driver';
$msg{'javaw.exe'} = 'javaw.exe - remote java connection';
$msg{'db2jcchttp-8080-Proc'} = 'db2jcchttp-8080-Proc - java web browser connection (modsql?)';

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
$debugLevel = 0;
$accumulate = "No";
$showUser = "Yes";
$showSystem = "No";
$showAll = "No";
$showZero = "Yes";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsvcCUSAd:z";

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
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "C"))  {
   if ( $silent ne "Yes") {
     print "Delta values have been zeroed\n";
   }
   if ( $OS eq "Windows" ) {
     $x = `remove lappSumm.hist`;
   }
   else {
     $x = `rm lappSumm.hist`;
   }
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( $silent ne "Yes") {
     print "Delta values will be an accumulation of deltas from the last -C\n";
   }
   $accumulate = "Yes";
 }
 elsif (($getOpt_optName eq "z"))  {
   if ( $silent ne "Yes") {
     print "Only processes that have changed will be displayed\n";
   }
   $showZero = "No";
 }
 elsif (($getOpt_optName eq "U"))  {
   if ( $silent ne "Yes") {
     print "User CPU will be displayed\n";
   }
   $showUser = "Yes";
   $showSystem = "No";
   $showAll = "No";
 }
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "System CPU will be displayed\n";
   }
   $showUser = "No";
   $showSystem = "Yes";
   $showAll = "No";
 }
 elsif (($getOpt_optName eq "A"))  {
   if ( $silent ne "Yes") {
     print "User and System CPU will be added and then displayed\n";
   }
   $showUser = "No";
   $showSystem = "No";
   $showAll = "Yes";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Applications on database $getOpt_optValue will be listed\n";
   }
   $database = uc($getOpt_optValue);
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
$CurrSection = "";

if (! open (LTSPIPE,"db2 get snapshot for all applications |"))  {
        die "Can't run get snapshot for all applications! $!\n";
    }

# Print Headings ....
print "Application Snapshot Summary ($Now) .... \n\n";
print "Loading old comparison values\n";

@oldSnap_values = (); # clear out array
if ( open(OLDSNAP,"<lappSumm.hist") ) { 
  while (<OLDSNAP>) {
    @oldSnap_values = split(/\|/,$_);
    if ( $oldSnap_values[0] eq "SnapTime" ) {
      print "Delta Values are obtained are from $oldSnap_values[1]\n";
    }
    else {
      if ($debugLevel > 0 ) { print "0=$oldSnap_values[0],1=$oldSnap_values[1],2=$oldSnap_values[2],3=$oldSnap_values[3]\n"; }
      $oldCPU{$oldSnap_values[0]}=$oldSnap_values[1];
      $oldCalls{$oldSnap_values[0]}=$oldSnap_values[2];
      $oldSystemCPU{$oldSnap_values[0]}=$oldSnap_values[3];
    }
  }
  close OLDSNAP;
}
else {
  print "No history values to display \n";
}

$disHead = "Yes";
$entriesNotShown = 0;

# Only write out new values if we aren't accumulating
if ( $accumulate eq "No" ) {
  if (! open (NEWSNAP,">lappSumm.hist"))  {
          print "Can't create the history file! $!\n";
  }
  else {
    print NEWSNAP "SnapTime|$Now|SnapTime\n";
  } 
}

while (<LTSPIPE>) {
    if ( $debugLevel > 0 ) {  print "$CurrSection   : $_\n"; }

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    $linein = $_;

    @appsnapinfo = split(/=/,$linein);
    $x = trim($appsnapinfo[0]);
    if ( $debugLevel > 1 ) {  print "$CurrSection   : $x = $appsnapinfo[1]\n"; }

    if ( trim($appsnapinfo[0]) eq "Application Snapshot") {
      $CurrSection = "AppSnap";
      $memHeadPrinted = "No";
    }
    if ( trim($appsnapinfo[0]) eq "Database Connection Information") {
      $CurrSection = "DBConnection";
    }
    if ( trim($appsnapinfo[0]) eq "Memory usage for agent:") {
      $CurrSection = "Memory";
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
    if ( trim($appsnapinfo[0]) eq "Process ID of client application") {
      $ProcessID = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Locks held by application") {
      $LocksHeld = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Blocking cursor") {
      $blocking = trim($appsnapinfo[1]);
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
      $CurrSection = "WorkspaceInformation";

      # Print out a summary line .....

      $TotCalls = $RowsDeleted + $RowsInserted + $RowsUpdated + $RowsSelected; 
      $cTime = substr($ConnStart,0,16);

      $valuesDifferent = "Yes";
      if ( defined( $oldCPU{$AppID} ) ) {
        if ( $showUser eq "Yes" ) {
          $CPUTime = $UserCPUTime;
          $oldCPUTime = $oldCPU{$AppID};
          $head="User CPU";
        }
        elsif ( $showSystem eq "Yes" ) {
          $CPUTime = $SystemCPUTime;
          $oldCPUTime = $oldSystemCPU{$AppID};
          $head="System CPU";
        }
        else {
          $CPUTime = $SystemCPUTime + $UserCPUTime;
          $oldCPUTime = $oldCPU{$AppID} + $oldSystemCPU{$AppID};
          $head="Total CPU";
        }

        $deltaCPU = $CPUTime - $oldCPUTime;

        $deltaCalls = $TotCalls - $oldCalls{$AppID};
        if ( ($deltaCalls == 0) && ( sprintf("%9.2f",$deltaCPU) == 0 ) ) { $valuesDifferent = "No"; }
        if ( $debugLevel > 0 ) { print "deltaCalls = $deltaCalls, deltaCPU = $deltaCPU, valuesDifferent = $valuesDifferent\n"; }

        if ( $debugLevel > 0 ) { 
          print "deltaCPU=$deltaCPU, CPUTime=$CPUTime, systemCPUTime=$SystemCPUTime, UserCPUTime=$UserCPUTime\n";
          print "oldCPUTime=$oldCPUTime, oldCPU=$oldCPU{$AppID}, oldSystemCPUTime=$oldSystemCPU{$AppID}\n";
        }
      }
      else { # AppID is new .....
        $deltaCPU = '';
        $deltaCalls = '-';
      }

      # Only gather new stats if we aren't accumulating .....
      if ( $accumulate eq "No" ) {
        print NEWSNAP "$AppID|$UserCPUTime|$TotCalls|$SystemCPUTime\n"; # save for next iteration
      }

      if ( $disHead eq "Yes" ) {
        if ( ($database eq $DBName ) || ( $database eq "") ) {
          if ( ( $showZero eq "Yes" ) || ( ( $showZero eq "No" ) && ( $valuesDifferent eq "Yes") ) ) {
            ## output the db details .....
            noteApp($AppName);
            printf "\n%-10s %-5s %-20s %-20s %-9s %10s %9s %-11s %-11s %-16s %-20s\n",
                   'Database','AppID','App Name','Status','ProcessID',$head,'Delta CPU','Total Calls','Delta Calls','Connection Time','Client IP';
            printf "%-10s %-5s %-20s %-20s %-9s %10.2f %9.2f %11s %11s %-16s %-20s\n",
                   $DBName, $AppID, $AppName, $AppStatus, $ProcessID, $CPUTime, $deltaCPU, $TotCalls, $deltaCalls, $cTime, $ClientIP;
            $disHead = "No";
          }
          else {
            $entriesNotShown++;
          }
        }
      }
      else {
        if ( ($database eq $DBName ) || ( $database eq "") ) {
          if ( ( $showZero eq "Yes" ) || ( ( $showZero eq "No" ) && ( $valuesDifferent eq "Yes") ) ) {
            ## output the details .....
            noteApp($AppName);
            printf "%-10s %-5s %-20s %-20s %-9s %10.2f %9.2f %11s %11s %-16s %-20s\n",
                   $DBName, $AppID, $AppName, $AppStatus, $ProcessID, $CPUTime, $deltaCPU, $TotCalls, $deltaCalls, $cTime, $ClientIP;
          }
          else {
            $entriesNotShown++;
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
    }
    if ( trim($appsnapinfo[0]) eq "Statement sorts") {
      $STNumSorts = trim($appsnapinfo[1]);
    }
    if ( trim($appsnapinfo[0]) eq "Total sort time") {
      $STSortTime = trim($appsnapinfo[1]);
    }
    if ($CurrSection eq "SQLStatement") {
      if ( trim($appsnapinfo[0]) eq "Agent process/thread ID" ) {
        $CurrSection = "";
      }
      else {
        $SQLStatement = "$SQLStatement $linein";
      }
    }
    if ( trim($appsnapinfo[0]) eq "Dynamic SQL statement text:") {
      $CurrSection = "SQLStatement";
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
    }
}

if ( $showZero eq "No" ) { print "\n\n$entriesNotShown zero change entries suppressed\n"; }

# Only close the file if we aren't accumulating .....
if ( $accumulate eq "No" ) {
  close NEWSNAP;
}

print "\nThe following application types were displayed:\n\n";
foreach $app (sort by_key keys %apps) {
  if ( defined($msg{$app}) ) { 
    print "$msg{$app}\n";
  }
  else {
    print "$app - No descriptive message text found\n";
  }
}


