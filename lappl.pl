#!/usr/bin/perl
# --------------------------------------------------------------------
# lappl.pl
#
# $Id: lappl.pl,v 1.18 2018/10/21 21:01:49 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST APPLICATIONS SHOW DETAIL command
#
# Usage:
#   lappl.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lappl.pl,v $
# Revision 1.18  2018/10/21 21:01:49  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.17  2018/10/17 00:46:31  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.16  2017/04/24 02:20:30  db2admin
# add in subtotals for the different statuses
#
# Revision 1.15  2014/05/25 22:24:59  db2admin
# correct the allocation of windows include directory
#
# Revision 1.14  2014/01/05 02:24:44  db2admin
# Correct count of non-active connections
#
# Revision 1.13  2014/01/05 00:45:40  db2admin
# include 'Connection Completed' as waiting threads
#
# Revision 1.12  2013/10/28 05:24:04  db2admin
# add in -X option to not display the FW threads
#
# Revision 1.11  2012/09/25 06:49:18  db2admin
# change -q to -v
#
# Revision 1.10  2012/09/25 06:47:43  db2admin
# get rid of the NODE code
#
# Revision 1.9  2012/09/25 06:43:23  db2admin
# rewrite the code to make allowances for the differing versions of DB2
#
# Revision 1.8  2012/04/09 23:24:32  db2admin
# Adjust to take into account an extra space with 'Not Collected'
#
# Revision 1.7  2011/11/21 02:59:44  db2admin
# Change the way that waiting connections are displayed in the summary
#
# Revision 1.6  2011/11/15 05:05:22  db2admin
# correct bug with -A
#
# Revision 1.5  2010/06/10 05:04:51  db2admin
# adjust to print out originating node if available
#
# Revision 1.4  2009/10/14 22:17:08  db2admin
# Improve help information
#
# Revision 1.3  2009/07/20 23:12:04  db2admin
# Modify script to try and detect V8 command output
#
# Revision 1.2  2009/01/04 23:54:35  db2admin
# standardise parameters
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

my $ID = '$Id: lappl.pl,v 1.18 2018/10/21 21:01:49 db2admin Exp db2admin $';
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
    $logDir = `cd; pwd`;
    chomp $logDir;
    $logDir .= '/logs/';
    $dirSep = '/';
    $tempDir = '/var/tmp/';
  }
}
use lib "$scriptDir";
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $myDate_debugLevel $getOpt_diagLevel $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime $datecalc_debugLevel displayMinutes timeDiff timeAdd timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsDOR [DATA | DATAONLY] -d <database> [-v[v etc]] [-8] [-A] [-X]

       Script to format the output of a LIST APPLICATIONS SHOW DETAIL command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to be listed (if ALL then all databases will be listed - this is the default)
       -v              : increment the diag level
       -8              : version 8
       -A              : dont display waiting connections (also excludes those with a status of 'Connect Completed')
       -X              : exclude the monitoring fast write processes

       Note: This script formats the output of a 'db2 list applications for database <db> show detail' 
             or 'db2 list applications show detail' command
       \n";
}

# Set default values for variables

$silent = "No";
$database = "ALL";
$diagLevel = 0;
$version = "V9";
$onlyActive = "No";
$includeFW = "Yes";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hs8vAXd:";

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
 elsif (($getOpt_optName eq "8"))  {
   if ( $silent ne "Yes") {
     print "Display format will be considered DB2 Version 8\n";
   }
   $version = "V8";
 }
 elsif (($getOpt_optName eq "A"))  {
   if ( $silent ne "Yes") {
     print "No 'waiting' threads will be displayed\n";
   }
   $onlyActive = "Yes";
 }
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print "No FW threads will be included\n";
   }
   $includeFW = "No";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database connections to $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v"))  {
   $diagLevel++;
   if ( $silent ne "Yes") {
     print "Diag level will be incremented to $diagLevel\n";
   }
 }
 else { # handle other entered values ....
   if ( $database eq "ALL" ) {
     $database = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Database connections to $getOpt_optValue will be listed\n";
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
my %stateCount = ();

$TotalConnections = 0;
$TotalWaitingConnections = 0;

if ( $database eq "ALL" ) {
  if (! open (LAPPPIPE,"db2 list applications show detail | "))  { die "Can't run LIST APPLICATIONS! $!\n"; }
}
else {
  if (! open (LAPPPIPE,"db2 list applications for database $database show detail | "))  { die "Can't run LIST APPLICATIONS! $!\n"; }
}

# Print Headings ....
print "\nApplication listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($Now) .... \n\n";

while (<LAPPPIPE>) {
    if ( $diagLevel > 1 ) {print "Processing $_\n";}

    # parse the db2 list applications show detail

    # Get rid of lines that we dont want .....
    if ( $_ =~ /SQL1611W/ ) { # no data to process
      print "No applications are currently showing in a DB2 LIST APPLICATIONS command\n\n$_\n";
      exit;
    }

    if ( $_ =~ /CONNECT Auth Id/ ) { # in the heading line
      printf "%-8s %-20s %-6s %-34s %-8s %6s %6s %-20s\n",
             'AuthID', 'Application', 'App', 'Application ID', 'Database', 'Num of', 'Thread', 'Status';
      printf "%-8s %-20s %-6s %-34s %-8s %6s %6s %-20s\n",
             '', '', 'Handle', '', '', 'Agents', '', '';
      printf "%-8s %-20s %-6s %-34s %-8s %6s %6s %-20s\n",
             '--------', '--------------------', '------', '----------------------------------', '--------', '------', '------', '--------------------';
    }

    @lapplinf1 = split(/\s+/);
    if ( trim($lapplinf1[0]) eq "CONNECT") {
      next;
    }

    if ( trim($lapplinf1[0]) eq "") {
      next;
    }

    if ( $lapplinf1[0] =~ /-----/ ) { # heading delimiter
      $clNum = 0;
      $versKey = "";
      foreach $cl (@lapplinf1) {
        $clLen = length($cl);
        if ( $diagLevel > 0 ) {print "$clNum : $cl : $clLen\n"; }
        $versKey = "$versKey$clLen";
        $colWidth[$clNum] = $clLen;
        $clNum++;
      }
      if ( $diagLevel > 0 ) {print "VersKey >$versKey<\n"; }
    }

    # set the columns of the required fields (these are the defaults for Version 8)

    $cnAUTHID = 1;
    $cnAPPNAME = 2;
    $cnAPPHANDLE = 3;
    $cnAPPID = 4;
    $cnAGENTS = 6;
    $cnTHREAD = 8;
    $cnSTATUS = 9;
    $cnDBNAME = 12;

    # NOTE: versKey is just a concatenation of all of the lengths of the columns in the output 
    $db2Vers = "8" ;
    if ( $versKey eq "3020106251016153026820" ) { 
      $db2Vers = "9.1" ;
      $cnDBNAME = 11;
    }
    elsif ( $versKey eq "12820106251016153026820" ) {
      $db2Vers = "9.7" ;
      $cnDBNAME = 11;
    }

    if ( trim($lapplinf1[2]) eq "----------") { # it is a heading line
      next; # skip this line from further processing
    }

    if ( $diagLevel > 0 ) { print "\$cnAPPNAME=$cnAPPNAME, \$colWidth\[\$cnAPPNAME-1\]= " . $colWidth[$cnAPPNAME-1] . "\n"; }
      
    $dispAUTHID = trim(substr($_,colOffset($cnAUTHID),$colWidth[$cnAUTHID-1]));
    $dispAPPNAME = trim(substr($_,colOffset($cnAPPNAME),$colWidth[$cnAPPNAME-1]));
    $dispAPPHANDLE = trim(substr($_,colOffset($cnAPPHANDLE),$colWidth[$cnAPPHANDLE-1]));
    $dispAPPID = trim(substr($_,colOffset($cnAPPID),$colWidth[$cnAPPID-1]));
    $dispAGENTS = trim(substr($_,colOffset($cnAGENTS),$colWidth[$cnAGENTS-1]));
    $dispTHREAD = trim(substr($_,colOffset($cnTHREAD),$colWidth[$cnTHREAD-1]));
    $dispSTATUS = trim(substr($_,colOffset($cnSTATUS),$colWidth[$cnSTATUS-1]));
    $dispDBNAME = trim(substr($_,colOffset($cnDBNAME),$colWidth[$cnDBNAME-1]));

    if ( (($dispSTATUS =~ /Waiting/ ) || ($dispSTATUS =~ /Connect Completed/ )) ){
      $TotalWaitingConnections = $TotalWaitingConnections + 1;
    }

    # -A

    if ( defined($stateCount{$dispSTATUS}) ) {
      $stateCount{$dispSTATUS}++;
    }
    else {
      $stateCount{$dispSTATUS} = $stateCount{$dispSTATUS} + 1;
    }

    if ( (($dispSTATUS =~ /Waiting/ ) || ($dispSTATUS =~ /Connect Completed/ )) && ( $onlyActive eq "Yes") ){
      if ( defined ($waitingConnectionCNT{$dispDBNAME} ) ) {
        $waitingConnectionCNT{$dispDBNAME}++;
      }
      else {
        $waitingConnectionCNT{$dispDBNAME} = 1;
      }
      next;
    }

    # -X

    if ( ($dispAPPNAME =~ /^db2fw/ ) && ( $includeFW eq "No") ){
      if ( defined ($waitingConnectionCNT{$dispDBNAME} ) ) {
        $waitingConnectionCNT{$dispDBNAME}++;
      }
      else {
        $waitingConnectionCNT{$dispDBNAME} = 1;
      }
      next;
    }

    printf "%-8s %-20s %-6s %-34s %-8s %6s %6s %-20s\n",
             $dispAUTHID, $dispAPPNAME, $dispAPPHANDLE, $dispAPPID, $dispDBNAME, $dispAGENTS, $dispTHREAD, $dispSTATUS;

    $TotalConnections++;

    if ( defined( $connectionCNT{$dispDBNAME} ) ) {
      $connectionCNT{$dispDBNAME}++;
    }
    else {
      $connectionCNT{$dispDBNAME} = 1;
      @databases = (@databases,$dispDBNAME);
    }
}

print "\nTotal Connections Displayed : $TotalConnections ($TotalWaitingConnections)\n";

foreach $database ( @databases ) {
  if ( $onlyActive eq "Yes" ) {
    print "  Connections for $database : $connectionCNT{$database} ($waitingConnectionCNT{$database})\n"
  }
  else {
    print "  Connections for $database : $connectionCNT{$database}\n"
  }
}
print "\n";
if ( $onlyActive eq "Yes" ) {
  print "Note that the number in brackets is the number of waiting connections\n";
}

print "Status Counts:\n";

foreach $state ( keys %stateCount ) {
    print "  $state: $stateCount{$state}\n";
}
print "\n";

sub colOffset {
  my $cn = shift; # column number
  my $co = 0;

  if (($cn <= 1) || ($cn > $#colWidth) ) { # ignore the call if we dont have a column width to count up to
    return 0;
  }
  else {
    for ( $i = 0 ; $i < $cn -1 ; $i++ ) {
      $co = $colWidth[$i] + 1 + $co;
    }
  }

  if ( $diagLevel > 0 ) { print "Column Offset for $cn is $co\n"; }

  return $co;

}  
