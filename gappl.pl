#!/usr/bin/perl
# --------------------------------------------------------------------
# gappl.pl
#
# $Id: gappl.pl,v 1.6 2019/05/13 02:09:37 db2admin Exp db2admin $
#
# Description:
# Script to show information from a 'get snapshot from application in <DB> command
#
# Usage:
#   gappl.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: gappl.pl,v $
# Revision 1.6  2019/05/13 02:09:37  db2admin
# add option to limit displayed applications to those holding locks
#
# Revision 1.5  2019/05/10 05:55:14  db2admin
# correct the usage description
#
# Revision 1.4  2019/04/16 21:17:24  db2admin
# reorder the ingestData parms
#
# Revision 1.3  2019/04/06 13:55:18  db2admin
# adjust the headers
#
# Revision 1.2  2019/03/11 22:04:23  db2admin
# set up the yuse of a default database name if found
# alter the way that the $silent variable is used
#
# Revision 1.1  2019/03/08 00:24:37  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------"

use strict; 

my $ID = '$Id: gappl.pl,v 1.6 2019/05/13 02:09:37 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

# Global Variables for standard routines

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

# included modules

use lib "$scriptDir";
use commonFunctions qw(displayDebug ingestData trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel  $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

# Global variables for this script

my $currentRoutine = 'main';
my $silent = 0;
my $debugLevel = 0;
my $printDetail = 1;
my $exclude = 0;
my $excludeSystem = 0;
my $includeActive = 0;
my $inFile = "";
my $DBName_Sel = '';
my $locksOnly = 0;

###############################################################################
# Subroutines and functions ......                                            #

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs [-f <filename>] [-d <Database>] [-l] [-v[v]] [-p] [-x] [-a]

       Script to reformat the output of a get snapshot command. 
       Different to a lappl.pl command in that this command requires an input database name

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -f              : file to read info from
       -s              : Silent mode (dont produce the report)
       -d              : database
       -p              : print detailed report
       -a              : only show active connections
       -l              : only display an entry if it holds some locks
       -x              : exclude system applications
       -v              : debug level

       Note: This script formats the output of a 'db2 get snapshot for applications on <database>' command
             It differs from the lappl.pl as it can only show the applications for a specified database.
       \n ";
} # end of usage

sub processParameters {

  # ----------------------------------------------------
  # -- Start of Parameter Section
  # ----------------------------------------------------

  while ( getOpt(":?haxslpf:d:v") ) {
    if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
      usage ("");
      exit;
    }
    elsif (($getOpt_optName eq "s"))  {
      $printDetail = 0;
      $silent = 1;
    }
    elsif (($getOpt_optName eq "f"))  {
      if ( ! $silent ) {
        print "Application data will be read from file $getOpt_optValue (File should have been generated using 'db2 get snapshot for applications on $DBName_Sel')\n";
      }
      $inFile = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "l"))  {
      if ( ! $silent ) {
        print "Only apps holding locks will be displayed\n";
      }
      $locksOnly = 1;
    }
    elsif (($getOpt_optName eq "d"))  {
      if ( ! $silent ) {
        print "Application data for connections to database $getOpt_optValue will be listed\n";
      }
      $DBName_Sel = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "p"))  {
      $printDetail = 1;
      if ( ! $silent ) {
        print "Detailed report will be printed\n";
      }
    }
    elsif (($getOpt_optName eq "a"))  {
      $includeActive = 1;
      if ( ! $silent ) {
        print "only active applications will be shown\n";
      }
    }
    elsif (($getOpt_optName eq "x"))  {
      $excludeSystem = 1;
      if ( ! $silent ) {
        print "system applications will be excluded\n";
      }
    }
    elsif (($getOpt_optName eq "v"))  {
      $debugLevel++;
      if ( ! $silent ) {
        print "debug level set to $debugLevel\n";
      }
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

# set debug level in commonFunctions module
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

# write out overall heading

print "\nListing of applications attached to $DBName_Sel at $NowTS\n\n";

# organise where the input is coming from
my $inputpipe;
if ( $inFile ne "" ) {
  displayDebug("Applixcation data report will be read from $inFile",1,$currentRoutine);
  if ( $inFile eq 'STDIN' ) {
    if (! open ($inputpipe,"-"))  { die "Can't open STDIN for input $!\n"; }
  }
  else {
    if (! open ($inputpipe,"<","$inFile"))  { die "Can't open $inFile for input$!\n"; }
  }
}
else {
  displayDebug("Issuing: db2 get snapshot for applications on $DBName_Sel",1,$currentRoutine);
  if (! open ($inputpipe,"db2 get snapshot for applications on $DBName_Sel |"))  { 
    die "Can't run du! $!\n";
  }
}

# entries to be gathered form the lock list

my %data = ();                 # structure to hold the returned data

my %valid_entries = (
  "Agents associated with the application"  => 1,
  "Application handle"                      => 1,
  "Application ID"                          => 1,
  "Application name"                        => 1,
  "Application status"                      => 1,
  "Configuration NNAME of client"           => 1,
  "CONNECT Authorization ID"                => 1,
  "Connection request start timestamp"      => 1,
  "Coordinator agent process or thread ID"  => 1,
  "Client login ID"                         => 1,
  "Database name"                           => 1,
  "Is this a System Application"            => 1,
  "Locks held by application"               => 1,
  "Process ID of client application"        => 1,
  "Snapshot timestamp"                      => 1,
  "TP Monitor client application name"      => 1,
  "UOW log space used (Bytes)"              => 1
);

# load the report data into an internal data structure
ingestData ($inputpipe, '=', \%valid_entries, \%data, '', 'Application handle','','Dummy','');

# close the input file

close $inputpipe;

# now process the loaded data

my $excludedSystem = 0;
my $nonActiveApps = 0;
my $totalApps = 0;
my %type = ();      # array to hold counts of the different statuses

if ( $printDetail ) { # print out the application detail
  printf "%-10s %-10s %-20s %-6s %-34s %-14s %6s %6s %-20s %-19s %5s %5s\n",
         '', '', '', 'App', '', '', 'Num of', 'Thread', '', '', 'Locks', 'Log';
  printf "%-10s %-10s %-20s %-6s %-34s %-14s %6s %-6s %-20s %-19s %5s %5s\n",
         'AuthID', 'Client ID', 'Application', 'Handle', 'Application ID', 'Server', 'Agents', ' ID', 'Status', 'Connection Time', 'Held', 'Used';
  printf "%-10s %-10s %-20s %-6s %-34s %-14s %6s %6s %-20s %-19s %5s %5s\n",
         '----------', '----------', '--------------------', '------', '----------------------------------', '--------------', '------', '------', '--------------------', '-------------------', '-----', '-----';

  foreach my $appl ( sort by_key keys %data) { # looping through each of the application records

    displayDebug("Application ID $appl being processed for Detail",1, $currentRoutine);

    if ( $appl eq 'root' ) { next; } # skip root entry

    # keep track of the types of statuses
    if ( ! defined($type{$data{$appl}{"Application status"}}) ) { # initialise the field
      $type{$data{$appl}{"Application status"}} = 1;
    }
    else {
      $type{$data{$appl}{"Application status"}}++;
    }

    if ( $locksOnly && ( $data{$appl}{"Locks held by application"} == 0 ) ) { next; } # skip records holding no locks 

    $totalApps++;
    $exclude = 0 ; 
    if ( $includeActive && ( ($data{$appl}{"Application status"} =~ "Waiting" ) || ($data{$appl}{"Application status"} =~ "Connect Completed" ) ) ) { 
      $nonActiveApps++;
      $exclude = 1 ; 
    }

    if ( $excludeSystem && ( $data{$appl}{"Is this a System Application"} eq "YES" ) ) { 
      $excludedSystem++;
      $exclude = 1 ; 
    }

    if ( $exclude ) { # when excluding just skip to next major key
      next;
    }

    # adjust values
    my $connTime = substr($data{$appl}{"Connection request start timestamp"},0,19);
    my $logUsed = int($data{$appl}{"UOW log space used (Bytes)"} /1024/1024);

    # print out the primary key information
    printf "%-10s %-10s %-20s %-6s %-34s %-14s %6s %6s %-20s %-19s %5s %5s\n", 
           $data{$appl}{"CONNECT Authorization ID"}, 
           $data{$appl}{"Client login ID"}, 
           $data{$appl}{"Application name"}, 
           $appl,
           $data{$appl}{"Application ID"}, 
           $data{$appl}{"Configuration NNAME of client"}, 
           $data{$appl}{"Agents associated with the application"}, 
           $data{$appl}{"Coordinator agent process or thread ID"}, 
           $data{$appl}{"Application status"}, 
           $connTime,
           $data{$appl}{"Locks held by application"},
           $logUsed;

  }

  print "\n\nTotal entries : $totalApps\n";
  print "Excluded entries : \n";
  print "        System Applications     : $excludedSystem\n";
  print "        non-Active Applications : $nonActiveApps\n";
  print "\nNote: log used is in Mb\n";
  print "\n";
}
else { # not printing the detail
  foreach my $appl ( sort by_key keys %data) { # looping through each of the application records

    displayDebug("Application ID $appl being processed for Summary",1, $currentRoutine);

    if ( $appl eq 'root' ) { next; } # skip root entry

    # keep track of the types of statuses
    if ( ! defined($type{$data{$appl}{"Application status"}}) ) { # initialise the field
      $type{$data{$appl}{"Application status"}} = 1;
    }
    else {
      $type{$data{$appl}{"Application status"}}++;
    }
  }
}

# Summarise the connections

print "Connection type Summary\n\n";
foreach my $appType ( sort keys %type ) {
  printf "    %-25s   : %5s\n",  $appType, $type{$appType};
}

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

