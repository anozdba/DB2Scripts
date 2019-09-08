#!/usr/bin/perl
# --------------------------------------------------------------------
# DBLoopDriver.pl
#
# $Id: DBLoopDriver.pl,v 1.27 2019/07/12 04:55:03 db2admin Exp db2admin $
#
# Description:
# Loops through all databases for a machine (as determined via db2ilist and list db directory) and runs passed parameters against DB
#
# $Name:  $
#
# ChangeLog:
# $Log: DBLoopDriver.pl,v $
# Revision 1.27  2019/07/12 04:55:03  db2admin
# only open a new file on change of file name
#
# Revision 1.26  2019/07/12 04:34:15  db2admin
# 1. standardise use of silent
# 2. introduce 'use strict'
# 3. add in -o parameter to specify output file
#
# Revision 1.25  2019/02/07 04:18:52  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.24  2019/01/29 00:04:11  db2admin
# change the parameter names referenced in commonFunctions.pm
#
# Revision 1.23  2018/10/21 21:01:47  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.22  2018/10/18 22:58:48  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.21  2018/10/16 22:07:57  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.20  2018/03/27 04:11:57  db2admin
# allow ##NL## for unix
#
# Revision 1.19  2014/05/25 22:19:18  db2admin
# correct the allocation of windows include directory
#
# Revision 1.18  2013/06/14 02:11:33  db2admin
# undo a 'fix' made to export a variable - not needed and it broke the script
# on unix
#
# Revision 1.17  2013/06/06 02:12:21  db2admin
# Correct Windows bug for non-multilined commands
#
# Revision 1.16  2013/02/22 00:14:20  db2admin
# Add in version number to help command
#
# Revision 1.15  2013/02/22 00:11:29  db2admin
# Add in a refreshed timestamp
#
# Revision 1.14  2012/11/05 02:03:31  db2admin
# Add in ##LC_INSTANCE## and ##LC_DATABASE##
#
# Revision 1.13  2010/05/19 01:56:57  db2admin
# Add in in date/time information for display
#
# Revision 1.12  2010/05/18 01:40:22  db2admin
# correct bug in handling of ##NL##
# issue display of command being executed
#
# Revision 1.11  2009/10/14 01:48:48  db2admin
# Make the excuting print statement a bit more descriptive
#
# Revision 1.10  2009/10/14 01:45:10  db2admin
# Add in multi line facility for Windows
#
# Revision 1.9  2009/05/14 21:36:30  db2admin
# Added option -I to only process the current instance
#
# Revision 1.8  2009/05/12 04:03:56  db2admin
# Adjusted the way the output is generated
#
# Revision 1.7  2009/05/12 03:28:57  db2admin
# added in option to only process a single instance
#
# Revision 1.6  2009/01/07 05:11:14  db2admin
# add in options to specify a file holding the instances
#
# Revision 1.5  2009/01/06 23:43:02  db2admin
# Correct Usage display
#
# Revision 1.4  2009/01/05 21:42:40  db2admin
# COrrected but in processing of -c option
#
# Revision 1.3  2009/01/05 21:38:11  db2admin
# Standardise parameters and add in extra variables
#
# Revision 1.2  2008/10/27 01:51:02  m08802
# Alter the way that parameters are passed in
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: DBLoopDriver.pl,v 1.27 2019/07/12 04:55:03 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hsF -c <command> [-f <filename>] [-i <instance>] [-I] [-l <delimiter>] [-v[v]] [-p] [-o filename]

       Script to loop through all databases for a machine (as determined via db2ilist and list db directory) and runs passed parameters against DB

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode 
       -c              : Command to be executed for each instance found
       -i              : Instance to be selected
       -I              : Only process the current instance
       -f              : File name to use as input instead of doing a db2ilist command
       -F              : Use default file input (identical to -f db2ilist.txt)
       -l              : line delimiter (Windows only)
       -p              : just print out the commands generated
       -o              : filename to send STDOUT output to. Name will be substituted as necessary
       -v              : verbose mode (debugging)

  NOTE: Command may include the following variables that will be substituted:
             ##MACHINE##  - Will be replaced by the machine name the command is running on
             ##INSTANCE## - Will be replaced by the instance name retrieved from the db2ilist command
             ##LC_INSTANCE## - Will be replaced by the lower case instance name retrieved from the db2ilist command
             ##DATABASE## - Will be replaced by the database name retrieved
             ##LC_DATABASE## - Will be replaced by the lower case database name retrieved
             ##YYYYMMDD## - Will be replaced by the date in YYYYMMDD format
             ##NL##       - Will be replaced by a new line (Windows only - can also use -l parameter)
     \n";
}

# Set default values for variables

my $DB2INSTANCE;
my $silent = 0;
my $command = "";
my $inFile = "";
my $instanceParm = "All";
my $lineDelim = "";
my $debugLevel = 0;
my $print = "No";
my $outFileMask = '';

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsvpc:Ff:i:Il:o:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = 1;
 }
 elsif (($getOpt_optName eq "p") )  {
   print STDERR "Print out the generated commands but dont run them\n";
   $print = "Yes";
 }
 elsif (($getOpt_optName eq "o"))  {
   if ( ! $silent ) {
     print STDERR "Output file mask is $getOpt_optValue\n";
   }
   $outFileMask = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "l"))  {
   if ( ! $silent ) {
     print STDERR "Line delimiter will be $getOpt_optValue\n";
   }
   $lineDelim = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( ! $silent ) {
     print STDERR "Instance list will be read from $getOpt_optValue\n";
   }
   $inFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "F"))  {
   if ( ! $silent ) {
     print STDERR "Instance list will be read from db2ilist.txt\n";
   }
   $inFile = "db2ilist.txt";
 }
 elsif (($getOpt_optName eq "I"))  {
   $DB2INSTANCE = $ENV{'DB2INSTANCE'};
   if ( ! $silent ) {
     print STDERR "Instance $DB2INSTANCE will only be used.\n";
   }
   $instanceParm = $DB2INSTANCE;
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( ! $silent ) {
     print STDERR "Instance $getOpt_optValue will only be used.\n";
   }
   $instanceParm = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( ! $silent ) {
     print STDERR "debug level increased to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( ! $silent ) {
     print STDERR "Command to be run is $getOpt_optValue\n";
   }
   $command = $getOpt_optValue;
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
if ( $inFile ne "" ) {
  if (! open (INSTPIPE,"<$inFile"))  { die "Can't open $inFile! $!\n"; }
}
else {
  if (! open (INSTPIPE,"db2ilist | "))  { die "Can't run db2ilist! $!\n"; }
}

# global variables
my @cmdout_info;
my @cmds;
my $cmd;
my $dbalias;
my $dbname;
my $lc_dbalias;
my $lc_instance;
my $linein;
my $lne;
my $x;
my $instance = '';
my $database = '';
my $outFile = '';
my $lastFile = '';
my $fileOpen = 0;

while (<INSTPIPE>) {
    if ( $_ =~ /Instance Error encountered/) { next; } # skip this message ....

    $instance = $_;
    chomp $instance;

    if ( ($instanceParm ne "All") && ($instanceParm ne $instance) ) {
      print STDERR "Instance $instance is being ignored\n";
      next;
    } # skip this instance

    $ENV{'DB2INSTANCE'} = $instance;

    # Run the command file and prost out the databases .....
    if (! open (DBPIPE,"db2 list db directory | "))  { die "Can't run db2 list ! $!\n"; }

    while (<DBPIPE>) {

      $linein = $_;
      chomp $linein;
      @cmdout_info = split(/=/,$linein);

      if ($linein =~ /Database alias/) {
        $dbalias = trim($cmdout_info[1]);
      }
      elsif ($linein =~ /Database name/) {
        $dbname = trim($cmdout_info[1]);
      }
      elsif ($linein =~ /Directory entry type/) {
        if ($linein =~ /Indirect/) {

          ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
          $year = 1900 + $yearOffset;
          $month = $month + 1;
          $hour = substr("0" . $hour, length($hour)-1,2);
          $minute = substr("0" . $minute, length($minute)-1,2);
          $second = substr("0" . $second, length($second)-1,2);
          $month = substr("0" . $month, length($month)-1,2);
          $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
          $Now = "$year.$month.$day $hour:$minute:$second";

          $lc_dbalias = lc($dbalias);
          $lc_instance = lc($instance);

          $lastFile = $outFile;        # remember the last file that was opened
          $outFile = $outFileMask;
          if ( $outFile ne '' ) {
            $outFile =~ s/##MACHINE##/$machine/g;
            $outFile =~ s/##YYYYMMDD##/$YYYYMMDD/g;
            $outFile =~ s/##DATABASE##/$dbalias/g;
            $outFile =~ s/##LC_DATABASE##/$lc_dbalias/g;
            $outFile =~ s/##INSTANCE##/$instance/g;
            $outFile =~ s/##LC_INSTANCE##/$lc_instance/g;
          }

          $cmd = $command;
          $cmd =~ s/##MACHINE##/$machine/g;
          $cmd =~ s/##YYYYMMDD##/$YYYYMMDD/g;
          $cmd =~ s/##DATABASE##/$dbalias/g;
          $cmd =~ s/##LC_DATABASE##/$lc_dbalias/g;
          $cmd =~ s/##INSTANCE##/$instance/g;
          $cmd =~ s/##LC_INSTANCE##/$lc_instance/g;
          if ( $print eq "No" ) { # generate and run the commands
            if ( $outFile ne '' ) {
              print STDERR "Executing [$Now] ($instance/$dbalias): $cmd \nOutput in $outFile\n";
            }
            else {
              print STDERR "Executing [$Now] ($instance/$dbalias): $cmd \n";
            }
          }
          if ( $OS eq "Windows" ) { # check if it is multi line ....
            if ( $debugLevel > 0 ) { print STDERR "In windows land\n"; }
            if ( $print eq "No" ) { # generate and run the commands
              if ( ! open (CMDOUT, ">dbloopdriver_temp.bat") ) { die "Cant write to dbloopdriver_temp.bat\n $!\n"; }
            }
            if ( ( $cmd =~ /$lineDelim/ ) || ( $cmd =~ /##NL##/ ) ) { # Multi line ....
              if ( $debugLevel > 0 ) { print "STDERR MULTI LINE\n"; }
              if ( $lineDelim ne "" ) { # a line delimiter exists so convert ##NL## to it
                $cmd =~ s/##NL##/$lineDelim/g;
              }
              else {
                $lineDelim = '##NL##';
              }
              @cmds = split(/$lineDelim/, $cmd) ;
              if ( $print eq "Yes" ) {          
                print "set DB2INSTANCE=$instance\n";
              }
              else {
                print CMDOUT "set DB2INSTANCE=$instance\n";
              }
              foreach $lne ( @cmds) {
                if ( $debugLevel > 0 ) { print STDERR "Line: $lne\n"; }
                if ( $print eq "Yes" ) {
                  print "$lne\n";
                }
                else {
                  print CMDOUT "$lne\n";
                }
              } 
            }
            else {
              if ( $print eq "Yes" ) {
                print "set DB2INSTANCE=$instance\n";
                print "$cmd\n";
              }
              else {
                print CMDOUT "set DB2INSTANCE=$instance\n";
                print CMDOUT "$cmd\n";
              }
            }
            if ( $print eq "No" ) { # generate and run the commands
              close CMDOUT;
            }
            $cmd = 'dbloopdriver_temp.bat';
          }
          else { # it is probably unix ....
            if ( $debugLevel > 0 ) { print "BEFORE: $cmd\n"; }
            if ( $cmd =~ /##NL##/ ) { $cmd =~ s/##NL##/\;/g} ; # change all of the new line literals to ';'
            $cmd = "DB2INSTANCE=$instance ; $cmd"; # dont export the assignment as `` doesn't run ksh or bash
            if ( $debugLevel > 0 ) { print STDERR "AFTER: $cmd\n"; }
          }
          if ( $print eq "No" ) {
            if ( ! $silent  ) { print STDERR "Issuing: $cmd\n"; }
            $ENV{'DB2INSTANCE'} = $instance;
            $x = `$cmd`; 
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
          else {
            if ( ! $silent  ) { print "Issuing: $cmd\n"; }
          }
        }
      }
    }
}

if ( $fileOpen ) { close OUTFILE; }

