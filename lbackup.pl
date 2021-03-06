#!/usr/bin/perl
# --------------------------------------------------------------------
# lbackup.pl
#
# $Id: lbackup.pl,v 1.22 2019/06/25 05:48:14 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST BACKUP ALL FOR <db> command
#
# Usage:
#   lbackup.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lbackup.pl,v $
# Revision 1.22  2019/06/25 05:48:14  db2admin
# 1. implment use script
# 2. add in -f parameter to handle an input file of a report
#
# Revision 1.21  2019/05/07 04:04:03  db2admin
# add in use of DB2DBDFT as the default database
#
# Revision 1.20  2019/01/25 04:08:18  db2admin
# correct bug with previous change where replace done incorrectly
#
# Revision 1.19  2019/01/25 03:12:40  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.18  2018/03/14 02:37:19  db2admin
# add in error message for SQL2155W
#
# Revision 1.17  2018/02/12 20:49:16  db2admin
# added elapsed time to the report display
#
# Revision 1.16  2014/11/11 04:55:56  db2admin
# add in reference to ltrim
#
# Revision 1.15  2014/11/11 04:52:18  db2admin
# add in listing of databases when database left off of script
# modify to use commonFunctions.pm
#
# Revision 1.14  2014/05/25 22:25:42  db2admin
# correct the allocation of windows include directory
#
# Revision 1.13  2012/08/09 02:14:13  db2admin
# initialise sqlerrmsg
#
# Revision 1.12  2012/03/08 22:37:52  db2admin
# force correct case for instance, machine and database
#
# Revision 1.11  2010/03/22 02:13:05  db2admin
# Add in a couple of changes
# 1. Add in debug mode
# 2. Improve help comments
# 3> Add some commentary on what the backup modes are
#
# Revision 1.10  2010/01/19 00:49:49  db2admin
# Add in version infromation to the help information
#
# Revision 1.9  2009/07/21 06:19:00  db2admin
# change last backup to 'last successful backup'
#
# Revision 1.8  2009/02/23 00:26:54  db2admin
# Adjust location information for Windows servers
#
# Revision 1.7  2009/02/22 23:38:44  db2admin
# add in netbackup error message
#
# Revision 1.6  2009/02/22 23:03:12  db2admin
# Correct problem with comment output to flat file
#
# Revision 1.5  2009/02/22 22:13:21  db2admin
# Also check to see if the backup has any error info associated with it
#
# Revision 1.4  2009/01/04 22:14:54  db2admin
# Correct Timestamp field
#
# Revision 1.3  2008/12/29 04:31:44  db2admin
# Standardised the parameter processing
#
# Revision 1.2  2008/12/29 02:05:52  db2admin
# Dont output extra space at end of data line
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $currentRoutine = 'Main';
my $machine;   # machine we are running on 
my $OS;        # OS running on
my $scriptDir; # directory the script ois running out of
my $tmp ;
my @tmp ;
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
    $logDir = 'logs\\';
    $tmp = rindex($0,'\\');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $dirSep = '\\';
    $tempDir = 'c:\temp\\';
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    $tmp = rindex($0,'/');
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

use commonFunctions qw(getOpt ltrim myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $cF_debugLevel displayMinutes timeDiff);

my $ID = '$Id: lbackup.pl,v 1.22 2019/06/25 05:48:14 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsDOR [DATA | DATAONLY] -d <database> [-f <filename>] [-v[v]]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -o or -O        : Only print out the data - dont print out a report
       -f              : file name to read the output of a 'list backup all for <database>' command
       -d              : Database to be listed [defaults to DB2DBDFT variable]
       -D              : Generate the data in a comma delimited form for loading into a table
       -r or -R        : Generate the report
       -v              : set debug level

       This command reformats the output of a 'db2 list backup all for <database>' command
       and extracts some details from a 'db2 get db cfg for <database>' command
       \n ";
}

# Set default values for variables

my $silent = 0;
my $database = "";
my $genData = "";
my $printRep = "Yes";
my $debugLevel = 0;
my $inFile = '';
my $i;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsrRoODf:d:|^DATA|^DATAONLY") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = 1;
 }
 elsif ((uc($getOpt_optName) eq "O") || ($getOpt_optName eq "DATAONLY") )  {
   if ( ! $silent ) {
     print "Only the data will be output\n";
   }
   $genData = "Yes";
   $printRep = "No";
 }
 elsif (($getOpt_optName eq "D")  || ($getOpt_optName eq "DATA") )  {
   if ( ! $silent ) {
     print "Data will be generated in a comma delimited form\n";
   }
   $genData = "Yes";
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( ! $silent ) {
     print "debug level now set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( ! $silent ) {
     print "Database $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "f"))  {
   $inFile = $getOpt_optValue;
   if ( ! $silent ) {
     print "Backup data will be read in from $getOpt_optValue\n";
   }
 }
 elsif (uc($getOpt_optName) eq "R")  {
   if ( ! $silent ) {
     print "The report will be generated\n";
   }
   $printRep = "Yes";
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Database $getOpt_optValue will be listed\n";
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
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $nowTS = "$year.$month.$day $hour:$minute:$second";

my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
my $Now = "$year.$month.$day $hour:$minute:$second";
my $NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";

my $instance = $ENV{'DB2INSTANCE'};

if ( $database eq "") {
  my $tmpDB = $ENV{'DB2DBDFT'};
  if ( ! defined($tmpDB) ) {
    usage ("A database must be provided");
    my $a = `ldb.pl`;
    print STDERR "Databases available in this instance are:\n\n$a";
    $a = `db2list.pl -sX`;
    print STDERR "Databases available in other instances on this server are:\n\n$a";
    exit;
  }
  else {
    if ( ! $silent ) {
      print "Database defaulted to $tmpDB\n";
    }
    $database = $tmpDB;
  }
}

my $lastBackup = "Never";

if ( $debugLevel > 0) { print "Processing $instance - $database ...... \n"; }

if (! open (LBACKUPPIPE,"db2 list backup all for $database |"))  {
        die "Can't run du! $!\n";
    }

if ($printRep eq "Yes") {
  # Print Headings ....
  print "Backup listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($Now) .... \n\n";
  printf "%-4s %-4s %-20s %-5s %-3s %-12s %-12s %-14s %3s %-30s %-14s %-2s %-30s %-30s\n",
         'Op', 'Obj', 'Timestamp+Seq', 'Type', 'Dev', 'Earliest Log', 'Current Log', 'Backup ID', '#TS', 'Comment', 'Backup End', 'St', 'Location', 'Elapsed';
  printf "%-4s %-4s %-20s %-5s %-3s %-12s %-12s %-14s %3s %-30s %-14s %-2s %-30s %-30s\n",
         '----', '----', '--------------------', '-----', '---', '------------', '------------', '--------------', '---', '------------------------------', '--------------', '--', '------------------------------', '-----------------------------';
}

$machine = lc($machine);
$instance = lc($instance);
$database = uc($database);

my $currentState = "NotStarted";
my $linecnt = -1;
my @Data = ();
my $maxData = -1;
my $stuffToPrint = "No";
my $linein = '';

my $Start = '';
my $End = '';
my $Op = '';
my $Obj = '';
my $TS ='';
my $Type = '';
my $linein = '';
my $Dev = '';
my $ELog = '';
my $CLog = '';
my $BackupID = '';
my $currentState = '';

my $TS_fmt = '';
my $numberOfTablespaces = '';
my $Comment = '';
my $End_fmt = '';
my $Status = '';
my $Location = '';
my $TS_Seq = '';
my $sqlcode = '';
my $sqlerrmsg = '';

while (<LBACKUPPIPE>) {

    if ( $linecnt >= 0 ) {
      $linecnt = $linecnt - 1;
    }

    if ( $debugLevel > 0 ) { print "Processing $_"; }

    chomp $_ ;
    $linein = $_;

    if ( $_ =~ /SQL1024N/) {
      if ($printRep eq "Yes") {
        die "A database connection must be established before running this program\n";
      }
      else {
        exit;
      }
    }
    elsif ( $_ =~ /SQL2155W/) {
      print "\n* -----------------------------------------\n$_\nReport listing stopped prematurely\n* -----------------------------------------\n";
    }
    elsif ( $_ =~ /SQL1013N/) {
      if ($printRep eq "Yes") {
        die "The database alias was not found for $instance\/$database\n";
      }
      else {
        exit;
      }
    }
    elsif ( $_ =~ /DB21016E/) {
      if ($printRep eq "Yes") {
        die "A system error was found in the connection to $instance\/$database\n$_\n";
      }
      else {
        exit;
      }
    }

    $linein = ltrim($_);

    my @lbackupinfo = split(/ +/,$linein);

    if ( $linecnt == 0 ) {
      # we have stopped counting down now ....
      if ($currentState eq "InFirstPart" ) {
        #  Op Obj Timestamp+Sequence Type Dev Earliest Log Current Log  Backup ID
        # -- --- ------------------ ---- --- ------------ ------------ --------------
        #  R  D  20080423081150000   F       S0000001.LOG S0000001.LOG 20080423074739
        # 012345678901234567890123456789012345678901234567890123456789012345678901234567890
        #           1         2         3         4         5         6         7

        $Op = $lbackupinfo[0];
        $Obj = $lbackupinfo[1];
        $TS = $lbackupinfo[2];
        $Type = $lbackupinfo[3];
        $linein = "$linein                                                                                    ";
        $Dev = trim(substr($linein,31,3));
        $ELog = trim(substr($linein,34,12));
        $CLog = trim(substr($linein,47,12));
        $BackupID = trim(substr($linein,61,14));
        $currentState = "AfterFirstPart";
      }
    }

    if ( trim($lbackupinfo[0]) eq "Op") {
      if ( $stuffToPrint eq "Yes" ) {
        # and now the printout .....

        my $fmtStart = substr($TS,0,4) . '-' . substr($TS,4,2) . '-' . substr($TS,6,2) . ' ' . substr($TS,8,2) . '.' . substr($TS,10,2) . '.' . substr($TS,12,2);
        my $fmtEnd   = substr($End,0,4) . '-' . substr($End,4,2) . '-' . substr($End,6,2) . ' ' . substr($End,8,2) . '.' . substr($End,10,2) . '.' . substr($End,12,2);
        my $elapsed = displayMinutes(timeDiff($fmtStart, $fmtEnd));

        if ($printRep eq "Yes") {
          if ( $sqlcode eq "" ) {
            printf "%-4s %-4s %-20s %-5s %-3s %-12s %-12s %-14s %3s %-30s %-14s %-2s %-30s %-30s\n",
                   $Op, $Obj, $TS, $Type, $Dev, $ELog, $CLog, $BackupID, $numberOfTablespaces, $Comment, $End, $Status, $Location, $elapsed;
            $lastBackup = $Start;
          }
          else {
            printf "%-4s %-4s %-20s %-5s %-3s %-12s %-12s %-14s %3s %-30s %-14s %-2s %-30s %-30s\n",
                   $Op, $Obj, $TS, $Type, $Dev, $ELog, $CLog, $BackupID, $numberOfTablespaces, "SQLCode=$sqlcode NBErrCode=$sqlerrmsg", $End, $Status, $Location, $elapsed;
          }
        }

        if ($genData eq "Yes") {
          $maxData++;
          $TS_fmt = formatTS($TS);
          $End_fmt = formatTS($End);
          $TS_Seq = substr $TS, 14;
          $Data[$maxData] = "BACKUP,$Now,$machine,$instance,$database,$Op,$Obj,$TS_fmt,$Type,$Dev,$ELog,$CLog,$BackupID,$numberOfTablespaces,$Comment,$End_fmt,$Status,$Location,$TS_Seq,$TS,$sqlcode,$sqlerrmsg";
        }
      }
      $stuffToPrint = "No";
      $currentState = "InFirstPart";
      $linecnt = 2;
      $sqlcode = "";
      $sqlerrmsg = "";
      next;
    }

    if ( trim($lbackupinfo[0]) eq "Contains") {
      $numberOfTablespaces = $lbackupinfo[1];
    }

    if ( trim($lbackupinfo[0]) eq "Comment:") {
      $Comment = trim(substr($linein,9));
    }

    if ( trim($lbackupinfo[0]) eq "Start") {
      $Start = trim($lbackupinfo[2]);
    }

    if ( trim($lbackupinfo[0]) eq "End") {
      $End = trim($lbackupinfo[2]);
    }

    if ( trim($lbackupinfo[0]) eq "Status:") {
      $Status = trim($lbackupinfo[1]);
    }

#    if ( trim($lbackupinfo[0]) eq "EID:") {
    if ( $linein =~ /Location:/) {
      $Location = trim( $linein =~ /Location:(.*)$/);
      if ($Location eq "/usr/openv/netbackup/bin/nbdb2.so64" ) {
        $Location = "NetBackup";
      }
      if ($Location =~ /nbdb2.dll/ ) {
        $Location = "NetBackup";
      }
      $stuffToPrint = "Yes";
    }

    if ( $linein =~ /sqlcode:/) {
      if ( trim($lbackupinfo[5]) eq "sqlcode:") {
        $sqlcode = trim($lbackupinfo[6]);
      }
    }

    if ( $linein =~ /sqlerrmc:/) {
      if ( trim($lbackupinfo[0]) eq "sqlerrmc:") {
        @tmp = split(/\�/,trim($lbackupinfo[1]));
        $sqlerrmsg = $tmp[1];
      }
    }
}

if ( $stuffToPrint eq "Yes" ) {

  # and now the printout .....

  if ($printRep eq "Yes") {

    my $fmtStart = substr($TS,0,4) . '-' . substr($TS,4,2) . '-' . substr($TS,6,2) . ' ' . substr($TS,8,2) . '.' . substr($TS,10,2) . '.' . substr($TS,12,2);
    my $fmtEnd   = substr($End,0,4) . '-' . substr($End,4,2) . '-' . substr($End,6,2) . ' ' . substr($End,8,2) . '.' . substr($End,10,2) . '.' . substr($End,12,2);
    my $elapsed = displayMinutes(timeDiff($fmtStart, $fmtEnd));

    if ( $sqlcode eq "" ) {
      printf "%-4s %-4s %-20s %-5s %-3s %-12s %-12s %-14s %3s %-30s %-14s %-2s %-30s %-30s\n",
             $Op, $Obj, $TS, $Type, $Dev, $ELog, $CLog, $BackupID, $numberOfTablespaces, $Comment, $End, $Status, $Location, $elapsed;
      $lastBackup = $Start;
      print "\nBackup types: F - Offline N - Online I - Incremental offline O - Incremental online D - Delta offline E - Delta online R - Rebuild\n";
      print "Dev types: (Guess) <Blank> - Disk O - Other (Netbackup)\n\n";
    }
    else {
      printf "%-4s %-4s %-20s %-5s %-3s %-12s %-12s %-14s %3s %-30s %-14s %-2s %-30s %-30s %-30s\n",
             $Op, $Obj, $TS, $Type, $Dev, $ELog, $CLog, $BackupID, $numberOfTablespaces, "SQLCode=$sqlcode NBErrCode=$sqlerrmsg", $End, $Status, $Location, $elapsed;
      print "\nBackup types: F - Offline N - Online I - Incremental offline O - Incremental online D - Delta offline E - Delta online R - Rebuild\n";
      print "Dev types: (Guess) <Blank> - Disk O - Other (Netbackup)\n\n";
    }
  }

  if ($genData eq "Yes") {
    $maxData++;
    $TS_fmt = formatTS($TS);
    $End_fmt = formatTS($End);
    $TS_Seq = substr $TS, 14;
    $Data[$maxData] = "BACKUP,$Now,$machine,$instance,$database,$Op,$Obj,$TS_fmt,$Type,$Dev,$ELog,$CLog,$BackupID,$numberOfTablespaces,$Comment,$End_fmt,$Status,$Location,$TS_Seq,$TS,$sqlcode,$sqlerrmsg";
  }
}

# Gather configuration information about the backups .....

if (! open (CFGPIPE,"db2 get db cfg for $database |"))  {
        die "Can't run du! $!\n";
    }

# First log archive method                 (LOGARCHMETH1) = OFF
# Backup pending                                          = NO
# Number of database backups to retain   (NUM_DB_BACKUPS) = 12
#   Automatic database backup            (AUTO_DB_BACKUP) = OFF

my $logMethod1 = "";
my $logMethod2 = "";
my $numBackupsHeld = "";
my $AutoBackup = "";
my $logprimary = '';
my $logsecond = '';
my $logfilsize = '';

while (<CFGPIPE>) {
    my @cfginfo = split(/=/,$_);
    chomp $cfginfo[1];
    if ($cfginfo[0] =~ /First log archive method/) {
      $logMethod1 = trim($cfginfo[1]);  
    }
    elsif ($cfginfo[0] =~ /Second log archive method/) {
      $logMethod2 = trim($cfginfo[1]);  
    }
    elsif ($cfginfo[0] =~ /Number of primary log files/) {
      $logprimary = trim($cfginfo[1]);  
    }
    elsif ($cfginfo[0] =~ /Number of secondary log files/) {
      $logsecond = trim($cfginfo[1]);  
    }
    elsif ($cfginfo[0] =~ /Log file size/) {
      $logfilsize = trim($cfginfo[1]);  
    }
    elsif ($cfginfo[0] =~ /Number of database backups to retain/) {
      $numBackupsHeld = trim($cfginfo[1]);  
    }
    elsif ($cfginfo[0] =~ /Automatic database backup/) {
      $AutoBackup = trim($cfginfo[1]);  
    }
}

if ($printRep eq "Yes") {
  print "Database $database configuration:\n\n";
  print "  First log archive method             : $logMethod1\n";
  print "  Second log archive method            : $logMethod2\n";
  print "  Number of database backups to retain : $numBackupsHeld\n";
  print "  Automatic database backup            : $AutoBackup\n\n";
  print "  Last Successful Backup Taken         : $lastBackup\n\n";
}

# print out the data if required
my $lb_fmt = '';
if ($genData eq "Yes") {
  for ( $i = 0; $i <= $maxData; $i++) {
    print "$Data[$i]\n";
  }
  if ($lastBackup eq "Never") {
    $lb_fmt = "";
  }
  else {
    $lb_fmt = formatTS($lastBackup);
  }
  print "BACKUPCONFIG,$Now,$machine,$instance,$database,$logMethod1,$logMethod2,$numBackupsHeld,$AutoBackup,$lb_fmt,$logprimary,$logsecond,$logfilsize\n";
}

sub formatTS() {
  my $S = shift;
  my $formattedString = substr($S,0,4) . "." . substr($S,4,2) . "." . substr($S,6,2) . " " . substr($S,8,2) . ":" . substr($S,10,2) . ":" . substr($S,12,2);
  return $formattedString;
}

