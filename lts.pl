#!/usr/bin/perl
# --------------------------------------------------------------------
# lts.pl
#
# $Id: lts.pl,v 1.39 2019/08/14 21:44:09 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST TABLESPACES command
#
# Usage:
#   lts.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lts.pl,v $
# Revision 1.39  2019/08/14 21:44:09  db2admin
# correct the way that the default data source is selected
#
# Revision 1.38  2019/08/05 22:28:53  db2admin
# only print out variations in options when -s option hasn't been selected
#
# Revision 1.37  2019/08/05 22:23:44  db2admin
# 1. add in option to preserve the case of machine, instance and database
# 2. by default make machine and instance lower case
# 3. force option -x when -D option selected
# 4. increase the size of state for 'list tablespaces' option (even though it doesn't seem to be used)
# 5. modify the option checking to default values when required
#
# Revision 1.36  2019/07/31 04:49:27  db2admin
# only print out messages when silent hasn't been selected
#
# Revision 1.35  2019/07/31 04:04:54  db2admin
# convert a maxsize of NONE to NULL
# ensure database is upper case in the data file
#
# Revision 1.34  2019/07/23 01:32:21  db2admin
# correct bug in calculation of free Mb when using list tablespaces
#
# Revision 1.33  2019/07/23 00:20:43  db2admin
# add in details about maximum tablespace size
#
# Revision 1.32  2019/06/09 08:59:44  db2admin
# add in indicator for when a lower HWM could be done
#
# Revision 1.31  2019/05/26 00:40:11  db2admin
# put in a pending free pages message if necessary\
#
# Revision 1.30  2019/05/10 03:51:11  db2admin
# add in free mb to display (not to the generated load file)
#
# Revision 1.29  2019/04/16 21:18:54  db2admin
# reorder the ingestData parms
#
# Revision 1.28  2019/03/12 23:11:47  db2admin
# accept a default value for the database
# alter the way that the $silent variable is used
#
# Revision 1.27  2019/03/01 04:24:47  db2admin
# increase the size of sto group bo a 12 char limit
#
# Revision 1.26  2019/03/01 04:17:33  db2admin
# add in new bufferpool and storage group columns to the monGetTablespace report (-m)
#
# Revision 1.25  2019/02/20 04:11:03  db2admin
# 1. when -t option is set restict the data being loaded by ingestData
# 2. add in -e option to wrap DB2 commands in a db2 command
# 3. sort generated LOAD DATA and generate SET TABLESPACE commands into ascending Tablespace ID order
# 4. add in minor debug statements
#
# Revision 1.24  2019/02/20 01:40:48  db2admin
# 1. Update help screen to make it option interactions more obvious
# 2. allow tablespace selection for the -m option
#
# Revision 1.23  2019/02/20 01:08:10  db2admin
#
# Essentially this mod merges the old lts.pl, lcont.pl and lspace.pl commands
#
# 1. Add in option to display container information
# 2. Include File system free space in container display
# 3. Add in -g option to generate SET TABLESPACE commands
# 4. add in -l options to force the use of LIST TABLESPACE (the old way of doing it)
# 5. add in -T option to indicate that total pages should be used on SET TABLESPACE
# 6. added in -D option to generate the displayed data in a load format
# 7. added in -O option to OMIT the report
# 8. added in the -F option to generate a file directory list commands
# 9. added the -p option to provide a string to replace the leading directories of file names
#    on a generated SET TABLESPACE command
#
# Revision 1.22  2019/02/18 04:17:55  db2admin
# modify record rejection to accomodate windows preferences
#
# Revision 1.21  2019/02/18 03:59:05  db2admin
# 1. add in code utilising ingestDate
# 2. correct totalling in MON_GET_TABLESPACE
# 3. alter options to now be normal, -m and -S
#
# Revision 1.20  2019/02/14 00:57:20  db2admin
# update help information with -f STDIN description
#
# Revision 1.19  2019/02/14 00:39:31  db2admin
# 1. modify format of generated output
# 2. allow tablespace information to be read from STDIN
# 3. procide detailed instructions on how to run when a restore is in progress
#
# Revision 1.18  2019/01/25 03:12:41  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.17  2016/04/15 06:22:57  db2admin
# update to use commonFunctions.pm
#
# Revision 1.16  2014/05/25 22:28:46  db2admin
# correct the allocation of windows include directory
#
# Revision 1.15  2013/09/19 05:48:34  db2admin
# increase the length of the tablespace name column
#
# Revision 1.14  2010/02/02 05:33:19  db2admin
# remove code that was preventing space calculations fro system managed tablespaces
#
# Revision 1.13  2010/01/11 01:27:38  db2admin
# Add in usage information on what command is being executed
#
# Revision 1.12  2009/11/12 21:28:26  db2admin
# correct database name in final line of output
#
# Revision 1.11  2009/10/05 21:29:31  db2admin
# added in debug mode
#
# Revision 1.10  2009/07/15 22:33:49  db2admin
# added on the allocated Mb value
#
# Revision 1.9  2009/06/05 01:46:30  db2admin
# correct code so Windows use does not produce an error
#
# Revision 1.8  2009/04/01 03:05:03  db2admin
# Alter tablespace name comparisons to be contains rather equals
#
# Revision 1.7  2009/01/19 05:08:13  db2admin
# initialise $scriptdir directory with a non null value
#
# Revision 1.6  2009/01/19 00:51:17  db2admin
# Add in a check to ensure that database is specified
#
# Revision 1.5  2009/01/18 23:41:05  db2admin
# correct for windows execution
#
# Revision 1.4  2008/12/05 02:21:19  db2admin
# correct timestamp in heading
#
# Revision 1.3  2008/12/05 02:19:25  m08802
# Add in standard parameter and make tablespace checking case insensitive
#
# Revision 1.2  2008/10/23 23:41:30  m08802
# Add code to display offline tablespaces
#
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: lts.pl,v 1.39 2019/08/14 21:44:09 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

my $machine;            # machine name
my $machine_info;       # ** UNIX ONLY ** uname
my @mach_info;          # ** UNIX ONLY ** uname split by spaces
my $OS;                 # OS
my $scriptDir;          # directory where the script is running
my $tmp;
my $dirSep;             # directory separator
my $tempDir; 
my $logDir;

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

chomp $machine;

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $cF_debugLevel ingestData tablespaceStateLit displayDebug);

sub adjustName {
  # Using the supplied prefix generate a new name

  my $currentRoutine = 'adjustName';
  
  my $name = shift;
  my $type = shift;
  my $prefix = shift;
  
  if ( $prefix eq '' ) { return $name; } # nothing to do
  
  my @levels = split($dirSep,$name);
  if ( (substr($name,1,1) eq ':') && ( substr($prefix,1,1) eq ':' ) ) { # probably changing a windows drive
    # both string have a drive letter
    $name = substr($name,2);    # remove the first 2 characters  
  }
  elsif( (substr($name,1,1) eq ':') && ( substr($prefix,1,1) ne ':' ) ) { # probably changing a windows drive
    # name has a drive letter but replacement doesn't
    $prefix = substr($name,0,2) . $prefix;    # add the drive letter to the replacement string
  }
  if ( $type eq 'F' ) { # filename
    $name = $prefix . $levels[$#levels-1] . $dirSep . $levels[$#levels];
  }
  else { # directory name
    $name = $prefix . $levels[$#levels];
  }
  
  return $name;
  
}  # end of adjustName
  
sub mount_point {
  # return the mount point

  my $currentRoutine = 'mount_point';

  my $fso = shift;
  my $ret = '';
  
  if ( $OS eq 'Windows' ) {
    if ( $fso =~ /\:/ ) {
      $ret = substr($fso,0,2);
    }
  }
  else { # unix
    $ret = `df -k $fso | grep -v Filesystem | grep -v 'not a block'`;
    my @tmp = split(" ",$ret);
    $ret = $tmp[5];
  }
  
  return $ret;
}
  
sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs [-d <database> | -f <Filename>] [-t <tablespace>] [-v[v]]
                [-l | -m | -S [[-c] [-O] [-F] [-g [-p <prefix>] [-e] [-T]] [-D [-L]]]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (in this program only suppesses parameter messages)
       -d  [REQUIRED]  : Database to list
       -t              : Limit output tablespaces containing this string
       -v              : turn on verbose/debug mode
       -f              : Instead of directly accessing the databases use this file as input
                         Note: -f STDIN will read input from standard input
                               db2 list tablespaces show detail | lts.pl -l -d dbadb -f STDIN

  ## Data source (mutually exclusive)
       -l  [DEFAULT]   : use 'list tablespaces show detail' to get information
       -m              : SQL based on MON_GET_TABLESPACE (see lts.sql)
       -S or -x        : use 'get snapshot for tablespaces on <database>' to get data

  ## Snapshot (-S or -x) Data Source options
       -c              : display container information
       -O              : dont produce the report (omit it)
       -g              : generate SET TABLESPACE commands
       -e              : parcel SET TABLESPACE commands in a DB2 \"\" statement
       -T              : use Total pages when generating SET TABLESPACE commands (ignored unless -g specified)
       -p              : string used to generate new file name when processing with -g (ignored unless -g specified)
       -D              : generate the data files to load
       -F              : generate file dircmd_<database>.bat with a unique list of commands to determine free space for all container mount points
       -L              : leave the case of machine, instance and database as it is

     NOTE: if any of the Snapshot specific options are selected then option -x WILL be forced
\n";

}

my $lowerHWMMsg = 0;   # flag indicating whether or not to print the lower HWM message
my $pendingMsg = 0;    # flag indicating whether or not to print the pending free pages message
my $infile = "";
my $TSName = "ALL";
my $database = "";
my $silent = 0;
my $debugLevel = 0;
my $useMonGetTablespace = 0;
my $useSnapshot = 0;
my $useList = 0;
my $showContainers = 0;
my $generateSETTS = 0;
my $generateReport = 1;
my $generateData = 0;
my $prefix = '';
my $useTotalAlloc = 0;
my $genDriveDir  = 0;
my $useDB2CMD = 0;
my $currentRoutine = 'Main';
my $changeCase = 1;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsxODmFcgLeSTvlp:f:d:t:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = 1;
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   $cF_debugLevel++;
   if ( ! $silent ) {
     print "Debug Level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "L"))  {
   $changeCase = 0;
   if ( ! $silent ) {
     print "The case of machine, instance and database will be preserved\n";
   }
 }
 elsif (($getOpt_optName eq "c"))  {
   $showContainers = 1;
   if ( ! $silent ) {
     print "Containers will be displayed\n";
   }
 }
 elsif (($getOpt_optName eq "e"))  {
   $useDB2CMD = 1;
   if ( ! $silent ) {
     print "The SET TABLESPACE commands will be generated in a DB2 command\n";
   }
 }
 elsif (($getOpt_optName eq "F"))  {
   $genDriveDir = 1;
   if ( ! $silent ) {
     print "A file (dircmd_<database>.bat) containing directory list commands will be generated\n";
   }
 }
 elsif (($getOpt_optName eq "T"))  {
   $useTotalAlloc = 1;
   if ( ! $silent ) {
     print "When creating the SET TABLESPACE commands the total allocation will be used\n";
     print "By default the HWM + 200 pages is used\n";
   }
 }
 elsif (($getOpt_optName eq "O"))  {
   $generateReport = 0;
   if ( ! $silent ) {
     print "Report will be omitted\n";
   }
 }
 elsif (($getOpt_optName eq "g"))  {
   $generateSETTS = 1;
   if ( ! $silent ) {
     print "SET TABLESPACE commands will be generated\n";
   }
 }
 elsif (($getOpt_optName eq "D"))  {
   $generateData = 1;
   if ( ! $silent ) {
     print "Data records will be generated for loading\n";
   }
 }
 elsif (($getOpt_optName eq "m"))  {
   $useMonGetTablespace = 1;
   if ( ! $silent ) {
     print "Extended reporting via MON_GET_TABLESPACE will be done\n";
   }
 }
 elsif (($getOpt_optName eq "S") || ($getOpt_optName eq "x"))  {
   $useSnapshot = 1;
   if ( ! $silent ) {
     print "get snapshot will be used to obtain data\n";
   }
 }
 elsif ( ($getOpt_optName eq "l") )  {
   $useList = 1;
   if ( ! $silent ) {
     print "list tablespaces will be used to obtain data\n";
   }
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( ! $silent ) {
     print "File $getOpt_optValue will be used as input\n";
   }
   $infile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( ! $silent ) {
     print "DB2 connection will be made to $getOpt_optValue\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( ! $silent ) {
     print "Only Tablespaces containing $getOpt_optValue will be listed\n";
   }
   $TSName = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $prefix =~ /$dirSep$/ ) { # if the last character is a directory separator
     $prefix = $getOpt_optValue;
   }
   else { # if not then add one on
     $prefix = "$getOpt_optValue$dirSep";
   }
   if ( ! $silent ) {
     print "Prefix '$prefix' will be used when generating new names\n";
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( ! $silent ) {
       print "DB2 connection will be made to $database\n";
     }
   }
   elsif ( $TSName eq "ALL" ) {
     $TSName = uc($getOpt_optValue);
     if ( ! $silent ) {
       print "Only tablespace $TSName will be listed\n";
     }
   }
   elsif ( ($infile eq "" ) && (substr($getOpt_optValue,0,5) eq "FILE:") ) {
     $infile = substr($getOpt_optValue,5);
     if ( ! $silent ) {
       print "File $infile will be sued as input\n";
     }
   }
   else {
     usage ("Parameter $getOpt_optName : This parameter is unknown");
     exit;
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

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

# Check the options that have been selected

if ( $database eq "") {
  my $tmpDB = $ENV{'DB2DBDFT'};
  if ( ! defined($tmpDB) ) {
    usage ("A database must be provided");
    exit;
  }
  else {
    if ( ! $silent ) {
      print "Database defaulted to $tmpDB\n";
    }
    $database = $tmpDB;
  }
}

if ( $useList + $useMonGetTablespace + $useSnapshot == 0 ) { # no method has been set - default to 'get list'
  if ( ! $silent ) { print "Defaulted to using 'db2 list tablespaces'\n"; }
  $useList = 1;
}

if ( $useList + $useMonGetTablespace + $useSnapshot > 1 ) { # more than one method has been set
  if ( $useSnapshot ) { # -x or -S has been set
    if ( ! $silent ) { print "Options -x, -m and -l are mutually exclusive - option x will be used\n"; }
    $useMonGetTablespace = 0;
    $useList = 0;
  }
  elsif ( $useMonGetTablespace ) {  # -m has bene set
    if ( ! $silent ) { print "Options -m and -l are mutually exclusive - option m will be used\n"; }
    $useList = 0;
  }
}

if ( $useList || $useMonGetTablespace ) { # check to make sure a snapshot only option has not been selected
  if ( $useDB2CMD || $useTotalAlloc || ($prefix ne '' ) ) { # options for the generate SET TS option have been set
    if ( ! $silent ) { print "Option -g assumed : An option for the generate SET TS (-g) has been selected\n";  }
    $generateSETTS = 1;
  }
    
  if ( ( ! $changeCase ) && ( ! $generateData ) ) { # change case is only applicable when data is being generated
    if ( ! $silent ) { print "Option -D assumed : Retain case is only applicatible when data is being generated\n";  }
    $generateData = 1;
  }
    
  if ( ( ! $generateReport ) && ( ! $generateData ) ) { # given that the report is being ommitted it is assumed that the data is wanted
    if ( ! $silent ) { print "Option -D assumed : It only makes sense to exclude the report if you only want the data\n";  }
    $generateData = 1;
  }
    
  if ( $generateData || $generateSETTS || $genDriveDir || $showContainers || ! $generateReport ) { # can only select -O, -c, -F, -g, -D when -x selected
    if ( ! $silent ) { print "Option -x assumed : When one of -O, -c, -F, -g or -D is selected then option x MUST be selected\n"; }
    $useSnapshot = 1; 
    $useList = 0;
    $useMonGetTablespace = 0;
  }
}

my $TotAlloc = 0;
my $TotUsed = 0;
my $Zeroes = "00";
my %dataOut = ();   # array to hold data to be printed and then loaded
my %drives = ();    # array to hold unique drive letters
my %data = ();      # the array to hold the ingested data
my %SETTS = ();     # array to hold SET TABLESPACE commands

if (! open(STDCMD, ">ltscmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 connect to $database\n";
if ( $debugLevel > 0 ) { print "To be executed: db2 connect to $database\n"; }
if ( $useMonGetTablespace ) {
  print "If SMS database statistics aren't being displayed then you should turn on\n";
  print "buffer pool statistics using the following commands:\n";
  print "                db2 attach to $ENV{'DB2INSTANCE'}\n"; 
  print "                db2 update dbm cfg using DFT_MON_BUFPOOL on\n\n"; 
  print STDCMD "db2 -txf ${scriptDir}lts.sql\n";
  if ( $debugLevel > 0 ) { print "To be executed: db2 -txf ${scriptDir}lts.sql\n"; }
}
elsif ( $useSnapshot ) {
  print STDCMD "db2 get snapshot for tablespaces on $database\n";
  if ( $debugLevel > 0 ) { print "To be executed: db2 get snapshot for tablespaces on $database\n"; }
}
else {
  print STDCMD "db2 list tablespaces show detail\n";
  if ( $debugLevel > 0 ) { print "To be executed: db2 list tablespaces show detail\n"; }
}
close STDCMD;

my $pos = "";
if ($OS ne "Windows") {
  my $t = `chmod a+x ltscmd.bat`;
  $pos = "./";
}

my $LTSPIPE;
if ( $infile eq "" ) {
  if ( $debugLevel > 0 ) { print "Input will be the output of the above commands\n"; }
  if (! open ($LTSPIPE,"${pos}ltscmd.bat |"))  {
    die "Can't run ltscmd.bat! $!\n";
  }
}
else {
  if ( uc($infile) eq 'STDIN' ) { 
    open ($LTSPIPE,"-") || die "Unable to open $infile\n"; 
    print "Input will be read from STDIN\n";
  }
  else {
    open ($LTSPIPE,$infile) || die "Unable to open $infile\n"; 
    print "Input will be read from $infile\n";
  }
}

# Print Headings ....
if ( $useMonGetTablespace ) { # use mon_get_tablespace
  print "Tablespace listing from MON_GET_TABLESPACE for Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($NowTS) .... \n\n";
  printf "%-4s %-18s %-4s %-17s %-12s %-10s %9s %9s %9s %9s %9s %1s %5s %10s %10s %-12s\n",
         '', '', '', '', '', '', '', '', '', '', '', 'L', 'Page','';
  printf "%-4s %-18s %-4s %-17s %-12s %-10s %9s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-12s\n",
         'TSID', 'Tablespace Name', 'Type', 'Contents', 'Sto Group', 'Buff Pool', 'Total Pgs', 'Used Pgs', 'Free Pgs', 'Pend Free', 'HWM', 'H', 'Size','Used Mb', 'Alloc Mb', 'Free Mb', 'State';
  printf "%-4s %-18s %-4s %-17s %-12s %-10s %9s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-12s\n",
         '----', '------------------', '----', '-----------------', '------------', '----------', '---------', '---------', '---------', '---------', '---------', '-', '-----', '----------', '----------', '----------', '------------';
}
elsif ( $useSnapshot ) { # use get snapshot
  if ($generateReport) { # generate the report
    print "\nTablespace listing from GET SNAPSHOT TABLESPACES for Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($NowTS) .... \n\n";
    printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-4s %-11s %-12s\n",
           '', '', '', '', '', '', '', '', '', 'L', 'Page','', '';
    printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-4s %-11s %-12s\n",
           'TSID', 'Tablespace Name', 'Type', 'Contents', 'Total Pgs', 'Used Pgs', 'Free Pgs', 'Pend Free', 'HWM', 'H', 'Size','Used Mb', 'Alloc Mb', 'Free Mb', 'ARSZ', 'Max Size', 'State';
    printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-4s %-11s %-12s\n",
           '----', '------------------', '----', '-----------------', '---------', '---------', '---------', '---------', '---------', '-', '-----', '----------', '----------', '----------', '----', '-----------', '------------';
  }         
}
elsif  ( $useList ) { # use list tablespace
  print "Tablespace listing from LIST TABLESPACES for Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($NowTS) .... \n\n";
  printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-12s\n",
         '', '', '', '', '', '', '', '', 'L', 'Page','','','','';
  printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-12s\n",
         'TSID', 'Tablespace Name', 'Type', 'Contents', 'Total Pgs', 'Used Pgs', 'Free Pgs', 'HWM', 'H', 'Size','Used Mb', 'Alloc Mb', 'Free Mb', 'State';
  printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-12s\n",
         '----', '------------------', '----', '-----------------', '---------', '---------', '---------', '---------', '-', '-----', '----------', '----------', '----------', '------------';
}

my $abort = 0;
my $TSID;
my $DefStorage;
my $restPending;
my $Type;
my $Name;
my $Contents;
my $TPages;
my $UPages;
my $FPages;
my $HWM;
my $PSize;
my $State;
my $MbFree ;
my $MbAlloc ;
my $MbUsed;
my $restoreInProgress = 0;
my @ltsinfo = ();
my $lowerHWM = ' ';

my %valid_entries = ();
if ( $useSnapshot ) {
  %valid_entries = (
     "Tablespace ID"                            => 1,
     "Tablespace name"                          => 1,
     "Total number of pages"                    => 1,
     "Number of used pages"                     => 1,
     "Number of pending free pages"             => 1,
     "Number of free pages"                     => 1,
     "Tablespace Type"                          => 1,
     "Using automatic storage"                  => 1,
     "Auto-resize enabled"                      => 1,
     "Maximum tablespace size (bytes)"          => 1,
     "High water mark (pages)"                  => 1,
     "Tablespace Content Type"                  => 1,
     "Tablespace Page size (bytes)"             => 1,
     "Number of containers"                     => 1,
     "Tablespace State"                         => 1
     );
     
  if ( $showContainers ) { # need some extra keys ....
    %valid_entries = (
      %valid_entries,
      "Container Name"                          => 1,
      "Container ID"                            => 1,
      "Container Type"                          => 1,
      "Total Pages in Container"                => 1,
      "Container is accessible"                 => 1,
      "Usable Pages in Container"               => 1,
      "File system used space (bytes)"          => 1,
      "File system total space (bytes)"         => 1,
    ); 
  }
  
  my $entFound = ingestData ($LTSPIPE, '=', \%valid_entries, \%data, $TSName, 'Tablespace name','','Container Name','File system total space');

  my $usedMb = 0;
  my $totalMb = 0;
  my $freeMb = 0;
  my $instance = lc($ENV{'DB2INSTANCE'});
  foreach my $tblspace ( sort {$data{$a}{"Tablespace ID"} <=> $data{$b}{"Tablespace ID"}} keys %data) {
  
    displayDebug("processing $tblspace",1,$currentRoutine);
    if ( ($tblspace =~ /$TSName/) || ($TSName eq "ALL") ) {
  
      $lowerHWM = ' ';
      $usedMb = $data{$tblspace}{"Number of used pages"} * $data{$tblspace}{"Tablespace Page size (bytes)"}/1024/1024;
      $totalMb = $data{$tblspace}{"Total number of pages"} * $data{$tblspace}{"Tablespace Page size (bytes)"}/1024/1024;
      $freeMb = $totalMb - $usedMb;

      $data{$tblspace}{"Tablespace Content Type"} =~ s/All permanent data. Regular table space./Data - Regular TS/;
      $data{$tblspace}{"Tablespace Content Type"} =~ s/All permanent data. Large table space./Data - Large TS/;
      $data{$tblspace}{"Tablespace Content Type"} =~ s/User Temporary data/User Temporary/;
      $data{$tblspace}{"Tablespace Content Type"} =~ s/System Temporary data/System Temporary/;
      $data{$tblspace}{"Tablespace Type"} =~ s/Database managed space/DMS/;
      $data{$tblspace}{"Tablespace Type"} =~ s/System managed space/SMS/;

      my $stateLit = tablespaceStateLit($data{$tblspace}{"Tablespace State"});

      if ( $data{$tblspace}{"High water mark (pages)"} > $data{$tblspace}{"Number of used pages"} ) { $lowerHWM = '*'; $lowerHWMMsg = 1;}

      if ( $generateReport ) { # printing out the report
        printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %9s %1s %5s %10.1f %10.1f %10.1f %-4s %-11s %-12s %-30s\n",
               $data{$tblspace}{"Tablespace ID"},
               $tblspace,
               $data{$tblspace}{"Tablespace Type"},
               $data{$tblspace}{"Tablespace Content Type"},
               $data{$tblspace}{"Total number of pages"},
               $data{$tblspace}{"Number of used pages"},
               $data{$tblspace}{"Number of free pages"},
               $data{$tblspace}{"Number of pending free pages"},
               $data{$tblspace}{"High water mark (pages)"},
               $lowerHWM,
               $data{$tblspace}{"Tablespace Page size (bytes)"},
               $usedMb,
               $totalMb,
               $freeMb,
               $data{$tblspace}{"Auto-resize enabled"},
               $data{$tblspace}{"Maximum tablespace size (bytes)"},
               $data{$tblspace}{"Tablespace State"},
               $stateLit;
        if ( $data{$tblspace}{"Number of pending free pages"} > 0 ) { $pendingMsg = 1; }
      }
      
      $TotAlloc += $totalMb;
      $TotUsed += $usedMb;
    
      if ( $generateData ) { # generate tablespace data

        my $maxSize = $data{$tblspace}{"Maximum tablespace size (bytes)"};
        if ( $maxSize eq 'NONE' )  { $maxSize = 'NULL'; }
      
        if ( $changeCase ) {
          $dataOut{$data{$tblspace}{"Tablespace ID"} . 'ATS'} = "TABLESPACE,$NowTS," .
                      lc($machine) . "," .
                      lc($instance) . "," .
                      uc($database) . 
                      ",$tblspace,$data{$tblspace}{\"Tablespace ID\"}," .
                      "$data{$tblspace}{\"Tablespace Type\"}," .
                      "$data{$tblspace}{\"Tablespace Content Type\"}," .
                      "$data{$tblspace}{\"Tablespace State\"}," .
                      "$data{$tblspace}{\"Total number of pages\"}," .
                      "$data{$tblspace}{\"Number of used pages\"}," .
                      "$data{$tblspace}{\"Number of free pages\"}," .
                      "$data{$tblspace}{\"High water mark (pages)\"}," .
                      "$data{$tblspace}{\"Tablespace Page size (bytes)\"}," .
                      "$usedMb," .
                      "$data{$tblspace}{\"Number of containers\"}," .
                      "$data{$tblspace}{\"Auto-resize enabled\"}," .
                      "$date," .
                      "$maxSize," . "\n";
        }
        else {
          $dataOut{$data{$tblspace}{"Tablespace ID"} . 'ATS'} = "TABLESPACE,$NowTS,$machine,$instance," . 
                      "$database,$tblspace,$data{$tblspace}{\"Tablespace ID\"}," .
                      "$data{$tblspace}{\"Tablespace Type\"}," .        
                      "$data{$tblspace}{\"Tablespace Content Type\"}," .        
                      "$data{$tblspace}{\"Tablespace State\"}," .        
                      "$data{$tblspace}{\"Total number of pages\"}," .        
                      "$data{$tblspace}{\"Number of used pages\"}," .        
                      "$data{$tblspace}{\"Number of free pages\"}," .        
                      "$data{$tblspace}{\"High water mark (pages)\"}," .        
                      "$data{$tblspace}{\"Tablespace Page size (bytes)\"}," .        
                      "$usedMb," .
                      "$data{$tblspace}{\"Number of containers\"}," .        
                      "$data{$tblspace}{\"Auto-resize enabled\"}," .        
                      "$date," . 
                      "$maxSize," . "\n";
        }
      }
      
      my $firstContainer = 1;
      my $SETTSContainers = '';
      foreach my $key ( sort keys %{$data{$tblspace}} ) { 
        if ( $key =~ /^Container Name:/ ) { # it the start of a container block
          if ( $generateReport && $showContainers ) {
            if ( $firstContainer ) {
              printf "                      %-4s %10s %10s %10s %10s %-4s %-60s\n",
                     'CID', 'FS Free Gb', 'Total Pgs', 'Usable Pgs', 'Alloc Mb', 'Type', 'File/Folder';
              printf "                      %-4s %10s %10s %10s %10s %-4s %-60s\n",
                     '----', '----------', '----------', '----------', '----------', '----', '-------------------------------------------------------------';
              $firstContainer = 0;       
            }
          }
          my $CName = $key;
          $CName =~ s/^Container Name://g;
          my $free = $data{$tblspace}{$key}{"File system total space (bytes)"} - $data{$tblspace}{$key}{"File system used space (bytes)"};
          $free = $free/1024/1024/1024;
          my $cont_mb_alloc = $data{$tblspace}{$key}{"Total Pages in Container"} * $data{$tblspace}{"Tablespace Page size (bytes)"}/1024/1024;
          my $type = substr($data{$tblspace}{$key}{"Container Type"},0,4);
          if ( $generateReport && $showContainers ) {
            printf "                      %-4s %10.2f %10s %10s %10d %-4s %-60s\n",
                   $data{$tblspace}{$key}{"Container ID"},
                   $free,        
                   $data{$tblspace}{$key}{"Total Pages in Container"},        
                   $data{$tblspace}{$key}{"Usable Pages in Container"},
                   $cont_mb_alloc,
                   $type,        
                   $CName;
          }
          my $mp = mount_point($CName);
          chomp $mp;
          $drives{$mp} = 1;
          if ( $generateData ) { # generate container data
            $cont_mb_alloc = int($cont_mb_alloc);
            $dataOut{$data{$tblspace}{"Tablespace ID"} . 'CNT'} = "CONTAINER,$NowTS,$machine,$instance," . 
                         uc($database) . ",$tblspace,$data{$tblspace}{\"Tablespace ID\"}," .
                         "$data{$tblspace}{$key}{\"Container ID\"}," .
                         "$CName,$type," .
                         "$data{$tblspace}{$key}{\"Total Pages in Container\"}," .        
                         "$data{$tblspace}{$key}{\"Usable Pages in Container\"}," .
                         "$data{$tblspace}{$key}{\"Container is accessible\"}," . 
                         "$cont_mb_alloc," . $mp . "\n";
          }
          if ( $generateSETTS ) { # start collecting container information
            if ( uc($type) eq 'FILE' ) { # file ....
              my $containerName = adjustName ($CName, 'F',$prefix);
              if ( $useTotalAlloc ) {
                $SETTSContainers .= ", FILE '$containerName' $data{$tblspace}{$key}{\"Total Pages in Container\"}";
              }
              else {
                my $HWMPages = int($data{$tblspace}{"High water mark (pages)"}/$data{$tblspace}{"Number of containers"}+200);
                $SETTSContainers .= ", FILE '$containerName' $HWMPages";
              }
            }
            else { # treat as PATH
              my $containerName = adjustName ($CName, 'P',$prefix);
              $SETTSContainers .= ", PATH '$containerName'";
            }
          }
        }
      }
        
      if ( $generateSETTS ) { # produce the SET TS command for this tablespace
        if ( $data{$tblspace}{"Using automatic storage"} eq 'Yes' ) { # Automatic Storage ....
          $SETTS{$data{$tblspace}{"Tablespace ID"}} = 'SET TABLESPACE CONTAINERS FOR ' .
                                                      $data{$tblspace}{"Tablespace ID"} . " USING AUTOMATIC STORAGE";
        }
        else {
          $SETTSContainers =~ s/^, /  /g; # remove the leading comma
          $SETTS{$data{$tblspace}{"Tablespace ID"}} = 'SET TABLESPACE CONTAINERS FOR ' .
                                                      $data{$tblspace}{"Tablespace ID"} . " USING (\n";
          my @lines = split (',' , $SETTSContainers);
          my $comma = ' ';
          foreach my $line (@lines) { # add each container
            $SETTS{$data{$tblspace}{"Tablespace ID"}} .= "        $comma$line\n";
            $comma = ' ,';
          }
          $SETTS{$data{$tblspace}{"Tablespace ID"}} .= ")";                                          
        }
      }
        
      if ( $generateReport && $showContainers ) {
        print "\n";  # put in a line break between the containers and the next tablespace
      }
    }
  }
  if ( $generateSETTS ) { # produce the SET TS command for this tablespace
    foreach my $tmpKey ( sort {$a<=>$b} keys %SETTS) {
      if ( $useDB2CMD ) {
        print "db2 \"$SETTS{$tmpKey}\"\n";
      }
      else {
        print "$SETTS{$tmpKey}\n;\n";
      }
    }
  }
  if ( $generateData ) {
    foreach my $tmpData ( sort {$a<=>$b} keys %dataOut) {
      print "$dataOut{$tmpData}";
    }
  }
  if ( $genDriveDir ) { # produce a file of directory list commands
    if (! open(DIRCMD, ">dircmd_$database.bat") ) { die "Unable to open a file to hold the dir commands to run $!\n"; }
    if ( ! $silent ) { print "starting to write out commands\n"; }
    print DIRCMD "echo \"SERVER: $machine\"\n";

    foreach my $drive ( sort keys %drives ) {
      if ($OS eq "Windows" ) {
        print DIRCMD "dir $drive\n";
      }
      else {
        print DIRCMD "df -k $drive\n";
      }
    }
    close DIRCMD;
  }

}
else { # either MON_GET_TABLESPACE or LIST TABLESPACES

  while (<$LTSPIPE>) {

    if ( $abort ) { next; }

    chomp $_;

    if ( $debugLevel > 0 ) { print "Input: $_\n"; }

    if ( $_ =~ /because a previous restore is incomplete or still in progress/) {
      $restoreInProgress = 1;
    }

    if ( ( $_ =~ /SQL1024N/) ) {
    
      if ( $restoreInProgress ) {
        print "This script cant run the required commands to generate the information as they need to be run in the same process that is running the restore\n";
        print "In the screen doing the restore please run:\n";
        print "   db2 list tablespaces show detail | lts.pl -d $database -f STDIN\n";
        $abort = 1;
      }
      else {
        print "A database connection must be established before running this program - perhaps $database is not the database name \n";
        $abort = 1;
      }
    }

    if ( $useMonGetTablespace ) { # use sql against the database
      $lowerHWM = ' ';
      @ltsinfo = split(" ",$_,15);
      $TotAlloc = $TotAlloc + $ltsinfo[10];
      $TotUsed = $TotUsed + $ltsinfo[9];

      # skip the connection headings
      if ( trim($_) eq '' ) { next; }
      if ( $_ =~ /Database Connection/ ) { next; }
      if ( $_ =~ /db2 connect to / ) { next; }
      if ( $_ =~ /db2 -txf / ) { next; }
      if ( $_ =~ /Database server/ ) { next; }
      if ( $_ =~ /SQL authorization/ ) { next; }
      if ( $_ =~ /Local database alias/ ) { next; }

      $ltsinfo[14] = trim($ltsinfo[14]);    #  strip off trailing spaces of state
      $ltsinfo[13] = substr($ltsinfo[13],0,10);    #  limit bufferpool to 10 chars
      $ltsinfo[12] = substr($ltsinfo[12],0,12);    #  limit storage group to 12 chars
      my $freeMb = $ltsinfo[10] - $ltsinfo[9];

      if ( $ltsinfo[7] > $ltsinfo[4] ) { $lowerHWM = '*'; $lowerHWMMsg = 1; } # HWM > Used pages

      if ( ($ltsinfo[1] =~ /$TSName/) || ($TSName eq "ALL") ) {
        printf "%-4s %-18s %-4s %-17s %-12s %-10s %9s %9s %9s %9s %9s %1s %5s %10.1f %10.1f %10.1f %-6s\n",
               $ltsinfo[0],$ltsinfo[1],$ltsinfo[2],$ltsinfo[11],$ltsinfo[12],$ltsinfo[13],$ltsinfo[3],$ltsinfo[4],$ltsinfo[5],$ltsinfo[6],$ltsinfo[7],$lowerHWM,$ltsinfo[8],$ltsinfo[9],$ltsinfo[10],$freeMb,$ltsinfo[14];
      }
    }
    elsif ( $useList ) { # use "list tablespaces show detail" command

      @ltsinfo = split(/=/);

      if ( $debugLevel > 0 ) { print "$ltsinfo[0] : $ltsinfo[1]\n"; }

      if ( trim($ltsinfo[0]) eq "Tablespace ID") {
        $TSID = trim($ltsinfo[1]);
        $DefStorage = "";
        $restPending = '';
      }

      if ( trim($ltsinfo[0]) eq "Name") {
        $Name = trim($ltsinfo[1]);
      }

      if ( trim($ltsinfo[0]) eq "Type") {
        $Type = trim($ltsinfo[1]);
        if ( $Type eq 'System managed space' ) {
          $Type = 'SMS';
        }
        elsif ( $Type eq 'Database managed space' ) {
          $Type = 'DMS';
        }
      }

      if ( trim($ltsinfo[0]) eq "Contents") {
        $Contents = trim($ltsinfo[1]);
        if ($Contents eq "All permanent data. Regular table space.") {
          $Contents = "Data - Regular TS";
        }
        elsif ($Contents eq "All permanent data. Large table space.") {
          $Contents = "Data - Large TS";
        }
        elsif ($Contents eq "User Temporary data") {
          $Contents = "User Temporary";
        }
        elsif ($Contents eq "System Temporary data") {
          $Contents = "System Temporary";
        }
      }

      if ( trim($ltsinfo[0]) eq "Restore pending") {
        # if this is the case then the wont be any page size info coming .....
        $restPending = "Restore Pending";
        $TPages = "N/A";
        $UPages = "N/A";
        $FPages = "N/A";
        $HWM = "N/A";
        $PSize = "N/A";
      }

      if ( trim($ltsinfo[0]) eq "Storage may be defined") {
        if ( $DefStorage !~ /Must Define Storage/ ) {
          # if this is the case then the wont be any page size info coming .....
          $DefStorage = "May Define Storage";
          $TPages = "N/A";
          $UPages = "N/A";
          $FPages = "N/A";
          $HWM = "N/A";
          $PSize = "N/A";
          if ( $restPending ne '' ) { $DefStorage = "$restPending - $DefStorage"; }
          if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
            printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %9s %9s %-12s\n",
                 $TSID,$Name,$Type,$Contents,$TPages,$UPages,$FPages,$HWM,' ',$PSize,$restPending,$DefStorage,"$State - $DefStorage";
          }
        }
      }

      if ( trim($ltsinfo[0]) eq "Storage must be defined") {
        # if this is the case then the wont be any page size info coming .....
        $DefStorage = "Must Define Storage";
        $TPages = "N/A";
        $UPages = "N/A";
        $FPages = "N/A";
        $HWM = "N/A";
        $PSize = "N/A";
        if ( $restPending ne '' ) { $DefStorage = "$restPending - $DefStorage"; }
        if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
          printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %9s %9s %-12s\n",
                 $TSID,$Name,$Type,$Contents,$TPages,$UPages,$FPages,$HWM,' ',$PSize,'','',"$State - $DefStorage";
        }
      }

      if ( trim($ltsinfo[0]) eq "State") {
        $State = trim($ltsinfo[1]);
      }

      if ( trim($ltsinfo[0]) eq "Offline") {
        if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
          printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %9s %9s %-12s\n",
                 $TSID,$Name,$Type,$Contents,'***','Offline','***      ','','','','','',$State; 
        }
      }

      if ( trim($ltsinfo[0]) eq "Total pages") {
        $TPages = trim($ltsinfo[1]);
        if ( $TPages eq "Not applicable" ) {
          $TPages = "N/A";
        }
      }

      if ( trim($ltsinfo[0]) eq "Used pages") {
        $UPages = trim($ltsinfo[1]);
        if ( $UPages eq "Not applicable" ) {
          $UPages = "N/A";
        }
      }

      if ( trim($ltsinfo[0]) eq "High water mark (pages)") {
        $HWM = trim($ltsinfo[1]);
        $lowerHWM = ' ';
        if ( $HWM eq "Not applicable" ) {
          $HWM = "N/A";
        }
        else {
          if ( $HWM > $UPages ) { $lowerHWM = '*'; $lowerHWMMsg = 1; } # HWM > Used pages
        }
      }

      if ( trim($ltsinfo[0]) eq "Free pages") {
        $FPages = trim($ltsinfo[1]);
        my $dig = index($MbFree,".",0);
        if ($dig == -1) {
          $dig  = length($MbFree) + 1;
          $MbFree = $MbFree . ".00";
        }
        else {
          $MbFree = "$MbFree$Zeroes";
        }

        $MbFree = substr($MbFree,0,$dig + 3);
        if ( $FPages eq "Not applicable" ) {
          $FPages = "N/A";
        }
      }

      if ( trim($ltsinfo[0]) eq "Page size (bytes)") {
        $PSize = trim($ltsinfo[1]);
        $MbFree = ($FPages * $PSize)/1024/1024;
        # and now the printout .....

        $MbAlloc = ($TPages * $PSize)/1024/1024;
        my $dig = index($MbAlloc,".",0);
        if ($dig == -1) {
          $dig  = length($MbAlloc) + 1;
          $MbAlloc = $MbAlloc . ".00";
        }
        else {
          $MbAlloc = "$MbAlloc$Zeroes";
        }

        $MbAlloc = substr($MbAlloc,0,$dig + 3);
        $TotAlloc = $TotAlloc + $MbAlloc;
        $MbUsed = ($UPages * $PSize)/1024/1024;
        $TotUsed = $TotUsed + $MbUsed;
        my $dig = index($MbUsed,".",0);
        if ($dig == -1) {
          $dig  = length($MbUsed) + 1;
          $MbUsed = $MbUsed . ".00";
        }
        else {
          $MbUsed = "$MbUsed$Zeroes";
        }
        $MbUsed = substr($MbUsed,0,$dig + 3);

        if ( ($Name =~ /$TSName/) || ($TSName eq "ALL") ) {
          # This will never be executed if "Define Storage" is required as no page size will ever be found
          printf "%-4s %-18s %-4s %-17s %9s %9s %9s %9s %1s %5s %10s %10s %10s %-12s\n",
                 $TSID,$Name,$Type,$Contents,$TPages,$UPages,$FPages,$HWM,$lowerHWM,$PSize,$MbUsed,$MbAlloc,$MbFree,$State; 
        }
      }

    }
  }
}

$TotAlloc = $TotAlloc / 1024;
my $dig = index($TotAlloc,".",0);
if ($dig == -1) {
  $dig  = length($TotAlloc) + 1;
  $TotAlloc = $TotAlloc . ".00";
}
else {
  $TotAlloc = "$TotAlloc";
}
$TotAlloc = substr($TotAlloc,0,$dig + 3);

$TotUsed = $TotUsed / 1024;
$dig = index($TotUsed,".",0);
if ($dig == -1) {
  $dig  = length($TotUsed) + 1;
  $TotUsed = $TotUsed . ".00";
}
else {
  $TotUsed = "$TotUsed";
}
$TotUsed = substr($TotUsed,0,$dig + 3);
if ( $generateReport ) {
  print "\nTotal Storage in use for $database is $TotUsed Gb out of $TotAlloc Gb allocated\n\n";
  if ( $pendingMsg ) {
    print "To release the 'pending free pages' to free pages issue a 'db2 list tablespaces show detail' command\n\n";
  }
  if ( $lowerHWMMsg ) {
    print "An asterisk in the LH column indicates that the HWM could be lowered. In Db2 9.7 and later databases DMS and Automatic storage databases\n";
    print "can lower the HWM through use of the 'ALTER TABLESPACE XXX LOWER HIGH WATER MARK' command. This may improve backup elapsed times and may improve \n";
    print "table scan operations - see manuals for details and eligibility\n\n";
  }
}

if ($OS eq "Windows" ) {
 `del ltscmd.bat`;
}
else {
 `rm ltscmd.bat`;
}


