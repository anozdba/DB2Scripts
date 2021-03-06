#!/usr/bin/perl
# --------------------------------------------------------------------
# lsql.pl
#
# $Id: lsql.pl,v 1.13 2019/02/07 04:18:56 db2admin Exp db2admin $
#
# Description:
# Script to reformat the output of a supplied piece of SQL into comma 
# delimited form - notmally to be passed to a load program
#
# Usage:
#   lsql.pl <database> <sql file to run>
#
# $Name:  $
#
# ChangeLog:
# $Log: lsql.pl,v $
# Revision 1.13  2019/02/07 04:18:56  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.12  2019/01/25 03:12:41  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.11  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.10  2018/10/18 22:58:52  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.9  2018/10/17 03:47:32  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.8  2015/02/03 23:20:57  db2admin
# ensure that database, instance and machine are all the correct case
#
# Revision 1.7  2014/05/25 22:28:25  db2admin
# correct the allocation of windows include directory
#
# Revision 1.6  2011/11/21 03:02:23  db2admin
# Only delete the generated fil eif it is created (ie RunSQL is Yes)
#
# Revision 1.5  2011/02/17 23:42:14  db2admin
# add in the ability to handle just sql output files
#
# Revision 1.4  2011/02/17 22:17:24  db2admin
# allow the input file to just be processed - doesn't need to be run
#
# Revision 1.3  2009/01/22 00:03:44  db2admin
# Correct Windows delete command
#
# Revision 1.2  2008/12/30 21:53:36  db2admin
# Improved parameters and help messages
#
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

my $ID = '$Id: lsql.pl,v 1.13 2019/02/07 04:18:56 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hs -d <database> -f <SQL file> [-F]

       Script to reformat the output of a supplied piece of SQL into comma
       delimited form - notmally to be passed to a load program

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to insert the statements in to
       -f              : File containg the SQL to run (should be bar delimited)
       -F              : file contains the output of a SQL run (not the input to)

  NOTE: Input file is provided as STDIN
     \n ";
}

# Set default values for variables

$silent = "No";
$database = "";
$fileSQL = "";
$runSQL = "Yes";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

while ( getOpt(":?hsd:Ff:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print STDERR "File to be executed is $getOpt_optValue\n";
   }
   $fileSQL = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "F"))  {
   $runSQL = "No";
   if ( $silent ne "Yes") {
     print STDERR "Input file will be treated as a SQL output file\n";
   }
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print STDERR "Database to run the SQL on is ase $getOpt_optValue\n";
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
     if ( $silent ne "Yes") {
       print STDERR "Database to run the SQL on is ase $getOpt_optValue\n";
     }
   }
   elsif ( $fileSQL eq "" ) {
     $fileSQL = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print STDERR "File to be executed is $getOpt_optValue\n";
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

$instance = $ENV{'DB2INSTANCE'};
if ( $runSQL eq "Yes" ) {
  if ( $database eq "" ) {
    usage ("Database name MUST be supplied");
    exit;
  }
}

if ( $fileSQL eq "" ) {
  usage ("SQL filename name MUST be supplied");
  exit;
}

if ( $instance eq "" ) {
  $instance = $ENV{'ORACLE_SID'};
}

if ( $database eq "" ) {
  $database = $instance ;
}

# make sure the database and instance are lower case while the database is upper case

$database = uc($database);
$machine = lc($machine);
$instance = lc($instance);

$zeroes = "00";

if ( $runSQL eq "Yes" ) {
  if (! open(STDCMD, ">runSQLcmd.bat") ) {
    die "Unable to open a file to hold the commands to run $!\n"; 
  }
  print STDCMD "db2 connect to $database\n";
  print STDCMD "db2 -txf $fileSQL\n";

  close STDCMD;

  $pos = "";
  if ($OS ne "Windows") {
    $t = `chmod a+x runSQLcmd.bat`;
    $pos = "./";
  }

  if (! open (SQLPIPE,"${pos}runSQLcmd.bat |"))  { die "Can't run runSQLcmd.bat! $!\n"; }
} 
else { # just a file to be formatted
  if (! open (SQLPIPE,"<$fileSQL"))  { die "Can't open file $fileSQL $!\n"; }
}

while (<SQLPIPE>) {
    # Just prefix the output with machine, instance, database and delimit columns with commas

    chomp $_;

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    if ( ($_ =~ /selected\./) || ($_ =~ /Elapsed:/ )) { # get rid of unessential lines
      next;
    }

    if ( trim($_) eq "" ) { # skip blank lines
      next;
    }

    @sqlinfo = split(/\|/);

    if ( ($_ =~ /Database Connection Information/)  ) { # skip the connection information
      next;
    }

    if ( ( $#sqlinfo == 0 ) && ($_ =~ /=/)  ) { # skip entries where there is only one item and it contains =
      next;
    }

    $out = "$NowTS,$machine,$instance,$database";
    for ($i = 0; $i <= $#sqlinfo ; $i++ ) {
      $item = trim($sqlinfo[$i]);
      if ($item eq "-") {
        $item = "";
      }
      $out = "$out,$item";
    }
      
    print "$out\n";
}

if ( $runSQL eq "Yes" ) {
  if ($OS eq "Windows" ) {
   `del runSQLcmd.bat`;
  }
  else {
   `rm runSQLcmd.bat`;
  }
}
