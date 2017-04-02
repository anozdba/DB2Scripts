#!/usr/bin/perl
# --------------------------------------------------------------------
# lActiveLogs.pl
#
# $Id: lActiveLogs.pl,v 1.5 2017/03/30 22:58:43 db2admin Exp db2admin $
#
# Description:
# Script to List out Active Log usage
#
# Usage:
#   lActiveLogs.pl -d <database>
#
# $Name:  $
#
# ChangeLog:
# $Log: lActiveLogs.pl,v $
# Revision 1.5  2017/03/30 22:58:43  db2admin
# format the data from mon_get_transaction_log
#
# Revision 1.4  2017/03/30 06:02:04  db2admin
# correct log volume stats for pre version 10
#
# Revision 1.3  2017/03/30 03:13:36  db2admin
# add in some headings and sum log space used
#
# Revision 1.2  2017/03/30 02:56:15  db2admin
# correct which logs applications were being assigned to
#
# Revision 1.1  2017/03/29 04:56:03  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

use strict;

my $debugLevel = 0;
my %monthNumber;

my $ID = '$Id: lActiveLogs.pl,v 1.5 2017/03/30 22:58:43 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

my $machine;   # machine we are running on
my $OS;        # OS running on
my $scriptDir; # directory the script ois running out of
my $tmp ;
my $machine_info;
my @mach_info;
my $user = 'Unknown';
my $dirsep;
my $timeString;
my $exitCode = 0;
my %lastAlertTime = ();
my $lastAlertAlarmKey;
my %currentAlerts = ();
my $TS;
my $warn = 'CRITICAL ';
my $latency = '';
my $lastRun = '';
my @bit = ();
my %stateCount = ();

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scrxipts';
    $tmp = rindex($0,'\\');
    $user = $ENV{'USERNAME'};
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $dirsep = '\\';
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    $user = `id | cut -d '(' -f 2 | cut -d ')' -f 1`;
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $dirsep = '/';
  }
}

use lib "$scriptDir";

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $myDate_debugLevel timeDiff);

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs [-v[v]] [-d <database>] [-n <number>] [-w <number>] [-f <file>] [-9]

       Script to check  the active logs

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (no parameter information will be displayed)
       -d              : database to connect to 
       -n              : number of iterations (default 1)
       -f              : file to use for input
       -w              : wait between iterations (in seconds, default 60)S
       -a              : display all transactions (not just those with log data)
       -9              : use pre version 10 formatting
       -v              : debug level

       Basically just formats the output of:

       Select MEMBER, CUR_COMMIT_DISK_LOG_READS, CURRENT_ACTIVE_LOG, APPLID_HOLDING_OLDEST_XACT from table(mon_get_transaction_log(-1)) as t order by member asc (DB2 V10.1 and higher)

         and

       db2pd -db <database>  -logs -transactions

\n";

}

my $silent = "No";
my $database = '';
my $number = 1;
my $wait = 60;
my $waitMS = 60 * 1000;
my $inFile = '';    # input can be entered via file
my $delay = 240;
my $all = 0;
my $pre10 = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hasv9d:n:w:f:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be read\n";
   }
   $inFile = $getOpt_optValue;
 }
 elsif ($getOpt_optName eq "a")  {
   if ( $silent ne "Yes") {
     print "All transaction data will be displayed\n";
   }
   $all = 1;
 }
 elsif ($getOpt_optName eq "9")  {
   if ( $silent ne "Yes") {
     print "Pre version 10 formatting will be used\n";
   }
   $pre10 = 1;
 }
 elsif ($getOpt_optName eq "d")  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be used\n";
   }
   $database = $getOpt_optValue;
 }
 elsif ($getOpt_optName eq "w")  {
   $wait = "";
   ($wait) = ($getOpt_optValue =~ /(\d*)/);
   if ($wait eq "") {
      usage ("Value supplied for the wait parameter (-w) is not numeric");
      exit;
   }
   if ( $silent ne "Yes") {
     print "Monitor will wait $wait seconds before iteration\n";
   }
   $waitMS = $wait * 1000;
 }
 elsif ($getOpt_optName eq "n")  {
   $number = "";
   ($number) = ($getOpt_optValue =~ /(\d*)/);
   if ($number eq "") {
      usage ("Value supplied for number parameter (-n) is not numeric");
      exit;
   }
   if ( $silent ne "Yes") {
     print "Monitor will iterate $number times\n";
   }
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug Level set to $debugLevel\n";
   }
 }
 else { # handle other entered values ....
   usage ("Parameter $getOpt_optValue : This parameter is unknown");
   exit;
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $NowTS = "$year.$month.$day $hour:$minute:$second";
$user = getpwuid($<);

%monthNumber = ( 'Jan' =>  '01', 'Feb' =>  '02', 'Mar' =>  '03', 'Apr' =>  '04', 'May' =>  '05', 'Jun' =>  '06',
                    'Jul' =>  '07', 'Aug' =>  '08', 'Sep' =>  '09', 'Oct' =>  '10', 'Nov' =>  '11', 'Dec' =>  '12',
                    'January' =>  '01', 'February' =>  '02', 'March' =>  '03', 'April' =>  '04', 'May' =>  '05', 'June' =>  '06',
                    'July' =>  '07', 'August' =>  '08', 'September' =>  '09', 'October' =>  '10', 'November' =>  '11', 'December' =>  '12' );

# create the data to report on

my $SQLin = "$scriptDir/../sql/listActiveLogs.sql";

my $db2level = `db2level | grep Inform | cut -d" " -f5 | cut -d"." -f1,2 | cut -c2-`;

if ( $pre10 ) {
  $db2level = '9.7';
}

print "Current Log Activity Report\n\n";

if ( $db2level > 10.1 ) { # DB2 view is avavilable
  if ( $debugLevel > 0 ) { print "Executing: $scriptDir/runSQL.pl -sp \"%%DATABASE%%=$database\" \<$SQLin | db2 -t +wp -x\n";}

  my $ans = `$scriptDir/runSQL.pl -sp "%%DATABASE%%=$database" <$SQLin | db2 -t +wp -x | grep 'DataHere`;
  my ( $t, $MEMBER, $CUR_COMMIT_DISK_LOG_READS, $CURRENT_ACTIVE_LOG, $APPLID_HOLDING_OLDEST_XACT0 ) = split (" ",$ans);
  print "mon_get_transaction_log information:\n\n";
  print "  Member                        : $MEMBER\n";
  print "  Current Commit Log Reads      : $CUR_COMMIT_DISK_LOG_READS\n";
  print "  Current Active Log            : $CURRENT_ACTIVE_LOG\n";
  print "  APPLID holding the oldest Log : $APPLID_HOLDING_OLDEST_XACT0\n\n";
}

# input variables

my ($in_logName, $in_logStartLSN, $in_logStartLSO ) ;
my ($appID, $tranID, $locks, $state, $firstLSN, $firstLSO, $logSpace, $logon, $mach, $clientApp);

my $currentSection = '';
my $header = 1;

sub waitSeconds {

  # wait the specified number of seconds

  my $x;

  # wait a while
  if ( $number > 0 ) {
    if ( $OS eq "Windows" ) {
      $x = `PING 1.1.1.1 -n 1 -w $waitMS`;
    }
    else {
      $x = `/usr/sbin/ping 192.168.1.1 $wait`;
    }
  }

}

# loop as specified  .... $number times with a $wait seconds wait in between

while ( $number > 0 ) {

  $TS = getTimestamp();
  print "$TS - Iteration $number\n\n";

  processLogInfo();

  $number--; 
  if ( $number > 0 ) { waitSeconds(); }

}

sub processLogInfo {

  # create input stream to read

  if ( $inFile eq "" ) {              # no input file was specified ....
    if (! open (INPUT,"db2pd -db $database  -logs -transactions |") )  {       # Open the stream
      die "Can't run db2pd! \n$!\n";
    }
  }
  else { # just process the supplied file
    if ( ! open( INPUT, "<",$inFile ) ) {
      die "Can't open $inFile! \n$!\n";
    }
  }

  # process the data

  $currentSection = '';
  
  my ($LSO, $LSN, $CLog);
  my @logName = ();
  my @logStartLSN = ();
  my @logStartLSO = ();
  my @logTrans = ();
  my @logUsed = ();
  my $logNum = 0;
  my $displayCount = 0;

  while ( <INPUT> ) {

    chomp $_;
    if ( trim($_) eq '' ) { next; } # skip blank lines

    # figure out where you are ....

    if ( ($_ =~ /Logs:/) ) { $currentSection = 'logs'; next; }
    if ( ($_ =~ /Database Member/) ) { $currentSection = 'header'; next; }
    if ( ($_ =~ /Database Partition/) ) { $currentSection = 'header'; next; }

    if ( ($_ =~ /Transactions:/) ) { # print out the log details information
      $currentSection = 'transactions'; 

      print "Current Log: $CLog  LSN: $LSN  LSO: $LSO\n\n";
   
      if ( $debugLevel > 0 ) { 
        printf "%-12s %-16s %-13s\n", 'Log Name', 'Start LSN', 'Start LSO';
        for ( my $i = 0; $i <= $logNum-1; $i++ ) { # loop through the logs that were found
          printf "%12s %16s %13s\n", $logName[$i], $logStartLSN[$i], $logStartLSO[$i];
        }
      }

      print  "Transactions:\n-------------\n";
      printf "\n%12s %12s %12s %12s %-18s %-18s %14s %-12s %-16s %-40s\n", 'App ID', 'Tran ID', 'Locks', 'State', 'First LSN', 'First LSO', 'Log Space', 'Logon', 'Machine', 'Client App';

      next; 
    }

    if ( $debugLevel > 1 ) { print "INPUT ($currentSection) : $_\n"; }

    # process the logs header section

    if ( $currentSection eq 'logs' ) { # working through the log section
      @bit = split ;
      if ( $_ =~ /Current LSO/ ) { # save the LSO (Log Sequence Offset)
        $LSO = $bit[2];
      }
      elsif ( $_ =~ /Current LSN/ ) { # save the LSN (Log Sequence Number) 
        $LSN = $bit[2];
      }
      elsif ( $_ =~ /Current Log Number/ ) { # save the Current Log Number
        $CLog = $bit[3];
      }
      elsif ( $_ =~ /Address            StartLSN/ ) { # Change the section as now into log details
        $currentSection = 'logs-details';
        next; # skip to the next record
      }
    }

    # process the log detail section

    if ( $currentSection eq 'logs-details' ) { # working through the log details section
      @bit = split ;
      setVariablesBasedOnVersion_Logs();
      if ( defined($bit[0]) ) { # there is some data there ....
        $logName[$logNum] = $in_logName;
        $logStartLSN[$logNum] = $in_logStartLSN;
        $logStartLSO[$logNum] = $in_logStartLSO;
        $logTrans[$logNum] = '';
        $logNum++;
      }
    }

   # process the transaction section

    if ( $currentSection eq 'transactions' ) { # working through the log details section

      if ( $_ =~ /Total application/ ) { # end of the transaction list
        $currentSection = 'After Tran';
        next;
      }

      @bit = split ;
      setVariablesBasedOnVersion_Tran();
      if ( $_ =~ /Address            AppHandl/) { next ; } # skip the heading

      # count thge differing states

      if ( defined($stateCount{$state}) ) { $stateCount{$state}++; }
      else { $stateCount{$state} = 1; }

      if ( ($logSpace > 0 ) || ( $state ne 'READ') ){ # there is log volume for this tran
        $displayCount++;
        printf "%12s %12s %12s %12s %18s %18s %14s %-12s %-16s %-40s\n", $appID, $tranID, $locks, $state, $firstLSN, $firstLSO, $logSpace, $logon, $mach, $clientApp;

        # now add this applid to the list for the starting log

        my $tran_logValue;
        my $log_logValue;

        if ( $db2level >= 10 ) { $tran_logValue = $firstLSO; }
        else { $tran_logValue = hex($firstLSN); }
        # print "+++++ $tran_logValue, $firstLSN, $firstLSO\n";

        for ( my $i = 0; $i <= $logNum-1; $i++ ) { # loop through the logs that were found
          if ( $db2level >= 10 ) { $log_logValue = $logStartLSO[$i]; }
          else { $log_logValue = hex($logStartLSN[$i]); }
          # print ">>>>> $log_logValue, $logStartLSN[$i], $logStartLSO[$i]\n";

          if ( $tran_logValue < $log_logValue ) { # transaction LSO is less than the log start LSO (the log LSOs should be in ascending order)
                                             # so the first entry where the tran LSO is lower is one log past the log that the tran is using
            if ( $logTrans[$i-1] eq '' ) { # no trans yet
              $logTrans[$i-1]="$appID";
              $logUsed[$i-1]=$logSpace;
            }
            else {
              $logTrans[$i-1]="$logTrans[$i-1],$appID";
              $logUsed[$i-1]=$logUsed[$i-1]+$logSpace;
            }
            last ;
          } 
        }

      } 
      elsif ( $all ) { # print it anyway
        $displayCount++;
        printf "%12s %12s %12s %12s %18s %18s %14s %-12s %-16s %-40s\n", $appID, $tranID, $locks, $state, $firstLSN, $firstLSO, $logSpace, $logon, $mach, $clientApp;
      }
  
    }

  } # end of while REPIN

  close INPUT;

  if ( $displayCount == 0 ) {
    print "\nNo transactions displayed (-a option will display all transactions)\n";
  }

  print "\nState Counts:\n\n";
  foreach my $a ( keys %stateCount ) {
    printf "%-12s : %12s\n", $a, $stateCount{$a};
  }

  # process the collected data and produce the report

  print  "\nLogs:\n-----\n";


  printf "\n%-12s %-16s %-14s %14s %-60s\n", 'Log Name', 'Start LSN', 'Start LSO', 'Used Log Space', 'Application IDs';
  for ( my $i = 0; $i <= $logNum-1; $i++ ) { # loop through the logs that were found
    printf "%12s %-16s %14s %14s %-60s\n", $logName[$i], $logStartLSN[$i], $logStartLSO[$i], $logUsed[$i], $logTrans[$i];
  }

} # end of processQueueInfo

sub setVariablesBasedOnVersion_Logs {

  if ( $db2level >= 10 ) {
    if ( defined($bit[0]) ) { # there is some data there ....
      $in_logName = $bit[6];
      $in_logStartLSN = $bit[1];
      $in_logStartLSO = $bit[2];
    }
  }
  else { # must be 9.8 or lower
    if ( defined($bit[0]) ) { # there is some data there ....
      $in_logName = $bit[5];
      $in_logStartLSN = $bit[1];
      $in_logStartLSO = '';
    }
  }
}

sub setVariablesBasedOnVersion_Tran {

  if ( $db2level >= 10 ) {
    $appID = $bit[1];
    $tranID = $bit[3];
    $locks = $bit[4];
    $state = $bit[5];
    $firstLSN = $bit[8];
    $firstLSO = $bit[10];
    $logSpace = $bit[13];
    $logon = $bit[17];
    $mach = $bit[18]; 
    $clientApp = substr($_,301,30); 
  }
  else { # must be 9.8 or lower
    $appID = $bit[1];
    $tranID = $bit[3];
    $locks = $bit[4];
    $state = $bit[5];
    $firstLSN = $bit[8];
    $firstLSO = '';
    $logSpace = $bit[11];
    $logon = $bit[15];
    $mach = $bit[16]; 
    $clientApp = substr($_,259,30); 
  }
}

sub getTimestamp {

  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
  my $year = 1900 + $yearOffset;
  $month = $month + 1;
  $hour = substr("0" . $hour, length($hour)-1,2);
  $minute = substr("0" . $minute, length($minute)-1,2);
  $second = substr("0" . $second, length($second)-1,2);
  $month = substr("0" . $month, length($month)-1,2);
  my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
  my $NowTS = "$year.$month.$day $hour:$minute:$second";

  return $NowTS;

}

exit $exitCode;
