#!/usr/bin/perl
# --------------------------------------------------------------------
# ldcs.pl
#
# $Id: ldcs.pl,v 1.6 2018/10/18 22:58:51 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST DCS DIRECTORY command
#
# Usage:
#   ldcs.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ldcs.pl,v $
# Revision 1.6  2018/10/18 22:58:51  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.5  2018/10/17 01:09:28  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.4  2014/05/25 22:27:02  db2admin
# correct the allocation of windows include directory
#
# Revision 1.3  2010/03/03 03:26:04  db2admin
# Various changes:
# 1. catch error SQL1311N and put out appropriate message
# 2. Change debug levels for a number of displays
# 3. Correct heading
# 4. Only print out Generated heading if some entries are found
#
# Revision 1.2  2010/03/03 03:04:43  db2admin
# remove windows CR/LF
#
# Revision 1.1  2010/03/03 03:03:08  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

my $ID = '$Id: ldcs.pl,v 1.6 2018/10/18 22:58:51 db2admin Exp db2admin $';
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
    $scriptDir = 'c:\udbdba\scrxipts';
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
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $myDate_debugLevel $getOpt_diagLevel $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime $datecalc_debugLevel displayMinutes timeDiff timeAdd timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsg [-i <instance> | -f <filename>] -d <database> [-v[v]]

       Script to format the output of a LIST DCS DIRECTORY command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -g              : Generate the CATALOG statements to reproduce the entry
       -s              : Silent mode (dont produce the report)
       -d              : Database to list (if not entered defaults to ALL
       -i              : Instance to query (if not entered then defaults to value of DB2INSTANCE variable)
       -f              : File name to process 
       -v              : set debug level

      NOTE: This script formats the output of a 'list dcs directory' command
";
}

$infile = "";
$DBName_Sel = "";
$genDefs = "N";
$silent = "No";
$instance = "";
$debugLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsgvf:d:i:s|^GENDEFS";

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt($getOpt_opt) ) {
 if (($getOpt_optName eq "g") || ($getOpt_optName eq "GENDEFS") )  {
   if ( $silent ne "Yes") {
     print "Catalog definitions will be produced\n";
   }
   $genDefs = "Y";
 }
 elsif (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be read instead of accessing the DB2 Catalog\n";
   }
   $infile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be listed\n";
   }
   $DBName_Sel = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( $silent ne "Yes") {
     print "Instance $getOpt_optValue will be used\n";
   }
   $instance = getOpt_optValue;
   $ENV{'DB2INSTANCE'} = $getOpt_optValue;
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $instance eq "" ) {
     $instance = getOpt_optValue;
     $ENV{'DB2INSTANCE'} = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Instance $getOpt_optValue will be used\n";
     }
   }
   elsif ( $DBName_Sel eq "" ) {
     $DBName_Sel = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Database $DBName_Sel will be listed\n";
     }
   }
   else {
     usage ("Parameter $getOpt_optName : Will be ignored");
   }
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
$day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
$Now = "$year.$month.$day $hour:$minute:$second";

if (($infile ne "") && ($instance ne "")) {
  usage ("When filename (-f) is provided option -i should not be entered");
  exit;
}
if ( $infile eq "" ) {
  if (! open (LDBPIPE,"db2 list dcs directory | "))  { die "Can't run db2 list dcs! $!\n"; }
}
else {
  open (LDBPIPE,$infile) || die "Unable to open $infile\n"; 
  print "Input will be read from $infile\n";
}

if ($DBName_Sel eq "") {
  $DBName_Sel = "ALL";
}

$numHeld = -1;

# Print Headings ....
if ( $silent ne "Yes") {
  print "DCS Directory listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($Now) .... \n\n";
  printf "%-8s %-8s %-30s %-40s \n",
         'Local', 'Remote', '', '';
  printf "%-8s %-8s %-30s %-40s \n",
         'DB', 'DB', 'Parameters', 'Comment';
  printf "%-8s %-8s %-30s %-40s \n",
         '--------', '--------', '------------------------------', '----------------------------------------';
}

$numEntries = 0;

while (<LDBPIPE>) {
   #   DCS 1 entry:

   #    Local database name                = DCS2B8EC
   #    Target database name               = MSA1
   #    Application requestor name         =
   #    DCS parameters                     =
   #    Comment                            =
   #    DCS directory release level        = 0x0100

    if ( $_ =~ /SQL1311N/) {
      # no DCS information found ...
      print "No DCS Information found for instance $ENV{'DB2INSTANCE'} on $machine\n";
      last;
    }

    chomp $_;
    @ldbinfo = split(/=/);

    if ( $debugLevel > 0) { print "$_\n"; }
    if ( $debugLevel > 1) { print "$ldbinfo[0] : $ldbinfo[1]\n"; }

    if ( trim($ldbinfo[0]) eq "Target database name") {
      $TDBName = trim($ldbinfo[1]);
      if ( $debugLevel > 0) { print "Target Database: $TDBName\n"; }
    }

    if ( trim($ldbinfo[0]) eq "Local database name") {
      $DBName = trim($ldbinfo[1]);
      $TDBName = "";
      $DCSParms = "";
      $commlit = "";
      $comment = "";
      if ( $debugLevel > 0) { print "Local Database: $DBName\n"; }
    }

    if ( trim($ldbinfo[0]) eq "DCS parameters") {
      $DCSParms = trim($ldbinfo[1]);
      if ( $debugLevel > 0) { print "DCS Parameters: $DCSParms\n"; }
    }

    if ( trim($ldbinfo[0]) eq "Comment") {
      $comment = trim($ldbinfo[1]);
      if ( $debugLevel > 0) { print "Comment: $comment\n"; }
    }

    if ( (trim($ldbinfo[0]) eq "DCS directory release level")) { # end of entry
      
      if ( (uc($DBName_Sel) eq uc($DBName)) || (uc($DBName_Sel) eq "ALL") ||  (uc($DBName_Sel) eq uc($TDBName)) ) {
        $commlit = ""; 
        if ($comment ne "") {
          $commlit = "with \"$comment\"";
        }
        if ($DCSParms ne "") {
          $DCSParmsLit = "parms \"$DCSParms\"";
        }
        if ( $TDBName eq "" ) {
          if ( $silent ne "Yes" ) { 
            # print out the stuff ....
            printf "%-8s %-8s %-30s %40s \n", $DBName,$DBName,$DCSParms,$commlit;  # just use the local name as the target name
          }
          if ( $genDefs eq "Y") {
            $catalogDefs{$TDBName} = "catalog dcs db $DBName $DCSParmsLit $commlit\n";
            $numEntries++;
          }  
        }
        else {
          if ( $silent ne "Yes" ) { 
            # print out the stuff ....
            printf "%-8s %-8s %-30s %40s \n", $TDBName,$DBName,$DCSParms,$commlit;
          }
          if ( $genDefs eq "Y") {
            $catalogDefs{$TDBName} = "catalog dcs db $DBName as $TDBName $DCSParmsLit $commlit\n";
            $numEntries++;
          }
        }
        $DBName = "";
        $TDBName = "";
        $DCSParms = "";
        $commlit = "";
        $comment = "";
      }
    }
}

# Print out definitions if required ....

if (($genDefs eq "Y") && ( $numEntries > 0))  {

  if ( $silent ne "Yes") {
    print "\nGenerated CATALOG DCS DB definitions:\n\n";
  }

  foreach $key (sort by_key keys %catalogDefs ) {
    print "$catalogDefs{$key}";
  }
}

if ( $silent ne "Yes") {
  print "\n";
}

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

