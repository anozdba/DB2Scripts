#!/usr/bin/perl
# --------------------------------------------------------------------
# ldbmsnap.pl
#
# $Id: ldbmsnap.pl,v 1.2 2014/05/25 22:26:45 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET SNAPSHOT FOR DATABASE MANAGER command
#
# Usage:
#   ldbmsnap.pl  [parameter]
#
# $Name:  $
#
# ChangeLog:
# $Log: ldbmsnap.pl,v $
# Revision 1.2  2014/05/25 22:26:45  db2admin
# correct the allocation of windows include directory
#
# Revision 1.1  2011/11/15 23:22:54  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

$ID = '$Id: ldbmsnap.pl,v 1.2 2014/05/25 22:26:45 db2admin Exp db2admin $';
@V = split(/ /,$ID);
$Version=$V[2];
$Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs [-p <search parm>] [-V <search string>] [-f <filename> [-x|X]] [-v[v]]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -p               : parameter to list (default: All) [case insensitive]
       -V               : search string anywhere (in either parm, desc or value)
       -f               : Input comparison file
       -x               : only print out differing values from the comparison file
       -X               : only print out differing values from the comparison file (use file values for the commands)
       -v               : set debug level

       This script formats the output of 'db2 get snapshot for database manager'

       NOTE: -x only has an effect if -g is specified
             -X only has an effect if -f and -g are specified
     \n";
}

if ( $^O eq "MSWin32") {
  $machine = `hostname`;
  $OS = "Windows";
  BEGIN {
    $scriptDir = 'c:\udbdba\scripts';
    $tmp = rindex($0,"\\");
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}
else {
  $machine = `uname -n`;
  $machine_info = `uname -a`;
  @mach_info = split(/\s+/,$machine_info);
  $OS = $mach_info[0] . " " . $mach_info[2];
  BEGIN {
    $scriptDir = "/udbdba/scripts";
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}

require "commonFunctions.pl";

# Set default values for variables

$silent = "No";
$printRep = "Yes";
$PARMName = "All";
$compFile = "";
$debugLevel = 0;
$onlyDiff = "No";
$useFile = "No";
$search = "All";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsf:vxXV:p:";

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
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing $getOpt_optValue will be displayed\n";
   }
   $PARMName = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "V"))  {
   if ( $silent ne "Yes") {
     print "Entries containing $getOpt_optValue anywhere will be displayed\n";
   }
   $search = uc($getOpt_optValue);
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

if ($silent ne "Yes") {
  if ($PARMName eq "All") {
    print "All parameters will be displayed for database $database\n";
  }
}

if ( $compFile ne "" ) {
  ##################################################################
  #   THIS CODE NOT REALLY WRITTEN _ SAME AS LDBMCFG.PL            #
  ##################################################################
  # load up comparison file
  if (! open(COMPF, "<$compFile") ) { die "Unable to open $compFile for input \n $!\n"; }
  while (<COMPF>) {

    if ( $debugLevel > 0 ) { print ">> $_";}

    if ( $_ =~ /Database Manager Configuration/ ) { 
      die "File $compFile is a Database Manager Configuration file.\nA Database Configuration file is required\n\n";
    }

    $COMPF_input = $_;
    @COMPF_dbcfginfo = split(/=/);
    @COMPF_wordinfo = split(/\s+/);

    $COMPF_PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $COMPF_PRMNAME = $1;
      $validPARM{$COMPF_PRMNAME} = 1;
    }
    if ( ($COMPF_PRMNAME eq "") && ( defined($COMPF_dbcfginfo[0])) ) {
      $COMPF_PRMNAME = trim($COMPF_dbcfginfo[0]);
    }
    
    if ( $debugLevel > 0 ) { print "COMPF ParmName is $COMPF_PRMNAME\n"; }

    if ($COMPF_PRMNAME ne "") {
      chomp  $COMPF_dbcfginfo[1];
      if ( $COMPF_dbcfginfo[1] =~ /AUTOMATIC\(/ ) { # dont keep the current value
        if ( $debugLevel > 0 ) { print "COMPF_dbcfginfo[1] set to AUTOMATIC\n"; }
        $COMPF_dbcfginfo[1] = "AUTOMATIC";
      }
      $compDBCFG{$COMPF_PRMNAME} = $COMPF_dbcfginfo[1];
      if ( $debugLevel > 0 ) { print "Parameter $COMPF_PRMNAME has been loaded with parm $COMPF_dbcfginfo[1]\n"; }
    }
  }
  close COMPF;
}

if (! open(STDCMD, ">getdbcfgcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 get snapshot for database manager\n";

close STDCMD;

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x getdbcfgcmd.bat`;
  $pos = "./";
}

if (! open (GETDBCMDPIPE,"${pos}getdbcfgcmd.bat |"))  {
        die "Can't run getdbcfgcmd.bat! $!\n";
    }

$maxData = 0;
while (<GETDBCMDPIPE>) {
    # parse the db2 get db cfg output

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    $input = $_;
    chomp $_;
    @dbcfginfo = split(/=/);
    @wordinfo = split(/\s+/);

    $PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $PRMNAME = $1;
    }
    if ( ($PRMNAME eq "") && ( defined($dbcfginfo[0])) ) {
      $PRMNAME = trim($dbcfginfo[0]);
    }

    if ( $debugLevel > 0 ) { print "Parm Name $PRMNAME is being processed\n"; }

    $compValue = "";
    if ( defined ( $compDBCFG{$PRMNAME} ) ) { # if the entry exists in the comparison file
      if ( $debugLevel > 1 ) { print "Comparison value exists and is $compDBCFG{$PRMNAME}\n"; }
      $compValue = $compDBCFG{$PRMNAME};
    }
    if ( $debugLevel > 1 ) { print "Lookup for parameter '$PRMNAME' has finished\n"; }

    if ( $input =~ /Database Configuration for Database/ ) {
      $DBName = $wordinfo[5];
      if ( $DBName ne "" ) {
        if ($printRep eq "Yes") {
          print ">>>>>> Processing for database $DBName\n";
        }
      }
    }

    $display = "Yes";
    if ( ($PARMName ne "All") && ( uc($dbcfginfo[0]) !~ /$PARMName/ ) ) { # search parm not found
      $display = "No";
    }
    elsif ( ($search ne "All") && ( uc($input) !~ /$search/ ) ) {     # search parm not found
      $display = "No";
    }

    if ( $display eq "Yes" ) {

      if ( $debugLevel > 1 ) { print "Parm Name $PRMNAME has been selected for processing\n"; }

      chomp  $dbcfginfo[1];
      $prmval = $dbcfginfo[1];
      if ( $dbcfginfo[1] =~ /AUTOMATIC\(/ ) {
        if ( $debugLevel > 1 ) { print "AUTO Check : $dbcfginfo[1] contains AUTO\n"; }
        $prmval = "AUTOMATIC";
      }
      if ( $debugLevel > 1 ) { print "$dbcfginfo[1] \>\> $prmval\n"; }

      if ( $debugLevel > 1 ) { print "Parm Name $dbcfginfo[0] has a value of $prmval\n"; }

      # Generate the report if it is required

      if ( $printRep eq "Yes" ) {
        if ( $PRMNAME ne "" ) {
          if ( $compFile ne "" ) {
            if ( $compValue ne  $prmval ) {
              print "$_  << File Value = $compDBCFG{$PRMNAME}\n";
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

if ($OS eq "Windows" ) {
 `del getdbcfgcmd.bat`;
}
else {
 `rm getdbcfgcmd.bat`;
}
