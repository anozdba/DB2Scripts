#!/usr/bin/perl
# --------------------------------------------------------------------
# lutil.pl
#
# $Id: lutil.pl,v 1.50 2019/06/25 04:48:19 db2admin Exp db2admin $
#
# Description:
# Script to reformat the output of the following commands:
#
#     1. list utilities show detail
#     2. db2pd -db <database. -reorg
#
# Usage:
#   lutil.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lutil.pl,v $
# Revision 1.50  2019/06/25 04:48:19  db2admin
# implement the -i option to only print a single utility ID
#
# Revision 1.49  2019/05/07 05:52:10  db2admin
# use DB2DBDFT to provide default database
#
# Revision 1.48  2019/04/12 01:27:07  db2admin
# add in a -T option to provide a forced total work figure
#
# Revision 1.47  2019/02/07 04:18:56  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.46  2019/02/07 03:26:11  db2admin
# *** empty log message ***
#
# Revision 1.45  2019/01/30 04:05:06  db2admin
# correct error where variable name incorrectly removed
#
# Revision 1.44  2019/01/25 04:08:18  db2admin
# correct bug with previous change where replace done incorrectly
#
# Revision 1.43  2019/01/25 03:12:40  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.42  2018/12/14 23:44:46  db2admin
# 1. correct the calculation of time to go in a reorg phase
# 2. add in total utility run time
#
# Revision 1.41  2018/11/02 04:53:52  db2admin
# use the database in the returned output where possible
# correct the allocation of the use scripts directory
#
# Revision 1.40  2018/09/26 05:09:26  db2admin
# add in parameter -x to allow a portion of the elapsed time to be excluded when calulating estimates
#
# Revision 1.39  2018/09/19 22:03:55  db2admin
# correct bug in the processing of utility type
#
# Revision 1.38  2018/09/17 05:44:24  db2admin
# dont leave space in the type column for loads
#
# Revision 1.37  2018/01/16 20:35:55  db2admin
# adjust some of the reorg messages
#
# Revision 1.36  2018/01/15 22:35:05  db2admin
# Minor alterations:
# 1. Output data on reorgs
# 2. display paused reorgs
#
# Revision 1.35  2017/12/27 22:03:59  db2admin
# correct calculation of estimated time for phases
#
# Revision 1.34  2017/10/27 04:10:00  db2admin
# correct div by zero error
#
# Revision 1.33  2017/07/03 04:47:17  db2admin
# added in %complete calcualtion to output where applicable
#
# Revision 1.32  2017/07/03 00:50:24  db2admin
# Corrected some processing of US dates
# Corrected display of parameter -U
# Ensured only deals in whole minutes
#
# Revision 1.31  2017/05/27 00:54:22  db2admin
# allow a total work figure to be specified (useful for restores)
#
# Revision 1.30  2017/05/24 23:40:48  db2admin
# show completed work even if total work isn't available
#
# Revision 1.29  2017/04/23 12:13:11  db2admin
# make sure database name is in upper case
#
# Revision 1.28  2017/04/22 23:25:36  db2admin
# add in option to output the utility ID information in a load format
#
# Revision 1.27  2017/04/10 03:02:40  db2admin
# correct time difference and estimates
#
# Revision 1.26  2016/11/03 00:14:30  db2admin
# 1. Add option to allow utility (non reorg) dates to have either US (mm/dd/yyyy) or EUR (dd/mm/yyyy) date formats
# 2. Allow the use of environment variables to set the default date format for a server
# 3. try and identify when the wrong date format has been selected and provide information on how to modify the format
#
# Revision 1.25  2016/10/19 21:24:40  db2admin
# correct minor bug with end dates for completed reorgs not applying us date format if specified
#
# Revision 1.24  2016/09/26 05:30:23  db2admin
# add in option to use american dates for db2pd
#
# Revision 1.23  2016/09/19 05:26:38  db2admin
# convert routine to use routines in commonFunctions.pm module
#
# Revision 1.22  2016/09/19 03:45:34  db2admin
# one more grammar issue
#
# Revision 1.21  2016/09/19 01:18:50  db2admin
# correct grammar in messages
#
# Revision 1.20  2016/08/26 06:33:41  db2admin
# corerct spelling mistake in help screen
#
# Revision 1.19  2016/08/26 06:30:51  db2admin
# change the spot where reorg counting is done
#
#
# --------------------------------------------------------------------

use strict;

my $currentRoutine = 'Main';
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
    $scriptDir = 'c:\udbdba\scrxipts';
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

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $cF_debugLevel  timeDiff displayMinutes performTimestampAddition processDuration);

# Global Variables

my $currentSection = 'ID';
my $inFile = '';
my $inReorg = '';
my $debugLevel = 0;
$cF_debugLevel = 0;
my %utlValues_ID = ();
my %utlValues_Phase = ();
my $nowTS;
my $database = '';
my $utilityID = 'All';
my $allUtilities = 0;
my $printedUtilities = 0;
my $allReorgs = 0;
my $printedReorgs = 0;
# note that US format is defined as mm/dd/yyy
my $utilDate_USFormat = 0;   # default format is EUR (dd/mm/yyyy)
my $reorgDate_USFormat = 0;  # default format is EUR (dd/mm/yyyy)
my $percent_completed;
my $percentLit;
my $maxCount;
my $reorgTable;
my $excludeMinutes = 0;

my $reorgDate_warning = 0;
my $utilDate_warning = 0;
my $loadable = 0;
my $total = 0;
my $instance = $ENV{'DB2INSTANCE'};
my $completed = 0;
my $loadStartTime;
my $reorgStartTime;
my $totalWork = '';
my $forceWork = 0;

# -------------------------------------------------------------------

my $ID = '$Id: lutil.pl,v 1.50 2019/06/25 04:48:19 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

# Subroutines and functions ......

sub printDebug {
  
  my $test = shift;
  my $routine = shift;
  $routine = substr("$routine                    ",0,20);

  print "$routine - $test\n";
}

sub outputReorgLoadValues {

# ------------------------------------------------------------------------------
# Routine to print out the utility information in load format
# ------------------------------------------------------------------------------

  my $utilID = trim($utlValues_ID{'ID'});
  my $uc_database = uc($database);

  print "LOAD,$nowTS,$machine,$instance,$uc_database,1,$reorgStartTime,\"$reorgTable\",\"Reorg\",$maxCount,$completed\n";

} # end of outputReorgLoadValues

sub outputLoadValues {

# ------------------------------------------------------------------------------
# Routine to print out the utility information in load format
# ------------------------------------------------------------------------------

  my $utilID = trim($utlValues_ID{'ID'});
  my $uc_database = uc($database);

  if (defined($utlValues_ID{'Database Name'}) ) {
    $uc_database = uc($utlValues_ID{'Database Name'});
  }

  my $converted_type = $utlValues_ID{'Type'};
  $converted_type =~ s/ /_/g ; 

  print "LOAD,$nowTS,$machine,$instance,$uc_database,$utilID,$loadStartTime,\"$utlValues_ID{'Description'}\",\"$converted_type\",$total,$completed\n";

}

sub printUtilityValues {

# ------------------------------------------------------------------------------
# Routine to print out a single utility's information
# ------------------------------------------------------------------------------

  my $currentRoutine = 'printUtilityValues';
  my $workType = '';
  $total = 0;
  $completed = 0;
  $percentLit = "unknown %";

  $allUtilities++;

  if ( $database ne 'All' && uc($database) ne uc($utlValues_ID{'Database Name'}) ) { return; } # this database is not required

  if ( ($utilityID ne 'All') && ($utilityID ne trim($utlValues_ID{'ID'}) ) ) { return; } # this database is not required

  $printedUtilities++;
  
  #  Display the info about the utility running

  print "ID: $utlValues_ID{'ID'} $utlValues_ID{'Type'} of $utlValues_ID{'Database Name'} started at $utlValues_ID{'Start Time'} ($utlValues_ID{'Description'})\n";

  if ( $currentSection eq 'ID' ) { # print out the details from a utility record (no phases)
    
    # calculate how many minutes this utility has been running ....
    
    my ($day, $mon, $year, $hr, $min, $sec);
    if ( $utilDate_USFormat ) { # US format
      ($mon, $day, $year, $hr, $min, $sec) = ($utlValues_ID{'Start Time'} =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
    }
    else {
      ($day, $mon, $year, $hr, $min, $sec) = ($utlValues_ID{'Start Time'} =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
    }
    $loadStartTime = "$year.$mon.$day $hr:$min:$sec";
    if ( $debugLevel > 2 ) { printDebug( "call: $year-$mon-$day $hr:$min:$sec, $nowTS"); }
    if ( $debugLevel > 2 ) { printDebug( "startTime: $utlValues_ID{'Start Time'}, day:$day, month:$mon, year:$year, hour:$hr, minute:$min, seconds:$sec)", $currentRoutine); }
    my $minsElapsed = timeDiff ("$year-$mon-$day $hr:$min:$sec", $nowTS, 'M');

    if ( $minsElapsed > (1440 * 7 ) ) { $utilDate_warning = 1; } # utility has been running longer than 7 days - perhaps the date format is wrong

    if (defined($utlValues_ID{'Completed Work'})) { ($completed, $workType) = ( $utlValues_ID{'Completed Work'} =~ /(\d*) (.*)/); }
    
    if ( $forceWork && ( $totalWork ne '' ) ) { #  force the entered total work to be the total work
      $total = $totalWork;
    }
    else {
      if (defined($utlValues_ID{'Total Work'})) { 
        ($total,$workType) = ( $utlValues_ID{'Total Work'} =~ /(\d*) (.*)/); 
      }
      elsif ( $totalWork ne '' ) {
        $total = $totalWork;
      }
    } 
    
    if ( $debugLevel > 0 ) { printDebug( "Minutes Elapsed: $minsElapsed, Total work is defined as $total $workType", $currentRoutine); }
    
    if ( $total == 0 ) { # no target work so unable to estimate run time
      if ( $completed > 0 ) {
        print "  Status: Running $utlValues_ID{'Description'} $utlValues_ID{'Type'}. Completed $completed $workType.\n";
      }
      else {
        print "  Status: Running $utlValues_ID{'Description'} $utlValues_ID{'Type'}\n";
      }
      print "          No total work figure available so no run time estimates can be generated. Has been running for " . displayMinutes($minsElapsed) . "\n\n";
    }
    else { # total work is available
      if ( $completed == 0 ) { # no work done so unable to estimate completion time
        print "  Status: Running $utlValues_ID{'Description'} $utlValues_ID{'Type'}. $total $workType to be processed\n";
        print "          No completed work figure available so no run time estimates can be generated. Has been running for " . displayMinutes($minsElapsed) . "\n\n";
      }
      else { # should be able to provide estimates
        $percent_completed = int(($completed / $total) * 100);
        $percentLit = "$percent_completed %";
        print "  Status: Running $utlValues_ID{'Description'} $utlValues_ID{'Type'}. $completed $workType out of $total ($percentLit) have been processed in " . displayMinutes($minsElapsed) . "\n";
        my $estMinutes = int(($total * ($minsElapsed - $excludeMinutes)) / $completed);
        my $stillToGo = int($estMinutes - ($minsElapsed -  $excludeMinutes));
        my ($isDuration, $durationTS) = processDuration("$stillToGo minutes",'T');
        my $finishTime = performTimestampAddition( $nowTS, $durationTS );
        print "          Expected to complete in " . displayMinutes($stillToGo) . " (" . displayMinutes($estMinutes+$excludeMinutes) . " in total) at $finishTime\n\n"; 
      }
    }
 
  }
  else { # it must have been called from a new Phase
  
    # calculate how many minutes this phase has been running ....
    
    my ($day, $mon, $year, $hr, $min, $sec);
    if ( $utilDate_USFormat ) { # US format
      ($mon, $day, $year, $hr, $min, $sec) = ( $utlValues_Phase{'Start Time'} =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/ );
    }
    else { 
      ($day, $mon, $year, $hr, $min, $sec) = ( $utlValues_Phase{'Start Time'} =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/ );
    }
    $loadStartTime = "$year.$mon.$day $hr:$min:$sec";
    if ( $debugLevel > 2 ) { printDebug( "%% startTime: $utlValues_Phase{'Start Time'}, day:$day, month:$mon, year:$year, hour:$hr, minute:$min, seconds:$sec)", $currentRoutine); }
    my $minsElapsed = timeDiff ("$year-$mon-$day $hr:$min:$sec", $nowTS, 'M');

    if ( $minsElapsed > (1440 * 7 ) ) { $utilDate_warning = 1; } # utility has been running longer than 7 days - perhaps the date format is wrong

    if (defined($utlValues_Phase{'Completed Work'})) { ($completed, $workType) = ( $utlValues_Phase{'Completed Work'} =~ /(\d*) (.*)/); }
    
    if ( $forceWork ) { # for the use of the entered work figure
       $total = $totalWork;
    }
    else {
      if (defined($utlValues_Phase{'Total Work'})) { 
        ($total,$workType) = ( $utlValues_Phase{'Total Work'} =~ /(\d*) (.*)/); 
      }
      elsif ( $totalWork ne '' ) {
        $total = $totalWork;
      }
    } 
    
    if ( $debugLevel > 0 ) { printDebug( "%% Minutes Elapsed: $minsElapsed, Total work is defined as $total $workType", $currentRoutine); }
    
    print "          Phase $utlValues_Phase{'Phase Number'} has been running since $utlValues_Phase{'Start Time'} \n";
    if ( $total == 0 ) { # target work so unable to estimate run time
      if ( $completed > 0 ) {
        print "  Status: Running $utlValues_Phase{'Description'} phase. Completed $completed $workType.\n";
      }
      else {
        print "  Status: Running $utlValues_Phase{'Description'} phase.\n";
      }
      print "          No total work figure available so no run time estimates can be generated. Has been running for " . displayMinutes($minsElapsed) . "\n\n";
    }
    else { # total work is available
      if ( $completed == 0 ) { # no work done so unable to estimate completion time
        print "  Status: Running $utlValues_Phase{'Description'} phase. $total $workType to be processed. \n";
        print "          No completed work figure available so no run time estimates can be generated. Has been running for " . displayMinutes($minsElapsed) . "\n\n";
      }
      else { # should be able to provide estimates
        $percent_completed = int(($completed / $total) * 100);
        $percentLit = "$percent_completed %";
        print "  Status: Running $utlValues_Phase{'Description'} phase. $completed $workType out of $total ($percentLit) have been processed in " . displayMinutes($minsElapsed) . "\n";
        my $estMinutes = int(($total * ($minsElapsed - $excludeMinutes)) / $completed);
        my $stillToGo = int($estMinutes - ($minsElapsed - $excludeMinutes));
        my ($isDuration, $durationTS) = processDuration("$stillToGo minutes",'T');
        my $finishTime = performTimestampAddition( $nowTS, $durationTS );
        print "          Expected to complete in " . displayMinutes($stillToGo) . " mins (" . displayMinutes($estMinutes+$excludeMinutes) . " in total) at $finishTime\n\n"; 
      }
    }
  }
  
  if ( $loadable ) { outputLoadValues(); }
   
} # end of printUtilityValues

sub by_key {
  $a cmp $b ;
}

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 [-?hs] [-A] -d <database> [-i <ID Name>] [-f <file name>] [-v[v]] [-r <reorg file>] [-x minutes] [-u|-e] [-L] [-t <total work>] [-T <total work>]

       Script to reformat obtained information about running utilities

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (in this program only suppesses parameter messages)
       -d              : database to query [default will be supplied by DB2DBDFT]
       -A              : print all reorgs (ignored if database not supplied)
       -i              : ID of utility to display (defaults to All)
       -f              : file to reads utility information from (defaults to dynamically retrieving it)
                         Note only list utility statements can be fed in through this file
       -r              : file to reads reorg information from (defaults to dynamically retrieving it)
                         Note only db2pd reorg statements can be fed in through this file
       -t              : total work to be used if no total work figure found
       -T              : total work to be used even if a total work figure found
       -e              : reorg date format is in European format dd/mm/yyyy
       -u              : reorg date format is in US format mm/dd/yyyy [default]
       -U              : non-reorg utilities date format is in US format mm/dd/yyyy [default is in European date format]
       -L              : also output in a loadable format
       -x              : exclude this many minutes from the elapsed time when calculating estimates
                         (primarily used to account for disk initialisation during restores)
       -v              : set debug level

       The date formats (utility and reorg) can be set permanently for a server by setting environment variables:

            export LCL_LUTIL_DATEFMT=\"EUR\"
            export LCL_LUTIL_DATEFMT_REORG=\"EUR\"

            value can be either of US (mm/dd/yyyy) or EUR (dd/mm/yyyy)

       NOTE: Essentially just reformats the output of the following command:

             db2 list utilities show detail 
             
             and if database is also supplied then 
             
             db2pd -db <database> -reorg
\n";

}

# set environment variable defaults if they exist


my $holdMSG ='';
my $tmp = $ENV{"LCL_LUTIL_DATEFMT"};
if ( defined($tmp) ) { 
  if ( uc($tmp) eq 'US' ) { $utilDate_USFormat = 1; }
  else { $utilDate_USFormat = 0; }
  $holdMSG = "Default utility date format being set from environment variable LCL_LUTIL_DATEFMT ($tmp)\n"; 
}

$tmp = $ENV{"LCL_LUTIL_DATEFMT_REORG"};
if ( defined($tmp) ) { 
  if ( uc($tmp) eq 'US' ) { $reorgDate_USFormat = 1; }
  else { $reorgDate_USFormat = 0; }
  $holdMSG .= "Default reorg date format being set from environment variable LCL_LUTIL_DATEFMT_REORG ($tmp)\n"; 
}

my $silent = 0;
my $printAllReorgs = 0;
$utilityID = 'All';

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsLvx:d:Ai:f:r:uUet:T:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = 1;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( ! $silent ) {
     print "Databse $getOpt_optValue will be checked\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "A"))  {
   $printAllReorgs = 1;
   if ( ! $silent ) {
     print "All reorgs (active and completed) will be displayed\n";
   }
 }
 elsif (($getOpt_optName eq "L"))  {
   $loadable = 1;
   if ( ! $silent ) {
     print "Information will also be printed in a loadable format\n";
   }
 }
 elsif (($getOpt_optName eq "i"))  {
   $utilityID = $getOpt_optValue;
   if ( ! $silent ) {
     print "Only utility ID $getOpt_optValue will be displayed\n";
   }
 }
 elsif (($getOpt_optName eq "t"))  {
   $totalWork = $getOpt_optValue;
   if ( ! $silent ) {
     print "If needed a total work figure of $getOpt_optValue will be used\n";
   }
 }
 elsif ( $getOpt_optName eq "T" )  {
   $forceWork = 1;
   $totalWork = $getOpt_optValue;
   if ( ! $silent ) {
     print "A figure of $getOpt_optValue will be used as the total work figure even if a total work figure found\n";
   }
 }
 elsif (($getOpt_optName eq "f"))  {
   $inFile = $getOpt_optValue;
   if ( ! $silent ) {
     print "Utility data will be read in from $getOpt_optValue\n";
   }
 }
 elsif (($getOpt_optName eq "e"))  {
   $reorgDate_USFormat = 0;
   if ( ! $silent ) {
     print "DB2PD Reorg date format is ISO format\n";
   }
 }
 elsif (($getOpt_optName eq "U"))  {
   $utilDate_USFormat = 1;
   if ( ! $silent ) {
     print "Utility (non reorg) date format is US format\n";
   }
 }
 elsif (($getOpt_optName eq "u"))  {
   $reorgDate_USFormat = 1;
   if ( ! $silent ) {
     print "DB2PD Reorg date format is US format\n";
   }
 }
 elsif (($getOpt_optName eq "x"))  {
   $excludeMinutes = $getOpt_optValue * 1;
   if ( $excludeMinutes != $getOpt_optValue ) { 
     usage ("x Parameter value ($getOpt_optValue) must be numeric");
   }
   else {
     if ( ! $silent ) {
       print "$getOpt_optValue minutes will be subtracted from the elapsed time when calculating estimated times\n";
     }
   }
 }
 elsif (($getOpt_optName eq "r"))  {
   $inReorg = $getOpt_optValue;
   if ( ! $silent ) {
     print "DB2PD Reorg data will be read in from $getOpt_optValue\n";
   }
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   $cF_debugLevel++;
   if ( ! $silent ) {
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
$nowTS = "$year.$month.$day $hour:$minute:$second";

if ( $database eq "") {
  my $tmpDB = $ENV{'DB2DBDFT'};
  if ( ! defined($tmpDB) ) {
    $database = 'All';    # just do every database
  }
  else {
    if ( ! $silent ) {
      print "Database defaulted to $tmpDB\n";
    }
    $database = $tmpDB;
  }
}

if ( ! $silent ) {
  if ( $holdMSG ne '' ) {
    print "$holdMSG";
  }
}

if ( ! $silent  ) {
  if ( uc($database) eq "ALL" ) {
    print "Note: Reorganisations are only printed when a database name is supplied\n";
  }
}

print "Utility Snapshot ($nowTS) .... \n\n";

# Open the input for processing ......

if ( $inFile eq "" ) { # 
  if (! open (UTILPIPE,"db2 list utilities show detail | "))  { die "Can't run db2 list utilities! $!\n"; }
}
else {
  if (! open (UTILPIPE,"<$inFile"))  { die "Can't open $inFile! \n$!\n";  }
}

# variables used in the loop

my $somethingToPrint = 0;

# loop through the input 

while ( <UTILPIPE> ) {
  chomp $_; # get rid of the CRLF
  if ( $debugLevel > 1 ) { printDebug( ">>>>>$_", $currentRoutine); }

  my @parms = split('=',$_,2);
  my $name = trim($parms[0]);
  my $value = trim($parms[1]);

  # process the input
  

  if ( $name eq 'ID' ) { #Start of a new utility section ....
  
    if ( $somethingToPrint ) { # some interesting things have been found .... print them out (just prevents printing on the first ID)
      printUtilityValues;
    }
    
    $currentSection = 'ID';
    %utlValues_ID    = () ; # clear out existing array values
    %utlValues_Phase = () ; # clear out existing array values
    $value = substr("$value     ",0,5); 
    $somethingToPrint = 1;
    
  }
  elsif ( $name =~ 'Phase Number' ) { #Start of a new phase section ....

    $currentSection = 'PHASE';
  
    if (defined($utlValues_Phase{'Phase Number [Current]'}) ) { # this is the phase after the currently active phase so print out the details
      printUtilityValues;
      $somethingToPrint = 0;
    }
  
    %utlValues_Phase = () ; # clear out existing array values
    
  }
  
  
  if ( $currentSection eq 'ID') { $utlValues_ID{$name} = $value; }
  elsif ( $currentSection eq 'PHASE') { $utlValues_Phase{$name} = $value; }

}

# check to see if there is anything else to print ......

if ( $somethingToPrint ) {
  printUtilityValues;
}

if ( ($printedUtilities == 0) && ( $allUtilities == 0) ) { print "\nNo Utilities to print\n"; }
elsif ( $printedUtilities == 0 ) { print "\nNo Utilities printed ($allUtilities Utilities found)\n"; }
else { print "\n$printedUtilities out of $allUtilities utilities printed\n"; }

# check to see if we should also be looking for reorgs .....

if ( $database ne "All" ) { # a database has been specified ....

  if ( $inReorg eq "" ) { #
    if (! open (UTILPIPE,"db2pd -db $database -reorgs | "))  { die "Can't run db2pd utilities! $!\n"; }
  }
  else {
    if (! open (UTILPIPE,"<$inReorg"))  { die "Can't open $inReorg! \n$!\n";  }
  }

  my $currentRoutine = 'processReorg';
  my $lineIndicator = '';
  my @TRI = ();
  my @TRS = ();
  my $TSID = '';
  my $TBID = '';
  my $PTID = '';
  my $type = '';
  my $firstLine = 1;
  $completed = 0;
  $percentLit = 'Unknown %';

  while ( <UTILPIPE> ) { # process the input .......

    chomp $_;

    if ( $debugLevel > 0 ) { printDebug("INPUT: $_\n", $currentRoutine) ; } 
    
    if ( $_ =~ /TbspaceID/ ) { # Heading line for the Table Reorg Information
      $lineIndicator = 'TRI';
      next; # skip to the next line as that is where the data is
    }

    if ( $_ =~ /TableName/ ) { # Heading line for the Table Reorg Stats
      $lineIndicator = 'TRS';
      next; # skip to the next line as that is where the data is
    }

    if ( trim($_) eq '' ) { # Blank lines mean an end of section so reset flags
      $lineIndicator = '';
    }

    # process the Table Reorg Information
    if ( $lineIndicator eq 'TRI' ) { 
      @TRI = split;
      $type = $TRI[7];
      $TSID = $TRI[1];
      $TBID = $TRI[2];
      $PTID = $TRI[3];
      if ( $debugLevel > 2) { for ( my $i = 0 ; $i<=$#TRI ; $i++ ) { print "$i: $TRI[$i]\n"; } }
      @TRI = ();
      next;
    }

    # process the Table Reorg Stats
    if ( $lineIndicator eq 'TRS' ) { 
      $allReorgs++;
      @TRS = split;
      $reorgTable = $TRS[1];

      if ( $debugLevel > 2) { for ( my $i = 0 ; $i<=$#TRS ; $i++ ) { print "$i: $TRS[$i]\n"; } }
      if ( $TRS[4] eq 'n/a' ) { # reorg not finished so no end date
      
        $printedReorgs++;

        if ( $firstLine ) { # first line output so print the heading
          # Print headings ........
          printf "\n %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", "Table Name", "Type", "Reorg Start/End", "Phase Start", "Phase", "Processed", "Total", "State";
          $firstLine = 0;
        }
      
        printf " %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", $TRS[1], $type, $TRS[2] . ' ' . $TRS[3], $TRS[5] . ' ' . $TRS[6], $TRS[8], $TRS[9], $TRS[10], $TRS[11];
        
        # work out run time so far .....

        my $sTime = $TRS[2] . ' ' . $TRS[3] ;
        my ($day, $mon, $year, $hr, $min, $sec);
        if ( $reorgDate_USFormat ) {
          ($mon, $day, $year, $hr, $min, $sec) = ( $sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
        }
        else {
          ($day, $mon, $year, $hr, $min, $sec) = ( $sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
        }
        $reorgStartTime = "$year.$mon.$day $hr:$min:$sec";
        if ( $debugLevel > 2 ) { printDebug( "startTime: " . $TRS[2] . ' ' . $TRS[3] . ", day:$day, month:$mon, year:$year, hour:$hr, minute:$min, seconds:$sec)", $currentRoutine); }
        my $minsElapsed = timeDiff ("$year-$mon-$day $hr:$min:$sec", $nowTS, 'M');

        if ( $minsElapsed > (1440 * 7 ) ) { $utilDate_warning = 1; } # utility has been running longer than 7 days - perhaps the date format is wrong

        if ( $debugLevel > 0 ) { printDebug( "Minutes Elapsed: $minsElapsed, Total work: $TRS[10]. Completed work: $TRS[9]",$currentRoutine); }

        if ( $TRS[9] == 0 ) { # no work done so unable to estimate completion time
          print "  Status: Phase $TRS[8] has a total has a total work target of $TRS[10] (Tablespace ID: $TSID, Table ID: $TBID, Partition: $PTID)\n";
          print "          No completed work figure available so no run time estimates can be generated. Has been running for " . displayMinutes($minsElapsed) . "\n\n";
        }
        else { # should be able to provide estimates
          my $phs_sTime;
          my $elapsed;
          my ($phs_day, $phs_mon, $phs_year, $phs_hr, $phs_min, $phs_sec);
          if ( $TRS[5] eq 'n/a' ) { # no phases
            $completed = $TRS[8];
            $maxCount = $TRS[9];
            $elapsed = timeDiff ("$year-$mon-$day $hr:$min:$sec", $nowTS, 'M');
          }
          else {
            $completed = $TRS[9];
            $maxCount = $TRS[10];

            $phs_sTime = $TRS[5] . ' ' . $TRS[6] ;
            if ( $reorgDate_USFormat ) {
              ($phs_mon, $phs_day, $phs_year, $phs_hr, $phs_min, $phs_sec) = ( $phs_sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
            }
            else {
              ($phs_day, $phs_mon, $phs_year, $phs_hr, $phs_min, $phs_sec) = ( $phs_sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
            }
            if ( $debugLevel > 2 ) { printDebug( "startTime: " . $TRS[5] . ' ' . $TRS[6] . ", day:$phs_day, month:$phs_mon, year:$phs_year, hour:$phs_hr, minute:$phs_min, seconds:$phs_sec)", $currentRoutine); }
            $elapsed = timeDiff ("$phs_year-$phs_mon-$phs_day $phs_hr:$phs_min:$phs_sec", $nowTS, 'M');
          }

          $percent_completed = int(($completed / $maxCount ) * 100);
          $percentLit = "$percent_completed %";
          print "  Status: Running Phase $TRS[7]. $completed out of $maxCount ($percentLit) have been processed in " . displayMinutes($elapsed). " (Tablespace ID: $TSID, Table ID: $TBID, Partition: $PTID)\n";
          my $estMinutes = int(($maxCount * $elapsed) / $completed);
          my $stillToGo = int($estMinutes - $elapsed);
          my $totalRunTime = int($stillToGo + $minsElapsed);
          my ($isDuration, $durationTS) = processDuration("$stillToGo minutes",'T');
          my $finishTime = performTimestampAddition( $nowTS, $durationTS );
          print "          Phase expected to complete in " . displayMinutes($stillToGo) . " (" . displayMinutes($estMinutes) . " in total for this phase, " . displayMinutes($totalRunTime) . " for the complete run) at $finishTime\n\n";
        }
        if ( $loadable ) { outputReorgLoadValues(); }
      }
      elsif ( $_ =~ /Paused/ ) { # reorg is paused so report it
      
        $printedReorgs++;

        if ( $firstLine ) { # first line output so print the heading
          # Print headings ........
          printf "\n %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", "Table Name", "Type", "Reorg Start/End", "Phase Start", "Phase", "Processed", "Total", "State";
          $firstLine = 0;
        }
      
        printf " %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", $TRS[1], $type, $TRS[2] . ' ' . $TRS[3], $TRS[6], $TRS[7], $TRS[9], $TRS[10], $TRS[11];
        printf " %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", ' ', ' ', $TRS[4] . ' ' . $TRS[5], ' ' ,  ' ' , ' ' , ' ' , ' ' ;
        
        # work out run time so far .....

        my $sTime = $TRS[2] . ' ' . $TRS[3] ;
        my ($day, $mon, $year, $hr, $min, $sec);
        if ( $reorgDate_USFormat ) {
          ($mon, $day, $year, $hr, $min, $sec) = ( $sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
        }
        else {
          ($day, $mon, $year, $hr, $min, $sec) = ( $sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
        }
        $reorgStartTime = "$year.$mon.$day $hr:$min:$sec";
        my $eTime = $TRS[4] . ' ' . $TRS[5] ;
        my ($eday, $emon, $eyear, $ehr, $emin, $esec);
        if ( $reorgDate_USFormat ) {
          ($emon, $eday, $eyear, $ehr, $emin, $esec) = ( $eTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
        }
        else {
          ($eday, $emon, $eyear, $ehr, $emin, $esec) = ( $eTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
        }

        if ( $debugLevel > 2 ) { printDebug( "startTime: " . $TRS[2] . ' ' . $TRS[3] . ", day:$day, month:$mon, year:$year, hour:$hr, minute:$min, seconds:$sec)", $currentRoutine); }
        if ( $debugLevel > 2 ) { printDebug( "endTime  : " . $TRS[4] . ' ' . $TRS[5] . ", day:$eday, month:$emon, year:$eyear, hour:$ehr, minute:$emin, seconds:$esec)", $currentRoutine); }
        my $minsElapsed = timeDiff ("$year-$mon-$day $hr:$min:$sec", "$eyear-$emon-$eday $ehr:$emin:$esec", 'M');

        if ( $minsElapsed > (1440 * 7 ) ) { $utilDate_warning = 1; } # utility has been running longer than 7 days - perhaps the date format is wrong

        if ( $debugLevel > 0 ) { printDebug( "Minutes Elapsed: $minsElapsed, Total work: $TRS[10]. Completed work: $TRS[9]",$currentRoutine); }

        if ( $TRS[9] == 0 ) { # no work done so unable to estimate completion time
          print "  Status: Phase $TRS[8] has a total has a total work target of $TRS[10] (Tablespace ID: $TSID, Table ID: $TBID, Partition: $PTID)\n";
          print "          No completed work figure available so no run time estimates can be generated. Has been running for " . displayMinutes($minsElapsed) . "\n\n";
        }
        else { # should be able to provide estimates
          my $phs_sTime;
          my $phs_eTime;
          my $elapsed;
          my ($phs_day, $phs_mon, $phs_year, $phs_hr, $phs_min, $phs_sec);
          my ($ephs_day, $ephs_mon, $ephs_year, $ephs_hr, $ephs_min, $ephs_sec);
          if ( $TRS[6] eq 'n/a' ) { # no phases
            $completed = $TRS[9];
            $maxCount = $TRS[10];
            $elapsed = $minsElapsed; # calculated from utility stop and start times
          }
          else {
            $completed = $TRS[10];
            $maxCount = $TRS[11];

            $phs_sTime = $TRS[6] . ' ' . $TRS[7] ;
            if ( $reorgDate_USFormat ) {
              ($phs_mon, $phs_day, $phs_year, $phs_hr, $phs_min, $phs_sec) = ( $phs_sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
            }
            else {
              ($phs_day, $phs_mon, $phs_year, $phs_hr, $phs_min, $phs_sec) = ( $phs_sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
            }
            if ( $debugLevel > 2 ) { printDebug( "startTime: " . $TRS[5] . ' ' . $TRS[6] . ", day:$phs_day, month:$phs_mon, year:$phs_year, hour:$phs_hr, minute:$phs_min, seconds:$phs_sec)", $currentRoutine); }
            $phs_eTime = $TRS[8] . ' ' . $TRS[9] ;
            if ( $reorgDate_USFormat ) {
              ($ephs_mon, $ephs_day, $ephs_year, $ephs_hr, $ephs_min, $ephs_sec) = ( $phs_eTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
            }
            else {
              ($ephs_day, $ephs_mon, $ephs_year, $ephs_hr, $ephs_min, $ephs_sec) = ( $phs_eTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
            }
            if ( $debugLevel > 2 ) { printDebug( "startTime: " . $TRS[5] . ' ' . $TRS[6] . ", day:$phs_day, month:$phs_mon, year:$phs_year, hour:$phs_hr, minute:$phs_min, seconds:$phs_sec)", $currentRoutine); }
            if ( $debugLevel > 2 ) { printDebug( "endTime  : " . $TRS[7] . ' ' . $TRS[8] . ", day:$ephs_day, month:$ephs_mon, year:$ephs_year, hour:$ephs_hr, minute:$ephs_min, seconds:$ephs_sec)", $currentRoutine); }
            $elapsed = timeDiff ("$phs_year-$phs_mon-$phs_day $phs_hr:$phs_min:$phs_sec", "$ephs_year-$ephs_mon-$ephs_day $ephs_hr:$ephs_min:$ephs_sec", 'M');
          }

          $percent_completed = int(($completed / $maxCount ) * 100);
          $percentLit = "$percent_completed %";
          print "  Status: Running Phase [Paused]. $completed out of $maxCount ($percentLit) have been processed in " . displayMinutes($elapsed). " (Tablespace ID: $TSID, Table ID: $TBID, Partition: $PTID)\n";
          my $estMinutes = int(($maxCount * $elapsed) / $completed);
          my $stillToGo = int($estMinutes - $minsElapsed);
          print "          The utility had been running for " . displayMinutes($elapsed) . " when it was paused. There is still " . displayMinutes($stillToGo) . " to go\n\n";
        }
        if ( $loadable ) { outputReorgLoadValues(); }
      }
      else {
        # end time for the reorg set so not currently active - ignore unless requested to print all
        if ( $printAllReorgs ) { 

          $printedReorgs++;

          if ( $firstLine ) { # first line output so print the heading
            # Print headings ........
            printf "\n %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", "Table Name", "Type", "Reorg Start/End", "Phase Start", "Phase", "Processed", "Total", "State";
            $firstLine = 0;
          }

          printf " %-25s %-8s %-19s %-19s %-15s %-9s %-9s %5s\n", $TRS[1], $type, $TRS[2] . ' ' . $TRS[3], $TRS[6] . ' ' . $TRS[7], $TRS[9], $TRS[10], $TRS[11], $TRS[12];
          printf " %-25s %-8s %-19s \n", '', '', $TRS[4] . ' ' . $TRS[5];

          # work out the total run time...

          my $sTime = $TRS[2] . ' ' . $TRS[3] ;
          my ($day, $mon, $year, $hr, $min, $sec);
          if ( $reorgDate_USFormat ) {
            ($mon, $day, $year, $hr, $min, $sec) = ( $sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
          }
          else {
            ($day, $mon, $year, $hr, $min, $sec) = ( $sTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
          }
          if ( $debugLevel > 2 ) { printDebug( "startTime: " . $TRS[2] . ' ' . $TRS[3] . ", day:$day, month:$mon, year:$year, hour:$hr, minute:$min, seconds:$sec)", $currentRoutine); }
          my $eTime = $TRS[4] . ' ' . $TRS[5] ;
          my ($emon, $eday, $eyear, $ehr, $emin, $esec);
          if ( $reorgDate_USFormat ) {
            ($emon, $eday, $eyear, $ehr, $emin, $esec) = ( $eTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
          }
          else {
            ($eday, $emon, $eyear, $ehr, $emin, $esec) = ( $eTime =~ /(\d\d).(\d\d).(\d\d\d\d).(\d\d).(\d\d).(\d\d)/) ;
          }
          if ( $debugLevel > 2 ) { printDebug( "endTime: " . $TRS[4] . ' ' . $TRS[5] . ", day:$eday, month:$emon, year:$eyear, hour:$ehr, minute:$emin, seconds:$esec)", $currentRoutine); }
          my $minsElapsed = timeDiff ("$year-$mon-$day $hr:$min:$sec", "$eyear-$emon-$eday $ehr:$emin:$esec", 'M');

          if ( $debugLevel > 0 ) { printDebug( "Minutes Elapsed: $minsElapsed",$currentRoutine); }

          print "  Status: Finished Reorg in " . displayMinutes($minsElapsed). " (Tablespace ID: $TSID, Table ID: $TBID, Partition: $PTID)\n";
          if ( $minsElapsed > (1440 * 7 ) ) { $reorgDate_warning = 1; } # reorg has been running longer than 7 days - perhaps the date format is wrong
        }
      }
      @TRS = ();
    }
  }

  if ( ($printedReorgs == 0) && ( $allReorgs == 0) ) { print "\nNo reorganisations to print\n"; }
  elsif ( $printedReorgs == 0 ) { print "\nNo reorganisations printed ($allReorgs reorgs found)\n"; }
  else { print "\n$printedReorgs out of $allReorgs reorganisations printed\n"; }

}

if ( $reorgDate_warning ) { # reorg run times look strange (> 7 days) so mention date format
 my ($REORGFMT, $REORGFMT_ALT, $REORGFMT_OPT, $REORGFMT_ENV);
 if ( $reorgDate_USFormat ) { # current format for date is US 
   $REORGFMT = 'US';
   $REORGFMT_ALT = 'EUR';
   $REORGFMT_OPT = '-e or default';
   $REORGFMT_ENV = 'export LCL_LUTIL_DATEFMT_REORG="EUR"';
 }
 else { # currently it is EUR
   $REORGFMT = 'EUR';
   $REORGFMT_ALT = 'US';
   $REORGFMT_OPT = '-u';
   $REORGFMT_ENV = 'export LCL_LUTIL_DATEFMT_REORG="US"';
 }
  
 print "\n>>>> WARNING <<<<\nThe reorg elapsed times in this report look long. Perhaps the date format selected is incorrect.\nCurrently selected date format is $REORGFMT\n";
 print "To change the format to $REORGFMT_ALT you can either use the $REORGFMT_OPT option on the command line or\n";
 print "set the environment variable with a command like '$REORGFMT_ENV' (for KSH/BASH)\n";
}

if ( $utilDate_warning ) { # reorg run times look strange (> 7 days) so mention date format
 my ($UTILFMT, $UTILFMT_ALT, $UTILFMT_OPT, $UTILFMT_ENV);
 if ( $utilDate_USFormat ) { # current format for date is US 
   $UTILFMT = 'US';
   $UTILFMT_ALT = 'EUR';
   $UTILFMT_OPT = 'default';
   $UTILFMT_ENV = 'export LCL_LUTIL_DATEFMT="EUR"';
 }
 else { # currently it is EUR
   $UTILFMT = 'EUR';
   $UTILFMT_ALT = 'US';
   $UTILFMT_OPT = '-U';
   $UTILFMT_ENV = 'export LCL_LUTIL_DATEFMT="US"';
 }
  
 print "\n>>>> WARNING <<<<\nThe utility (non reorg) elapsed times in this report look long. Perhaps the date format selected is incorrect.\nCurrently selected date format is $UTILFMT\n";
 print "To change the format to $UTILFMT_ALT you can either use the $UTILFMT_OPT option on the command line or\n";
 print "set the environment variable with a command like '$UTILFMT_ENV' (for KSH/BASH)\n";
}

exit;
