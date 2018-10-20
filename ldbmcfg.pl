#!/usr/bin/perl
# --------------------------------------------------------------------
# ldbmcfg.pl
#
# $Id: ldbmcfg.pl,v 1.13 2018/10/18 22:58:51 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET DBM CFG command
#
# Usage:
#   ldbmcfg.pl  [parameter] [gendata [only]]
#                 or                        
#   ldbmcfg.pl  [gendata [only]] [parameter]
#
# $Name:  $
#
# ChangeLog:
# $Log: ldbmcfg.pl,v $
# Revision 1.13  2018/10/18 22:58:51  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.12  2018/10/17 20:37:44  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.11  2014/05/25 22:26:33  db2admin
# correct the allocation of windows include directory
#
# Revision 1.10  2013/02/22 00:03:44  db2admin
# Add in header to display
#
# Revision 1.9  2009/12/16 01:22:01  db2admin
# limit generated commands only to lines including an equals sign
#
# Revision 1.7  2009/11/11 02:02:52  db2admin
# ALter program to optionally only print out different configs
#
# Revision 1.5  2009/04/17 04:38:02  db2admin
# make the entered parm case insensitive
#
# Revision 1.4  2009/01/22 00:03:10  db2admin
# Correct Windows delete command
#
# Revision 1.3  2009/01/13 05:21:55  db2admin
# Standard parameters
#
# Revision 1.2  2009/01/13 05:09:24  db2admin
# Standardise parameter passing
#
# Revision 1.1  2008/10/26 23:21:37  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

my $ID = '$Id: ldbmcfg.pl,v 1.13 2018/10/18 22:58:51 db2admin Exp db2admin $';
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
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs [-p <parmname to list] [-o | ONLY]  [-g | GENDATA] [-f <filename> [-x|X]] [-v[v]]

       Script to format the output of a GET DBM CFG command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -p               : parameter To list (default: All) [case insensitive]
       -o or ONLY       : Only print out the generated defines (implies -g)
       -g or GENDATA    : Generate define statements to recreate the config
       -f               : Input comparison file
       -x               : only print out differing values from the comparison file
       -X               : only print out differing values from the comparison file (use file values for the commands)
       -v               : set debug level

       NOTE: -x only has an effect if -g is specified
             -X only has an effect if -f and -g are specified

     \n";
}

$DB2INSTANCE = $ENV{'DB2INSTANCE'};

# Set default values for variables

$silent = "No";
$genData = "No";
$printRep = "Yes";
$PARMName = "All";
$compFile = "";
$debugLevel = 0;
$onlyDiff = "No";
$useFile = "No";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsxXvp:ogf:|^ONLY|^GENDATA";

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
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "x"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing different comparison values will be displayed\n";
   }
   $onlyDiff = "Yes";
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing $getOpt_optValue will be displayed\n";
   }
   $PARMName = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print "The update commands will use the values from the file\n";
   }
   $useFile = "Yes";
   $onlyDiff = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "Comparison file will be $getOpt_optValue\n";
   }
   $compFile = $getOpt_optValue;
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
     $PARMName = uc($getOpt_optValue);
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

print "Processing instance $DB2INSTANCE on server $machine ($NowTS)\n\n";

if ( $compFile ne "" ) {
  # load up comparison file
  if (! open(COMPF, "<$compFile") ) { die "Unable to open $compFile for input \n $!\n"; }
  while (<COMPF>) {

    if ( $debugLevel > 0 ) { print ">> $_";}

    if ( $_ =~ /Database Configuration/ ) {
      die "File $compFile is a Database Configuration file.\nA Database Manager Configuration file is required\n\n";
    }
 
    $COMPF_input = $_;
    @COMPF_dbmcfginfo = split(/=/);
    @COMPF_wordinfo = split(/\s+/);

    $COMPF_PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $COMPF_PRMNAME = $1;
      $validPARM{$COMPF_PRMNAME} = 1;
    }
    if ( ($COMPF_PRMNAME eq "") && ( defined($COMPF_dbmcfginfo[0])) ) {
      $COMPF_PRMNAME = $COMPF_dbmcfginfo[0];
    }
    if ( $debugLevel > 0 ) { print "COMPF ParmName is $COMPF_PRMNAME\n"; }

    if ($COMPF_PRMNAME ne "") {
      chomp  $COMPF_dbmcfginfo[1];
      if ( $COMPF_dbmcfginfo[1] =~ /AUTOMATIC\(/ ) { # dont keep the current value
        if ( $debugLevel > 0 ) { print "COMPF_dbmcfginfo[1] set to AUTOMATIC\n"; }
        $COMPF_dbmcfginfo[1] = "AUTOMATIC";
      }
      $compDBMCFG{$COMPF_PRMNAME} = $COMPF_dbmcfginfo[1];
      if ( $debugLevel > 0 ) { print "Parameter $COMPF_PRMNAME has been loaded with parm $COMPF_dbmcfginfo[1]\n"; }
    }
  }
  close COMPF;
}

if (! open(STDCMD, ">getdbmcfgcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 get dbm cfg\n";

close STDCMD;

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x getdbmcfgcmd.bat`;
  $pos = "./";
}

if (! open (GETADMCFGPIPE,"${pos}getdbmcfgcmd.bat |"))  {
        die "Can't run getdbmcfgcmd.bat! $!\n";
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
    chomp $_;
    @dbmcfginfo = split(/=/);
    @wordinfo = split(/\s+/);

    $PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $PRMNAME = $1;
    }

    if ( ($PRMNAME eq "") && ( defined($dbmcfginfo[0])) ) {
      $PRMNAME = $dbmcfginfo[0];
    }

    if ( $debugLevel > 0 ) { print "Parm Name $PRMNAME is being processed\n"; }

    $compValue = "";
    if ( defined ( $compDBMCFG{$PRMNAME} ) ) { # if the entry exists in the comparison file
      if ( $debugLevel > 1 ) { print "Comparison value exists\n"; }
      $compValue = $compDBMCFG{$PRMNAME};
    }

    if ( (uc($dbmcfginfo[0]) =~ /$PARMName/) || ($PARMName eq "All") ) {
      if ( $debugLevel > 1 ) { print "Parm Name $PRMNAME has been selected for processing\n"; }
    
      $compValue = "";
      if ( $compFile ne "" ) { # a comparison file has been provided
        if ( defined ( $compDBMCFG{$PRMNAME} ) ) { # if the entry exists in the comparison file
          if ( $debugLevel > 1 ) { print "Comparison value exists\n"; }
          $compValue = $compDBMCFG{$PRMNAME};
        }
      }

      chomp  $dbmcfginfo[1];
      $prmval = $dbmcfginfo[1];
      if ( $dbmcfginfo[1] =~ /AUTOMATIC\(/ ) { 
        if ( $debugLevel > 1 ) { print "AUTO Check : $dbmcfginfo[1] contains AUTO\n"; }
        $prmval = "AUTOMATIC";
      }
      if ( $debugLevel > 1 ) { print "$dbmcfginfo[1] \>\> $prmval\n"; }
      
      if ( $debugLevel > 1 ) { print "Parm Name $dbmcfginfo[0] has a value of $prmval\n"; }

      if ( $genData eq "Yes" ) { # generating data
        if ($PRMNAME ne "") {
          if ( $onlyDiff eq "Yes" ) {
            if ( defined($validPARM{$PRMNAME}) ) {
              if ( $compValue ne  $prmval ) {
                $maxData++;
                if ( $useFile eq "Yes" ) {
                  $Data[$maxData] = "db2 update dbm cfg using $PRMNAME $compValue";
                }
                else {
                  $Data[$maxData] = "db2 update dbm cfg using $PRMNAME $prmval";
                } 
              }
            }
          }
          else { # print it even if the values are the same
            if ( $_ =~ /=/ ) {
              $maxData++;
              $Data[$maxData] = "db2 update dbm cfg using $PRMNAME $prmval";
            }
          }
        }
      }

      if ($printRep eq "Yes") {
        if ( $PRMNAME ne "" ) {
          if ( $compFile ne "" ) {
            if ( $compValue ne  $prmval ) {
              print "$_  << File Value = $compDBMCFG{$PRMNAME}\n";
            }
            else {
              print "$_ \n";
            }
          }
          else {
            print "$_ \n";
          }
        }
        else {
          print "$_ \n";
        }
      }
    }
}

if ($genData eq "Yes") {
  for ( $i = 1; $i <= $maxData; $i++) {
    print "$Data[$i] \n";
  }
}

if ($OS eq "Windows" ) {
 `del getdbmcfgcmd.bat`;
}
else {
 `rm getdbmcfgcmd.bat`;
}

