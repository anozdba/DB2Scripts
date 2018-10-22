#!/usr/bin/perl
# --------------------------------------------------------------------
# ldefs.pl
#
# $Id: ldefs.pl,v 1.7 2018/10/21 21:01:50 db2admin Exp db2admin $
#
# Description:
# Script to list out the definitions of supplied entries
#
# Usage:
#   ldefs.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ldefs.pl,v $
# Revision 1.7  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.6  2018/10/18 22:58:51  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.5  2018/10/17 01:11:55  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.4  2018/10/15 22:56:53  db2admin
# correct text in help
#
# Revision 1.3  2014/05/25 22:27:10  db2admin
# correct the allocation of windows include directory
#
# Revision 1.2  2009/06/09 04:01:55  db2admin
# correct but with database name comparison
#
# Revision 1.1  2009/06/09 03:10:03  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

my $ID = '$Id: ldefs.pl,v 1.7 2018/10/21 21:01:50 db2admin Exp db2admin $';
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

  print "Usage: $0 -?hs [-i <instance>] [-d <database>]

       Script to list out the definitions of supplied entries

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to list (if not entered defaults to ALL)
       -i              : Instance to query (if not entered then defaults to value of DB2INSTANCE variable)
       \n";
}

$infile = "";
$DBName_Sel = "";
$genDefs = "Y";
$silent = "No";
$instance = "";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsd:i:s";

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

if (! open (LDBPIPE,"db2 list db directory | "))  { die "Can't run db2 list db! $!\n"; }

if ($DBName_Sel eq "") {
  $DBName_Sel = "ALL";
}

$numHeld = -1;

# Print Headings ....
if ( $silent ne "Yes") {
  print "Database listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($Now) .... \n\n";
  printf "%-8s %-8s %-10s %4s %-20s %-40s \n",
         'Alias', 'Database', 'Type', 'Comment', 'Directory/Node(Authentication)';
  printf "%-8s %-8s %-10s %-20s %-40s \n",
         '--------', '--------', '----------', '--------------------', '----------------------------------------';
}

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
    @ldbinfo = split(/=/);

#   print "$ldbinfo[0] : $ldbinfo[1]\n";

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
#      print "catDBPartNum=$catDBPartNum   >>> $DBName_Sel\n";
      
      if ( (uc($DBName_Sel) eq uc($DBName)) || (uc($DBName_Sel) eq "ALL") ||  (uc($DBName_Sel) eq uc($DBAlias)) ) {
        $commlit = ""; 
        if ($comment ne "") {
          $commlit = "with \"$comment\"";
        }
        if ( $dirEntryType eq "Indirect") {
          if ( $silent ne "Yes") {
            printf "%-8s %-8s %-10s %-20s %-40s\n",
                 $DBAlias,$DBName,$dirEntryType,$Comment,$localDir;
          }
          if ( $genDefs eq "Y") {
            $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias on $localDir $commlit\n";
          }
        }
        else {
          # not a local database so save and print later ....
          $hold{$DBName} = sprintf "%-8s %-8s %-10s %-20s %-40s",
               $DBAlias,$DBName,$dirEntryType,$Comment,$localDir;
          if ( $genDefs eq "Y") {
            $node_hostname = "";
            $node_nodename = "";
            $node_comment = "";
            $node_DirEntryType = "";
            $node_serviceName = "";
            $node_Instance = "";
            $node_protocol = "";
            if (! open (LNODEPIPE,"db2 list node directory | "))  { die "Can't run db2 list db! $!\n"; }
            while (<LNODEPIPE>) {
              chomp $_;
              @lnodeinfo = split(/=/);
              if ( $_ =~ /Node name/ ) {
                $node_nodename = trim($lnodeinfo[1]);
                $correctNode = "No";
                if ( $node_nodename eq $NodeName ) {
                  $correctNode = "Yes";
                }
              }
              if ( $_ =~ /Comment/ ) {
                $node_comment = trim($lnodeinfo[1]);
                if ($node_comment ne "") {
                  $node_commlit = "with \"$node_comment\"";
                }
              }
              elsif ( $_ =~ /Directory entry type/ ) {
                $node_DirEntryType = trim($lnodeinfo[1]);
              }
              elsif ( $_ =~ /Protocol/ ) {
                $node_protocol =  trim($lnodeinfo[1]);
              }
              elsif ( $_ =~ /Hostname/ ) {
                $node_hostname =  trim($lnodeinfo[1]);
              }
              elsif ( $_ =~ /Instance/ ) {
                $node_Instance =  trim($lnodeinfo[1]);
              }
              elsif ( $_ =~ /Service name/ ) {
                $node_serviceName =  trim($lnodeinfo[1]);
                if ( $correctNode eq "Yes" ) {
                  $hold{$DBName} = trim($hold{$DBName}) . "  Node $node_nodename : remote server = $node_hostname, port = $node_serviceName, protocol = $node_protocol";
                  if (uc($node_protocol) eq "TCPIP") {
                    $catalogNodeDefs{$node_nodename} = "catalog $node_protocol node $node_nodename remote $node_hostname server $node_serviceName $node_commlit\n";
                  }
                  elsif (uc($node_protocol) eq "LOCAL") {
                    $catalogNodeDefs{$node_nodename} = "catalog $node_protocol node $node_nodename instance $node_Instance $node_commlit\n";
                  }
                }  
              }
            }

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

if ( $silent ne "Yes") {
  foreach $key (sort by_key keys %hold ) {
    print "$hold{$key}\n";
  }
}

# Print out definitions if required ....

if ($genDefs eq "Y") {

  if ( $silent ne "Yes") {
    print "\nGenerated CATALOG DB definitions:\n\n";
  }

  foreach $key (sort by_key keys %catalogNodeDefs ) {
    print "$catalogNodeDefs{$key}";
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

