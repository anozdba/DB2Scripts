#!/usr/bin/perl
# --------------------------------------------------------------------
# ldb.pl
#
#
# $Id: ldb.pl,v 1.11 2016/04/15 05:46:52 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST DB DIRECTORY command
#
# Usage:
#   ldb.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ldb.pl,v $
# Revision 1.11  2016/04/15 05:46:52  db2admin
# 1. Convert to use commonFunctions.pm
# 2. Correct minor bugs (after implementing "use strict"
#
# Revision 1.10  2014/05/25 22:26:00  db2admin
# correct the allocation of windows include directory
#
# Revision 1.9  2012/11/05 02:09:24  db2admin
# Add in a print of Oracle entries
#
# Revision 1.8  2012/02/02 03:59:59  db2admin
# test
#
# Revision 1.7  2010/01/11 00:59:53  db2admin
# make sure that the remote databases are referred to by their Alias name
#
# Revision 1.6  2009/10/14 22:12:02  db2admin
# Correct parse error
#
# Revision 1.5  2009/10/14 22:10:34  db2admin
# Enhance the help information
#
# Revision 1.4  2009/01/02 03:31:46  db2admin
# correct processing of ALL db parameter
#
# Revision 1.3  2008/12/10 04:23:00  db2admin
# adjust default value for script directory to prevent a windows failure
#
# Revision 1.2  2008/12/04 20:54:24  m08802
# standardised parameters and cleaned up code a bit
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: ldb.pl,v 1.11 2016/04/15 05:46:52 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsg [GENDEFS] [-i <instance> | -f <filename>] -d <database>

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -g or GENDEFS   : Generate the CATALOG statements to reproduce the entry
       -s              : Silent mode (dont produce the report)
       -d              : Database to list (if not entered defaults to ALL
       -i              : Instance to query (if not entered then defaults to value of DB2INSTANCE variable)
       -f              : File name to process 

      NOTE: This script formats the output of a 'list db directory' command
";
}

my $machine;            # machine name
my $machine_info;       # ** UNIX ONLY ** uname
my @mach_info;          # ** UNIX ONLY ** uname split by spaces
my $OS;                 # OS
my $scriptDir;          # directory where the script is running
my $tmp;

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scrxipts';
    $tmp = rindex($0,'\\');
    if ($tmp -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    $tmp = rindex($0,'/');
    if ($tmp -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
}

use lib "$scriptDir";

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $myDate_debugLevel);

my $infile = "";
my $DBName_Sel = "";
my $genDefs = "N";
my $silent = "No";
my $instance = "";
my $debugLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt(":?hsgvf:d:i:s|^GENDEFS") ) {
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
     print "Debug Level now set to $debugLevel\n";
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
   $instance = $getOpt_optValue;
   $ENV{'DB2INSTANCE'} = $getOpt_optValue;
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $instance eq "" ) {
     $instance = $getOpt_optValue;
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
my $date = "$year$month$day";

if (($infile ne "") && ($instance ne "")) {
  usage ("When filename (-f) is provided option -i should not be entered");
  exit;
}
if ( $infile eq "" ) {
  if (! open (LDBPIPE,"db2 list db directory | "))  { die "Can't run db2 list db! $!\n"; }
}
else {
  open (LDBPIPE,$infile) || die "Unable to open $infile\n"; 
  print "Input will be read from $infile\n";
}

if ($DBName_Sel eq "") {
  $DBName_Sel = "ALL";
}

my $numHeld = -1;

# Print Headings ....
if ( $silent ne "Yes") {
  print "Database listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($NowTS) .... \n\n";
  printf "%-8s %-8s %-10s %4s %-20s %-40s \n",
         'Alias', 'Database', 'Type', 'Part', 'Comment', 'Directory/Node(Authentication)';
  printf "%-8s %-8s %-10s %4s %-20s %-40s \n",
         '--------', '--------', '----------', '----', '--------------------', '----------------------------------------';
}

my $DBName = '';
my $NodeName = "";
my $Authentication = "";
my $commlit = "";
my $DBAlias = '';
my $localDir = '';
my $Authentication = '';
my $Comment = '';
my $dirEntryType = '';
my $catDBPartNum = '';
my %hold = ();
my %catalogDefs = ();

while (<LDBPIPE>) {
   #   Database 1 entry:

   #    Database alias                       = GM2STTST
   #    Database name                        = GM2STTST
   #    Local database directory             = /db2/gm2sttst
   #    Database release level               = a.00
   #    Comment                              =
   #    Directory entry type                 = Indirect
   #    Catalog database partition number    = 0
   #    Alternate server hostname            =
   #    Alternate server port number         =


   chomp $_;
    my @ldbinfo = split(/=/);

    if ( $debugLevel > 0 ) {    print "$ldbinfo[0] : $ldbinfo[1]\n"; }

    if ( trim($ldbinfo[0]) eq "Database alias") {
      $DBName = "";
      $NodeName = "";
      $Authentication = "";
      $commlit = "";
      $DBAlias = trim($ldbinfo[1]);
    }

    if ( trim($ldbinfo[0]) eq "Database name") {
      $DBName = trim($ldbinfo[1]);
    }

    if ( trim($ldbinfo[0]) eq "Node name") {
      $NodeName = trim($ldbinfo[1]);
    }

    if ( (trim($ldbinfo[0]) eq "Local database directory") || (trim($ldbinfo[0]) eq "Database drive") ) {
      $localDir = trim($ldbinfo[1]);
    }

    if ( trim($ldbinfo[0]) eq "Authentication") {
      $Authentication = trim($ldbinfo[1]);
    }

    if ( trim($ldbinfo[0]) eq "Comment") {
      $Comment = trim($ldbinfo[1]);
    }

    if ( trim($ldbinfo[0]) eq "Directory entry type") {
      $dirEntryType = trim($ldbinfo[1]);
    }

    if ( (trim($ldbinfo[0]) eq "Catalog database partition number") || (trim($ldbinfo[0]) eq "Catalog node number") ) {
      $catDBPartNum = trim($ldbinfo[1]);
      if ( $dirEntryType eq "Remote") {
        if ( $Authentication eq "" ) {
          $localDir = "$NodeName";
        }
        else {
          $localDir = "$NodeName ($Authentication)";
        }
      }
      if ( $debugLevel > 0 ) { print "catDBPartNum=$catDBPartNum   >>> $DBName_Sel\n"; }
      
      if ( (uc($DBName_Sel) eq uc($DBName)) || (uc($DBName_Sel) eq "ALL") ||  (uc($DBName_Sel) eq uc($DBAlias)) ) {
        $commlit = ""; 
        if ($Comment ne "") {
          $commlit = "with \"$Comment\"";
        }
        if ( $dirEntryType eq "Indirect") {
          if ( $silent ne "Yes") {
            printf "%-8s %-8s %-10s %4s %-20s %-40s\n",
                 $DBAlias,$DBName,$dirEntryType,$catDBPartNum,$Comment,$localDir;
          }
          if ( $genDefs eq "Y") {
            $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias on $localDir $commlit\n";
          }
        }
        else {
          # not a local database so save and print later ....
          $hold{$DBAlias} = sprintf "%-8s %-8s %-10s %4s %-20s %-40s\n",
               $DBAlias,$DBName,$dirEntryType,$catDBPartNum,$Comment,$localDir;
          if ( $genDefs eq "Y") {
            if ( $Authentication eq "" ) {
              $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias at node $NodeName $commlit\n";
            }
            else { 
              $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias at node $NodeName authentication $Authentication $commlit\n";
            }
          }
          $DBName = "";
          $DBAlias = "";
          $NodeName = "";
          $Authentication = "";
          $commlit = "";
        }
      }
    }
}

# Print out the remote databases at the end ....
# Print any Oracle entries first

oracle ("");


if ( $silent ne "Yes") {
  foreach my $key (sort by_key keys %hold ) {
    print "$hold{$key}";
  }
}

# Print out definitions if required ....

if ($genDefs eq "Y") {

  if ( $silent ne "Yes") {
    print "\nGenerated CATALOG DB definitions:\n\n";
  }

  foreach my $key (sort by_key keys %catalogDefs ) {
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

sub oracle {
my $connect_to_remote = "No";
my $dirEntryType = "Remote";
my $catDBPartNum = "-1";
my $Comment = "";


my $inst = 'ORACLE';
my $dbalias = "";
my $tnsnamesDirectory = 'C:\app\oracle\product\11.1.0\client_1\network\admin';


if ( ! open (DBPIPE, "<$tnsnamesDirectory\\TNSNAMES.ORA" ) ) {
  print "No tnsnames.ora file so assuming no Oracle checking to do\n"; 
}
else { # the file exists so just loop through looking for databases to try and connect to   
  while (<DBPIPE>) {
    my @line = split;
    if ( substr($_,0,1) ne " " && $line[1] eq "=" ) { # Found a database to try connecting to 
      $dbalias = uc($line[0]);
    }
    elsif ( $_ =~ /HOST =/ ) { # we can identify the machine it is from 
      # loop through the line and try and find the HOST name
      my @bits = split(/\)\(/, $_);
      foreach my $bt (@bits) {
        if (substr(trim($bt),0,4) eq "HOST" ) {
          # host entry
          my @host = split("=", $bt);
          $machine = uc(trim($host[1]));
        }
      } 
       printf "%-8s %-8s %-10s %4s %-20s %-40s\n",
       $dbalias,$dbalias,$dirEntryType,$catDBPartNum,$Comment,$machine;

      $dbalias = "";
    }
  }
  if ( $dbalias ne "") { # Means that no HOST record was found 
    $machine = "UNKNOWN";
    print "$dbalias";
    $dbalias = "";
  }
}
}
