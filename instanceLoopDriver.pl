#!/usr/bin/perl
# --------------------------------------------------------------------
# instanceLoopDriver.pl
#
# $Id: instanceLoopDriver.pl,v 1.14 2019/07/15 05:26:31 db2admin Exp db2admin $
#
# Description:
# Loop through all of the instances on a server and run the passed commands 
#
# Usage:
#   instanceLoopDriver.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: instanceLoopDriver.pl,v $
# Revision 1.14  2019/07/15 05:26:31  db2admin
# 1. Convert to 'use strict'
# 2. modify the way the $silent variable is used
# 3. add in -o option to allow output to be saved to a file
#
# Revision 1.13  2019/02/07 04:18:54  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.12  2019/01/25 03:12:40  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.11  2018/10/21 21:01:49  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.10  2018/10/18 22:58:50  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.9  2018/10/17 02:56:37  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.8  2014/05/25 22:23:54  db2admin
# correct the allocation of windows include directory
#
# Revision 1.7  2013/02/22 00:15:31  db2admin
# Add in version number to help message
#
# Revision 1.6  2013/02/22 00:07:27  db2admin
# Add in refreshed timestamp to each display
#
# Revision 1.5  2009/11/08 20:55:11  db2admin
# add extra information about which instance the command is being executed against
#
# Revision 1.4  2009/01/05 21:37:47  db2admin
# correct problem with -c parameter
#
# Revision 1.3  2009/01/02 03:30:00  db2admin
# enable program to run properly on Windows boxes
# improved parameter handling
# Add ##MACHINE## and ##YYYYMMDD## variables
#
# Revision 1.2  2008/10/27 01:55:28  m08802
# Add in ##INSTANCE## variable
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: instanceLoopDriver.pl,v 1.14 2019/07/15 05:26:31 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hs [-o mask] -c <command> 

       Script loops through all of the instances on a server and run the passed commands

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -o              : filename to send STDOUT output to. Name will be substituted as necessary 
       -c              : Command to be executed for each instance found

  NOTE: Command may include the following variables that will be substituted:
             ##INSTANCE## - Will be replaced by the instance name retrieved from the db2ilist command
             ##MACHINE##  - Will be replaced by the machine name the command is running on
             ##YYYYMMDD## - Will be replaced by the date in YYYYMMDD format
             ##HOME##     - (Only available on UNIX) WIll be replaced by the home directory of the instance
                            On Windows this will be replaced by the current directory
     \n";
}

# Set default values for variables

my $silent = 0;
my $command = "";
my $outFileMask = '';

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsc:o:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( ! $silent ) {
     print STDERR "Command to be run is $getOpt_optValue\n";
   }
   $command = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "o"))  {
   if ( ! $silent ) {
     print STDERR "Output file mask is $getOpt_optValue\n";
   }
   $outFileMask = $getOpt_optValue;
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $command eq "" ) {
     $command = $getOpt_optValue;
     if ( ! $silent ) {
       print STDERR "Command to be run is $getOpt_optValue\n";
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
my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $Now = "$year.$month.$day $hour:$minute:$second";
my $NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
my $NowTS = "$year-$month-$day-$hour.$minute.$second";
my $YYYYMMDD = "$year$month$day";

if ( $command eq "" ) {
  usage ("command MUST be supplied");
  exit;
}

# identify all of the Instances on the box ....
if (! open (INSTPIPE,"db2ilist | "))  { die "Can't run db2ilist! $!\n"; }

my $instance = '';
my $instOwnerHome = '';
my $x = '';
my $t = '';
my $lastFile = '';
my $fileOpen = 0;
my $outFile = '';

while (<INSTPIPE>) {
    if ( $_ =~ /Instance Error encountered/) { next; } # skip this message ....

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

    $instance = $_;
    chomp $instance;
    my $lc_instance = lc($instance);

    $ENV{'DB2INSTANCE'} = $instance;
    if ($OS ne "Windows" ) {
      $instOwnerHome = `grep $instance \/etc\/passwd | cut -d\":\" -f6`;
    }
    else {
      $instOwnerHome = `chdir`;
    }
    chomp $instOwnerHome;

    $lastFile = $outFile;        # remember the last file that was opened
    $outFile = $outFileMask;
    if ( $outFile ne '' ) {
      $outFile =~ s/##MACHINE##/$machine/g;
      $outFile =~ s/##YYYYMMDD##/$YYYYMMDD/g;
      $outFile =~ s/##INSTANCE##/$instance/g;
      $outFile =~ s/##LC_INSTANCE##/$lc_instance/g;
    }

    $t = $command;
    $t =~ s/##HOME##/$instOwnerHome/g;
    $t =~ s/##INSTANCE##/$instance/g;
    $t =~ s/##MACHINE##/$machine/g;
    $t =~ s/##YYYYMMDD##/$YYYYMMDD/g;

    if ( $outFile ne '' ) { # output is going to a file
      print STDERR "Executing [$NowTS] ($machine/$instance): $t\nOutput in $outFile\n";
    }
    else {
      print STDERR "Executing [$NowTS] ($machine/$instance): $t\n";
    }

    # run the command
    $x = `$t`;

    if ( $outFile ne '' ) { # output file set
      if ( $outFile ne $lastFile ) { # change of file name
        if ( $fileOpen ) { close OUTFILE; }
        if ( ! open(OUTFILE, ">", $outFile) ) {
          print STDERR "Unable to open $outFile for output\n$?\n";
          print STDERR "$x\n";
        }
        else { # new file opened .....
          $fileOpen = 1;     # set flag so we know it is open
          print OUTFILE "$x\n\n";
        }
      }
      else { # still writing to the same file
        print OUTFILE "$x\n\n";
      }
    }
    else { # just print it to STDOUT
      print "\n$x";
    }
}

