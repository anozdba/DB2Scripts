#!/usr/bin/perl
# --------------------------------------------------------------------
# llogs.pl
#
# $Id: llogs.pl,v 1.17 2019/06/24 05:30:56 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST HISTORY ARCHIVE LOG ALL FOR <db>
#
# Usage:
#   llogs.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: llogs.pl,v $
# Revision 1.17  2019/06/24 05:30:56  db2admin
# alter the way the silent parameter is processed
# add in default database processing
#
# Revision 1.16  2019/02/07 04:18:55  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.15  2019/01/25 03:12:41  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.14  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.13  2018/10/18 22:58:52  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.12  2018/10/18 20:37:16  db2admin
# convert date() calls to myDate()
#
# Revision 1.11  2018/10/17 01:15:36  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.10  2014/05/25 22:27:26  db2admin
# correct the allocation of windows include directory
#
# Revision 1.9  2012/04/17 01:10:34  db2admin
# Enforce upper case for database and lower case for machine and instance in output file
#
# Revision 1.8  2011/11/14 05:18:55  db2admin
# Add in code to print out a log summary line for loading into a table
#
# Revision 1.7  2011/06/16 23:35:06  db2admin
# Alter the log count retrieval so that it works in windows too
#
# Revision 1.6  2011/06/16 23:18:11  db2admin
# Improve checking, add in minimum month day
#
# Revision 1.5  2011/06/14 01:35:11  db2admin
# Add in logs per day calculations
#
# Revision 1.4  2011/01/04 01:39:20  db2admin
# various changes :
#   use new returns from date routine
#   improve debug prints
#   add headings to summary
#
# Revision 1.3  2009/04/26 23:23:03  db2admin
# Remove the internal date() function and use the one in commonFunctions.pl
#
# Revision 1.2  2008/12/31 00:58:51  db2admin
# Standardise parameters and improve help
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

my $ID = '$Id: llogs.pl,v 1.17 2019/06/24 05:30:56 db2admin Exp db2admin $';
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
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel  $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs -d <database> -f <Log List file> -c <check from time> [-v[v]]

       Script to format the output of a LIST HISTORY ARCHIVE LOG ALL FOR <db>

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode 
       -d              : Database to insert the statements in to
       -f              : File containing the output from a LIST LOGS command (if present this will take precedence over the -d parm)
       -x              : Dont produce the report
       -c              : If specified only records with keys greater than the supplied value will be displayed
       -v              : set debug level 

       This command provides a formatted listing of the 'db2 list history archive log all for <database>' command

       At the end it provides a summary of log archiving times.

     \n";
}

# Set default values for variables

$silent = 0;
$database = "";
$fileLogs = "";
$compare = "";
$debugLevel = 0;
$doReport = "Yes";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hvsxd:f:c:";

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt($getOpt_opt) ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = 1;
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( ! $silent ) {
     print STDERR "debug level has now been set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( ! $silent ) {
     print STDERR "Only records greater than $getOpt_optValue will be listed\n";
   }
   $compare = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "x"))  {
   if ( ! $silent ) {
     print STDERR "Report will not be produced\n";
   }
   $doReport = "No";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( ! $silent ) {
     print STDERR "File to be processed is $getOpt_optValue\n";
   }
   $fileLogs = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( ! $silent ) {
     print STDERR "Logs for database $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( ! $silent ) {
       print STDERR "Logs for database $getOpt_optValue will be listed\n";
     }
   }
   elsif ( $fileLogs eq "" ) {
     $fileLogs = $getOpt_optValue;
     if ( ! $silent ) {
       print STDERR "File to be read is $getOpt_optValue\n";
     }
   }
   else {
     usage ("Parameter $getOpt_optValue is invalid");
     exit;
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
@ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
$day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
$Now = "$year.$month.$day $hour:$minute:$second";
$NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
$NowTS = "$year-$month-$day-$hour.$minute.$second";

if ( ($database eq "") && ($fileLogs eq "") ) {
  if ( $database eq "") {
    my $tmpDB = $ENV{'DB2DBDFT'};
    if ( ! defined($tmpDB) ) {
      usage ("Database name MUST be supplied");
      exit;
    }
    else {
      if ( ! $silent ) {
        print "Database defaulted to $tmpDB\n";
      }
      $database = $tmpDB;
    }
  }
  else {
    usage ("Database name MUST be supplied");
    exit;
  }
}

@period = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23);
for ($i=0; $i <= $#period; $i++ ) {
  if ( $i > 0 ) {           
    if ( $period[$i] <= $period[$i-1]) {
      die "Defined periods must be in ascending order\n";
    }
  }
  $logElapsed[$i] = 0;
  $logElapsedCount[$i] = 0;
}

$instance = $ENV{'DB2INSTANCE'};

$lastTimestamp = "FIRST";

if ( $fileLogs eq "" ) {
  if (! open (LHALPIPE,"db2 list history archive log all for $database | "))  { die "Can't run du! $!\n"; }
}
else {
  open (LHALPIPE,$fileLogs) || die "Unable to open $fileLogs\n"; 
  print "Input will be read from $fileLogs\n";
}

if ( $doReport eq "Yes" ) {
  # Print Headings ....
  print "Archive Log listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $ARGV[0] ($Now) .... \n\n";
  printf "%-1s %-1s %-14s %-4s %-1s %13s %9s %5s %14s %14s %-1s %5s %-40s\n",
         '','O','','','D','','','','','','S','','';
  printf "%-1s %-1s %-14s %-4s %-1s %13s %9s %5s %14s %14s %-1s %5s %-40s\n",
         'O','b','','','e','','','','','','t','','';
  printf "%-1s %-1s %-14s %-4s %-1s %13s %9s %5s %14s %14s %-1s %5s %-40s\n",
         'p','j','Timestamp','Type','v','Earliest Log','Backup ID','EID','Start Time','End Time','s','Mins','Location';
  printf "%-1s %-1s %-14s %-4s %-1s %13s %9s %5s %14s %14s %-1s %5s %40s\n",
         '-','-','--------------','----','-','-------------','---------','-----','--------------','--------------','-','-----','----------------------------------------';
}

$verifyLogCount = 0;

while (<LHALPIPE>) {
    chomp $_;
    # print "Processing>> $_\n";
    # parse the db2 list tablespaces show detail
    # Op Obj Timestamp+Sequence Type Dev Earliest Log Current Log  Backup ID
    #  -- --- ------------------ ---- --- ------------ ------------ --------------
    #   X  D  20080305052538      P    D  S0001455.LOG C0000000
    #  ----------------------------------------------------------------------------
    # 
    #  ----------------------------------------------------------------------------
    #     Comment:
    #  Start Time: 20080305052538
    #    End Time:
    #      Status: A
    #  ----------------------------------------------------------------------------
    #   EID: 1582 Location: /prj/eaihubb01.dblog0/eaitrkdb/NODE0000/S0001455.LOG

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program                                                                \n";
    }

    if ( $_ =~ /Number of matching file entries = / ) {
      ($checkCount) = ($_ =~ /Number of matching file entries = (\d*)/);
      print "Check count is $checkCount\n";
    }

    $input = $_;
    @lhalinfo = split(/:/) ;
    @lhalinfo_space = split(/\s+/,trim($_)) ;
 
    if ($debugLevel > 1) {
      $tli0 = trim($lhalinfo[0]);
      $tli0_space = trim($lhalinfo_space[0]);
      $tli1 = trim($lhalinfo[1]);
      $tli1_space = trim($lhalinfo_space[1]);
      print "lhalinfo_space>>$lhalinfo_space[0] : $lhalinfo_space[1]\n";
      print "lhalinfo_space>>$tli0_space<<>>$tli1_space<<\n";
      print "lhalinfo>>$lhalinfo[0] : $lhalinfo[1]\n";
      print "lhalinfo>>$tli0<<>>$tli1<<\n";
    }

    if ( trim($lhalinfo_space[0]) eq "Op") {
      # skip headings 
      next;
    }

    if ( trim($input) eq "") {
      # skip blank lines 
      next;
    }

    if ( trim(substr($lhalinfo_space[0],0,1)) eq "-") {
      # skip headings 
      next;
    }

    if ( trim($lhalinfo_space[0]) eq "X") {
      # Process main data line ....
      $Op = $lhalinfo_space[0];
      $Obj = $lhalinfo_space[1];
      $Timestamp = $lhalinfo_space[2];
      $Type = $lhalinfo_space[3];
      $Dev = substr($input,33,1);
      $EarliestLog = substr($input,36,12);
      $BackupID = substr($input . "                       ",62,9);
      next;
    }

    if ( trim($lhalinfo[0]) eq "Start Time") {
      $STime = trim($lhalinfo[1]);
    }

    if ( trim($lhalinfo[0]) eq "End Time") {
      $ETime = trim($lhalinfo[1]);
      # Keep a count of logs per month (increase the 0,6 to 0,8 to get it by day
      if ( defined($logCount{substr($ETime,0,6)}) ) {
        $logCount{substr($ETime,0,6)}++;
        # keep track of the maximum day number per month (saves worrying about calendars and leap years)
        if ( substr($ETime,6,2) > $dayMax{substr($ETime,0,6)} ) {
          $dayMax{substr($ETime,0,6)} = substr($ETime,6,2);
        }
        # and the minimum
        if ( substr($ETime,6,2) < $dayMin{substr($ETime,0,6)} ) {
          $dayMin{substr($ETime,0,6)} = substr($ETime,6,2);
        }
      }
      else {
        $logCount{substr($ETime,0,6)} = 1;
        $dayMax{substr($ETime,0,6)} = substr($ETime,6,2);
        $dayMin{substr($ETime,0,6)} = substr($ETime,6,2);
      }
    }

    if ( trim($lhalinfo[0]) eq "Status") {
      $Status = trim($lhalinfo[1]);
    }

    if ( trim($lhalinfo[0]) eq "EID") {
      $EID = trim($lhalinfo_space[1]);
      $Location = trim($lhalinfo_space[3]);
      chomp $Location;

      if ($lastTimestamp eq "FIRST")  { # Do nothing
        $minDiff = "";
      }
      else {
        $X = substr($Timestamp,0,8);
        @T = myDate("DATE\:$X");
        if ( $T[12] ne '' ) { # date was invalid
          print $T[12];
        }
        if ( $debugLevel > 0 ) { print " ...... $lastT[5]\n"; }
        $X = substr($lastTimestamp,0,8);

        @lastT = myDate("DATE\:$X");
        if ( $lastT[12] ne '' ) { # date was invalid
          print $lastT[12];
        }
        if ( $debugLevel > 0 ) { print " ...... $lastT[5]\n"; }
        $dayDiff = $T[5] - $lastT[5];
        if ( $debugLevel > 0 ) { print "dayDiff = $dayDiff\n"; }
        $minDiff = $dayDiff * 1440;
        if ( $debugLevel > 0 ) { print "minDiff = $minDiff\n"; }
        $dayMin = (substr($Timestamp,8,2) * 60) + substr($Timestamp,10,2);
        if ( $debugLevel > 0 ) { print "dayMin = $dayMin\n"; }
        $lastDayMin = (substr($lastTimestamp,8,2) * 60) + substr($lastTimestamp,10,2);
        if ( $debugLevel > 0 ) { print "lastDayMin = $lastDayMin\n"; }
        $minDiff = $minDiff + $dayMin - $lastDayMin;
      }

      # check the times

      if ( $compare ne "") {
        $compFULL = substr($compare . "00000000000000000000",0,length($Timestamp));
        if ( $compFULL gt $Timestamp ) {
          next;
        }
      }

      # print out the information

      $verifyLogCount++;
      if ( $doReport eq "Yes" ) {
        printf "%-1s %-1s %-14s %-4s %-1s %13s %9s %5s %14s %14s %-1s %5s %40s\n",
               $Op,$Obj,$Timestamp,$Type,$Dev,$EarliestLog,$BackupID,$EID,$STime,$ETime,$Status,$minDiff,$Location;
      }
      
      $index = $#period;
      for ($i=0; $i <= $#period; $i++ ) {
        $Hr =  substr($Timestamp,8,2);
        if ( $i == 0 ) {           
          if ( $Hr < $period[$i] ) {
            $index = $#period; 
            last;
          }
        }
        elsif ( $i == $#period ) {
          if ( $Hr > $period[$i] ) {
            $index = $#period; 
            last;
          }
        }
        else {
          if ( $Hr < $period[$i] ) {
            $index = $i  - 1; 
            last;
          }
        }
      }
      $logElapsed[$index] = $minDiff + $logElapsed[$index];
      $logElapsedCount[$index]++;

      $lastTimestamp = $Timestamp;
 
    }
}

if ( $verifyLogCount != $checkCount ) {
  print "############################################################\n";
  print "# Verify count of $verifyLogCount does not match the check count\n";
  print "# Values in this report are likely to be wrong\n";
  print "############################################################\n";
}
else {
  print "Number of logs found in the report matches the check count of $checkCount\n";
}

$verifyLogCount = 0;

print "\n";
printf "%-7s %-8s   %-10s   %-12s  \n", '', 'Average', 'Total', 'Total Number';
printf "%-7s %-8s   %-10s   %-12s  \n", 'Period', 'Log Time', 'Log Time', 'of Logs';
for ($i=0; $i <= $#period; $i++ ) {
  $verifyLogCount += $logElapsedCount[$i];
  if ( $i == 0 ) { # FIRST Period           
    # dont do anything with the first element except remember it
    $first_period = substr("00" . $period[0], length($period[0]),2);
    $period_start = substr("00" . $period[0], length($period[0]),2);
  }
  elsif ( $i == $#period ) { # LAST Period
    $period_stop = substr("00" . $period[$i], length($period[$i]),2);
    if ( $logElapsedCount[$i-1] != 0 ) {
      $ave_logtime = ($logElapsed[$i-1] * 1.0) / $logElapsedCount[$i-1];
    }
    else {
      $ave_logtime = 0;
    }
    printf "%7s %5.2d   %10s   %12s  \n", $period_start . "-" . $period_stop, $ave_logtime, $logElapsed[$i-1], $logElapsedCount[$i-1];
    $period_start = substr("00" . $period[$i], length($period[$i]),2);
    if ( $logElapsedCount[$i] != 0 ) {
      $ave_logtime = ($logElapsed[$i] * 1.0) / $logElapsedCount[$i];
    }
    else {
      $ave_logtime = 0;
    }
    printf "%7s %5.2d   %10s   %12s  \n", $period_start . "-" . $first_period, $ave_logtime, $logElapsed[$i], $logElapsedCount[$i];
    $period_start = substr("00" . $period[$i], length($period[$i]),2);
  }
  else { # All of the ones in between
    $period_stop = substr("00" . $period[$i], length($period[$i]),2);
    if ( $logElapsedCount[$i-1] != 0 ) {
      $ave_logtime = ($logElapsed[$i-1] * 1.0) / $logElapsedCount[$i-1];
    }
    else {
      $ave_logtime = 0;
    }
    printf "%7s %5.2d   %10s   %12s  \n", $period_start . "-" . $period_stop, $ave_logtime, $logElapsed[$i-1], $logElapsedCount[$i-1];
  }
  $period_start = substr("00" . $period[$i], length($period[$i]),2);
}
$logElapsed[$index] = $minDiff + $logElapsed[$index];
$logElapsedCount[$index]++;

if ( $verifyLogCount != $checkCount ) {
  print "############################################################\n";
  print "# Verify count of $verifyLogCount does not match the check count\n";
  print "# Values in this report are likely to be wrong\n";
  print "############################################################\n";
}
else {
  print "\nReport Log count is correct\n";
}

print "\n";
printf "%-10s : %-8s %-16s %-16s %-11s\n", 'Date', 'Count','Max Day in Month', 'Min Day in Month', 'Ave Per day';

$verifyLogCount = 0;

$lastMonth = 0;
foreach $key (sort by_key keys %logCount ) {
  $verifyLogCount += $logCount{$key};
  $lastMonth = $currHold;
  $aveLogs = 0;
  if ( defined($dayMax{$key}) ) {
    $aveLogs = int($logCount{$key} / ($dayMax{$key} - $dayMin{$key} + 1));
    $holdMonthDaysSoFar = $dayMax{$key} - $dayMin{$key} + 1;
  }
  printf "%-10s : %-8s %-16s %-16s %-11s\n", $key, $logCount{$key}, $dayMax{$key}, $dayMin{$key}, $aveLogs;
  $currHold = $logCount{$key};
  $lastKey = $key;
}


print "\nAverage logs per day in the current month for $database=$aveLogs\n";

$prtDB = uc($database);
$prtInstance = lc($instance);
$prtMachine = lc($machine);

print "LOGSUMM,$Now,$prtMachine,$prtInstance,$prtDB,$aveLogs,$lastKey,$currHold,$holdMonthDaysSoFar\n";

if ( $verifyLogCount != $checkCount ) {
  print "############################################################\n";
  print "# Verify count of $verifyLogCount does not match the check count\n";
  print "# Values in this report are likely to be wrong\n";
  print "############################################################\n";
}
else {
  print "Report Log count is correct\n";
}

sub by_key {
  $a cmp $b ;
}

sub by_value {
  $logCount{$b} <=> $logCount{$a} ;
}


