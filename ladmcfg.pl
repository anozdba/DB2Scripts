#!/usr/bin/perl
# --------------------------------------------------------------------
# ladmcfg.pl
#
# $Id: ladmcfg.pl,v 1.9 2019/02/07 04:18:54 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET ADM CFG command
#
# Usage:
#   ladmcfg.pl  [parameter] [gendata [only]]
#                 or                        
#   ladmcfg.pl  [gendata [only]] [parameter]
#
# $Name:  $
#
# ChangeLog:
# $Log: ladmcfg.pl,v $
# Revision 1.9  2019/02/07 04:18:54  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.8  2019/01/25 03:12:40  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.7  2018/10/21 21:01:49  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.6  2018/10/18 22:58:50  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.5  2018/10/17 00:43:45  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.4  2014/05/25 22:24:54  db2admin
# correct the allocation of windows include directory
#
# Revision 1.3  2009/01/22 00:02:55  db2admin
# Correct Windows delete command
#
# Revision 1.2  2009/01/13 05:09:24  db2admin
# Standardise parameter passing
#
# Revision 1.1  2008/10/26 23:21:37  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

my $ID = '$Id: ladmcfg.pl,v 1.9 2019/02/07 04:18:54 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hs [-p <parmname to list] [-o | ONLY]  [-g | GENDATA]

       Script to format the output of a GET ADM CFG command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -p               : parameter to list (default: All)
       -o or ONLY       : Only print out the generated defines (implies -g)
       -g or GENDATA    : Generate define statements to recreate the config

     \n";
}

# Set default values for variables

$silent = "No";
$genData = "No";
$printRep = "Yes";
$PARMName = "All";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsp:og|^ONLY|^GENDATA";

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt($getOpt_opt) ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s") )  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing $getOpt_optValue will be displayed\n";
   }
   $PARMName = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "o") || ($getOpt_optName eq "ONLY") )  {
   if ( $silent ne "Yes") {
     print "Only the created definitions will be output\n";
   }
   $genData = "Yes";
   $printRep = "No";
 }
 elsif (($getOpt_optName eq "g") || ($getOpt_optName eq "GENDATA") )  {
   if ( $silent ne "Yes") {
     print "Update configuration definitions will be generated\n";
   }
   $genData = "Yes";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $PARMName eq "All") {
     if ( $silent ne "Yes") {
       print "Only entries containing $getOpt_optValue will be displayed\n";
     }
     $PARMName = $getOpt_optValue;
   }
   else {
     usage ("Parameter $getOpt_optValue is unknown");
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
$YYYYMMDD = "$year$month$day";

$zeroes = "00";

if (! open(STDCMD, ">getadmcfgcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 get admin cfg\n";

close STDCMD;

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x getadmcfgcmd.bat`;
  $pos = "./";
}

if (! open (GETADMCFGPIPE,"${pos}getadmcfgcmd.bat |"))  {
        die "Can't run getadmcfgcmd.bat! $!\n";
    }

if ( $silent ne "Yes") {
  if ($PARMName eq "All") {
    print "All parameters will be displayed\n";
  }
}

$maxData = 0;
while (<GETADMCFGPIPE>) {
    # print "Processing $_\n";
    # parse the db2 get dbm cfg 

    $input = $_;
    @admcfginfo = split(/=/);
    @wordinfo = split(/\s+/);

    $PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $PRMNAME = $1;
    }

    if ( (uc($admcfginfo[0]) =~ /$PARMName/) || ($PARMName eq "All") ) {
      if ( $genData eq "Yes" ) {
        if ($PRMNAME ne "") {
          $maxData++;
          chomp  $admcfginfo[1];
          $Data[$maxData] = "db2 update admin cfg using $PRMNAME $admcfginfo[1]";
        }
      }

      if ($printRep eq "Yes") {
        print "$_";
      }
     
    }

}

if ($genData eq "Yes") {
  for ( $i = 1; $i <= $maxData; $i++) {
    print "$Data[$i] \n";
  }
}

if ($OS eq "Windows" ) {
 `del getadmcfgcmd.bat`;
}
else {
 `rm getadmcfgcmd.bat`;
}

