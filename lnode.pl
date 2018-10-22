#!/usr/bin/perl
# --------------------------------------------------------------------
# lnode.pl
#
# $Id: lnode.pl,v 1.8 2018/10/21 21:01:50 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST NODE DIRECTORY command
#
# Usage:
#   lnode.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lnode.pl,v $
# Revision 1.8  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.7  2018/10/18 22:58:52  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.6  2018/10/17 00:51:24  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.5  2014/05/25 22:27:39  db2admin
# correct the allocation of windows include directory
#
# Revision 1.4  2012/11/05 02:10:04  db2admin
# Add in the printing of servers pointed to by entries in the TNSNAMES.ORA
#
# Revision 1.3  2009/01/05 22:34:05  db2admin
# initialise scripts variable to prevent compile errors on windows
#
# Revision 1.2  2008/12/04 22:06:45  m08802
# Standardised parameters and improved node selection
#
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------

my $ID = '$Id: lnode.pl,v 1.8 2018/10/21 21:01:50 db2admin Exp db2admin $';
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
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $myDate_debugLevel $getOpt_diagLevel $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime $datecalc_debugLevel displayMinutes timeDiff timeAdd timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsg [GENDEFS] [-i <instance> | -f <filename>] -n <node to list> [-v[v]]

       Script to format the output of a LIST NODE DIRECTORY command

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -g or GENDEFS   : Generate the CATALOG statements to reproduce the entry
       -n              : only list the indicated node
       -s              : Silent mode (dont produce the report)
       -i              : Instance to query (if not entered then defaults to value of DB2INSTANCE variable)
       -v              : increment the diagnostic level
       -f              : File name to process 

       This program provides a formatted display of the output of the following command:

       db2 list node directory

       As well it will parseany identified TNSNAMES.ORA file and output the Instance details found there
\n";
}

$infile = "";
$genDefs = "N";
$silent = "No";
$instance = "";
$diagLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsgvn:f:i:s|^GENDEFS";

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
   $diagLevel++;
   if ( $silent ne "Yes") {
     print "Diag Level now set to $diagLevel\n";
   }
 }
 elsif (($getOpt_optName eq "n"))  {
   if ( $silent ne "Yes") {
     print "Node $getOpt_optValue will be listed\n";
   }
   $NodeName_Sel = $getOpt_optValue;
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
   elsif ( $NodeName_Sel eq  "" ) {
     $NodeName_Sel = getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Node $getOpt_optValue will be listed\n";
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
$Now = "$year.$month.$dayOfMonth $hour:$minute:$second";

if (($infile ne "") && ($instance ne "")) {
  usage ("When filename (-f) is provided option -i should not be entered");
  exit;
}

if ( $infile eq "" ) {
  if (! open (LDBPIPE,"db2 list node directory | "))  { die "Can't run db2 list node! $!\n"; }
}
else {
  open (LDBPIPE,$infile) || die "Unable to open $infile\n"; 
  print "Input will be read from $infile\n";
}

$numHeld = -1;
$UCNodeName_Sel = uc($NodeName_Sel);

# Print Headings ....
if ( $silent ne "Yes") {
  print "Database listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($Now) .... \n\n";
  printf "%-15s %-8s %-10s %-30s %-10s %-40s \n",
         'Node', 'Type', 'Protocol', 'Host', 'Srvc Name', 'Comment';
  printf "%-15s %-8s %-10s %-30s %-10s %-40s \n",
         '--------', '--------', '----------', '------------------------------', '----------', '----------------------------------------';
}

while (<LDBPIPE>) {
#   Node 29 entry:
#    Node name                      = TCP0025
#    Comment                        =
#    Directory entry type           = LOCAL
#    Protocol                       = TCPIP
#    Hostname                       = epmprod
#    Service name                   = 51000

    chomp $_;
    @lnodeinfo = split(/=/);

    if ( $_ =~ /The node directory cannot be found/ ) {
      print "The node directory cannot be found\n";
      next;
    }

    if ( trim($lnodeinfo[0]) eq "Node name") {
      $NodeName = trim($lnodeinfo[1]);
    }

    if ( trim($lnodeinfo[0]) eq "Directory entry type") {
      $EntryType = trim($lnodeinfo[1]);
    }

    if ( trim($lnodeinfo[0]) eq "Protocol") {
      $Protocol = trim($lnodeinfo[1]);
    }

    if ( trim($lnodeinfo[0]) eq "Hostname") {
      $Host = trim($lnodeinfo[1]);
      $UCHost = uc($Host);
    }

    if ( trim($lnodeinfo[0]) eq "Comment") {
      $Comment = trim($lnodeinfo[1]);
    }

    if ( trim($lnodeinfo[0]) eq "Service name") {
      $Service = trim($lnodeinfo[1]);
      
      if ( (uc($NodeName_Sel) eq uc($NodeName)) || ($NodeName_Sel eq "ALL") || ($UCHost =~ /$UCNodeName_Sel/) ) {
        if ( $silent ne "Yes") {
          printf "%-15s %-8s %-10s %-30s %-10s %-40s \n",
                 $NodeName,$EntryType,$Protocol,$Host,$Service,$Comment;
        }
        if ( $genDefs eq "Y") {
          $commlit = "";
          if ($comment ne "") {
            $commlit = "with \"$comment\"";
          }
          if (uc($Protocol) eq "TCPIP") {
            $catalogDefs{$NodeName} = "catalog $Protocol node $NodeName remote $Host server $Service $commlit\n";
          }
        }
      }
    }
    if ( trim($lnodeinfo[0]) eq "Instance name") {
      $Instance = trim($lnodeinfo[1]);
      
      if ( ($NodeName_Sel eq uc($NodeName)) || ($NodeName_Sel eq "ALL") || ($UCHost =~ /$NodeName_Sel/) ) {
        if ( $silent ne "Yes") {
          printf "%-15s %-8s %-10s %-30s %-10s %-40s \n",
                 $NodeName,$EntryType,$Protocol,"Instance:",$Instance,$Comment;
        }
        if ( $genDefs eq "Y") {
          $commlit = "";
          if ($comment ne "") {
            $commlit = "with \"$comment\"";
          }
          if (uc($Protocol) eq "TCPIP") {
            $catalogDefs{$NodeName} = "catalog $Protocol node $NodeName remote $Host server $Service $commlit\n";
          }
          elsif (uc($Protocol) eq "LOCAL") {
            $catalogDefs{$NodeName} = "catalog $Protocol node $NodeName instance $Instance $commlit\n";
          }
        }
      }
    }
}
oracle ("");

# Print out definitions if required ....

if ($genDefs eq "Y") {

  if ( $silent ne "Yes") {
    print "\nGenerated CATALOG DB definitions:\n\n";
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

sub oracle {
  $connect_to_remote = "No";
  $dirEntryType = "REMOTE";
  $catDBPartNum = "-1";
  $Comment = "";
  $Protocol = "TCPIP";
  $Service = "";


  $inst = 'ORACLE';
  $dbalias = "";
  $tnsnamesDirectory = 'C:\app\oracle\product\11.1.0\client_1\network\admin';

  @tnsArr = ();

  if ( ! open (DBPIPE, "<$tnsnamesDirectory\\TNSNAMES.ORA" ) ) {
    print "No tnsnames.ora file so assuming no Oracle checking to do\n"; 
  }
  else { # the file exists so just loop through looking for databases to try and connect to   
    while (<DBPIPE>) {
      if ( $diagLevel > 0 ) { print $_; }
      @line = split;
      if ( substr($_,0,1) ne " " && $line[1] eq "=" ) { # Found a database to try connecting to 
        $dbalias = uc($line[0]);
        $machine = "";
        $port = "";
        if ( $diagLevel > 0 ) { print "DBALIAS=$dbalias\n"; }
      }
      elsif ( (uc($_) =~ /HOST =/) || (uc($_) =~ /PORT =/) ) { # we can identify the machine it is from or the Port
        # loop through the line and try and find the HOST name
        @bits = split(/\)\(/, $_);
        foreach $bt (@bits) {
          if (uc(substr(trim($bt),0,4)) eq "HOST" ) {
            # host entry
            @host_arr = split("=", $bt);
            $machine = uc(trim($host_arr[1]));
            if ( $diagLevel > 0 ) { print "MACHINE=$machine\n"; }
          }
          elsif (uc(substr(trim($bt),0,4)) eq "PORT" ) {
            # host entry
            @port_arr = split("=", $bt);
            $port = uc(trim($port_arr[1]));
            $port =~ s/\)//g;
            if ( $diagLevel > 0 ) { print "PORT=$port\n"; }
          }
        } 
      }
      if ( ($dbalias ne "" ) && ( $machine ne "" ) && ( $port ne "" ) ) {
        if ( $diagLevel > 0 ) { print ">>>> HERE ,$machine,$dirEntryType,$Protocol,$machine,$port,$Comment\n"; }
        $tnsArr{$machine} = sprintf "%-15s %-8s %-10s %-30s %-10s %-40s \n",$machine,$dirEntryType,$Protocol,$machine,$port,$Comment;    
        $dbalias = "";
        $machine = "";
        $port = "";
      }
    }  
    foreach $key (sort by_key keys %tnsArr ) {
      print "$tnsArr{$key}";
    }
  }
}

