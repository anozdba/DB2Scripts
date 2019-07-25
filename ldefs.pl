#!/usr/bin/perl
# --------------------------------------------------------------------
# ldefs.pl
#
# $Id: ldefs.pl,v 1.14 2019/04/16 21:17:51 db2admin Exp db2admin $
#
# Description:
# Script to provide database catalog defintions
#
# Usage:
#   ldefs.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ldefs.pl,v $
# Revision 1.14  2019/04/16 21:17:51  db2admin
# reorder the ingestData parms
#
# Revision 1.13  2019/04/09 05:08:54  db2admin
# corerct formatting of output
#
# Revision 1.12  2019/03/28 23:28:40  db2admin
# add in time/machine/instance details to listing
#
# Revision 1.11  2019/03/28 05:28:40  db2admin
# adjust catalog defs for indirect database def
#
# Revision 1.10  2019/03/28 05:14:11  db2admin
# complete rewrite of the script using ingestData
#
#
# --------------------------------------------------------------------"

use strict; 

my $ID = '$Id: ldefs.pl,v 1.14 2019/04/16 21:17:51 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

# Global Variables for standard routines

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
chomp $machine;

# included modules

use lib "$scriptDir";
use commonFunctions qw(displayDebug ingestData trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel  $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

# Global variables for this script

my $currentRoutine = 'main';
my $silent = 0;
my $debugLevel = 0;
my $printDetail = 1;
my $exclude = 0;
my $db_inFile = "";
my $node_inFile = "";
my $DBName_Sel = '';
my $NodeName_Sel = '';
my $generateDefs = 0;
my $cmdPref = '';
my $cmdSuff = '';
my %generateNode = ();
my %generateDB = ();
my $displayNodes = 1;
my $displayDBs = 1;

###############################################################################
# Subroutines and functions ......                                            #

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs [-d <Database>] [-v[v]] [-p] [-x] [-g|-G] [-f] [-F] [-D | -N]
                        [-f <file containing database defs>] [-F <file containing node defs>] 

       Generate catalog definitions for databases and nodes

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -D              : dont show nodes
       -N              : dont show databases
       -f              : file to read database info from (or STDIN)
       -F              : file to read node info from (or STDIN)
       -n              : only list nodes that contain this string
       -s              : Silent mode (dont produce the report)
       -d              : database (actually includes databases/nodes/aliases that include this string)
       -S              : suppress detailed report
       -g              : generate the definitions
       -G              : generate the definitions and wrap the commands in db2 \" \"
       -x              : exclude databases/nodes/aliases that include this string
       -v              : debug level

       Note: This script formats the output of a 'db2 list db directory' and 'db2 list node directory show detail' commands
             -D and -N can not both specify STDIN
       \n ";
} # end of usage

sub processParameters {

  # ----------------------------------------------------
  # -- Start of Parameter Section
  # ----------------------------------------------------

  while ( getOpt(":?hxgGsSNDF:n:f:d:v") ) {
    if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
      usage ("");
      exit;
    }
    elsif (($getOpt_optName eq "s"))  {
      $silent = "Yes";
    }
    elsif (($getOpt_optName eq "f"))  {
      if ( ! $silent ) {
        print "Database definitions will be read from file $getOpt_optValue (File should have been generated using 'db2 list db directory')\n";
      }
      $db_inFile = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "F"))  {
      if ( ! $silent ) {
        print "Node definitions will be read from file $getOpt_optValue (File should have been generated using 'db2 list node directory show detail')\n";
      }
      $node_inFile = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "n"))  {
      if ( ! $silent ) {
        print "Defs for nodes containing $getOpt_optValue will be listed\n";
      }
      $NodeName_Sel = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "d"))  {
      if ( ! $silent ) {
        print "Defs for databases containing $getOpt_optValue will be listed\n";
      }
      $DBName_Sel = $getOpt_optValue;
    }
    elsif (($getOpt_optName eq "S"))  {
      $printDetail = 0;
      if ( ! $silent ) {
        print "Detailed report will be supressed\n";
      }
    }
    elsif (($getOpt_optName eq "g"))  {
      $generateDefs = 1;
      if ( ! $silent ) {
        print "Defs will be generated\n";
      }
    }
    elsif (($getOpt_optName eq "N"))  {
      $displayDBs = 0 ;
      if ( ! $silent ) {
        print "Databases will not be displayed\n";
      }
    }
    elsif (($getOpt_optName eq "D"))  {
      $displayNodes = 0 ;
      if ( ! $silent ) {
        print "Nodes will not be displayed\n";
      }
    }
    elsif (($getOpt_optName eq "G"))  {
      $generateDefs = 1;
      $cmdPref = 'db2 "';
      $cmdSuff = '"';
      if ( ! $silent ) {
        print "Defs will be generated and embedded in a db2 command\n";
      }
    }
    elsif (($getOpt_optName eq "x"))  {
      $exclude = 1;
      if ( ! $silent ) {
        print "blah blah blah will be excluded\n";
      }
    }
    elsif (($getOpt_optName eq "v"))  {
      $debugLevel++;
      if ( ! $silent ) {
        print "debug level set to $debugLevel\n";
      }
    }
    elsif ( $getOpt_optName eq ":" ) {
      usage ("Parameter $getOpt_optValue requires a parameter");
      exit;
    }
    else { # handle other entered values ....
      if ( $DBName_Sel eq "" ) {
        $DBName_Sel = $getOpt_optValue;
        if ( ! $silent ) {
          print "Locks on database $DBName_Sel will be listed\n";
        }
      }
      else {
        usage ("Parameter $getOpt_optValue : is invalid");
        exit;
      }
    }
  }
} # end of processparameters

# End of Subroutines and functions ......                                     #
###############################################################################

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

if ( (uc($node_inFile) eq 'STDIN') and ( uc($db_inFile) eq 'STDIN') ) { # this isn't allowed
  usage ("Only one input file can be from STDIN");
  exit;
}

# set variables based on parameters
processParameters();

# set debug level in commonFunctions module
$cF_debugLevel = $debugLevel;

# organise where the input is coming from

my $inputpipe;
if ( $db_inFile ne "" ) {
  displayDebug("DB Directory list will be read from $db_inFile",1,$currentRoutine);
  if ( $db_inFile eq 'STDIN' ) {
    if (! open ($inputpipe,"-"))  { die "Can't open STDIN for input $!\n"; }
  }
  else {
    if (! open ($inputpipe,"<","$db_inFile"))  { die "Can't open $db_inFile for input$!\n"; }
  }
}
else {
  displayDebug("Issuing: db2 list db directory ",1,$currentRoutine);
  if (! open ($inputpipe,"db2 list db directory |"))  { 
    die "Can't run db2 list db directory! $!\n";
  }
}

# entries to be gathered form the 'list db directory' and the 'list node directory' commands

# ----------------------------------------------------------------------------------
# Database 98 entry:
# 
#  Database alias                       = ESBSMP01
#  Database name                        = ESBSMP01
#  Node name                            = ESB2I1P
#  Database release level               = 10.00
#  Comment                              =
#  Directory entry type                 = Remote
#  Catalog database partition number    = -1
#  Alternate server hostname            = esbdbld3prd.KAGJCM.local
#  Alternate server port number         = 60000
#
# Node 184 entry:
# 
#  Node name                      = SSYSIN7D
#  Comment                        =
#  Directory entry type           = LOCAL
#  Protocol                       = TCPIP
#  Hostname                       = ssdb1dev
#  Service name                   = 50024
#  Remote instance name           =
#  System                         =
#  Operating system type          = None
# 
# ---------------------------------------------------------------------------------

my %databaseData = ();         # structure to hold the returned data

my %valid_entries = (
  "Database alias"              => 1,
  "Database name"               => 1,
  "Comment"                     => 1,
  "Directory entry type"        => 1,
  "Local database directory"    => 1,
  "Node name"                   => 1,
  "Hostname"                    => 1,
  "Service name"                => 1,
  "Authentication"              => 1,
  "Protocol"                    => 1
);

# load the report data into an internal data structure
ingestData ($inputpipe, '=', \%valid_entries, \%databaseData, '', 'Database (.*) entry\:','','','');

if ( $debugLevel > 0 ) { # print out the available keys
  foreach my $key ( sort keys %databaseData ) { # looping through the 'Database data records'
    displayDebug("Key: $key Data: $databaseData{$key}",1,$currentRoutine);
  }
}

# close the input file

close $inputpipe;

if ( $node_inFile ne "" ) {
  displayDebug("DB Directory list will be read from $node_inFile",1,$currentRoutine);
  if ( $node_inFile eq 'STDIN' ) {
    if (! open ($inputpipe,"-"))  { die "Can't open STDIN for input $!\n"; }
  }
  else {
    if (! open ($inputpipe,"<","$node_inFile"))  { die "Can't open $node_inFile for input$!\n"; }
  }
}
else {
  displayDebug("Issuing: db2 list node directory show detail",1,$currentRoutine);
  if (! open ($inputpipe,"db2 list node directory show detail |"))  {
    die "Can't run db2 list node directory! $!\n";
  }
}

my %nodeData = ();         # structure to hold the returned data

# load the report data into an internal data structure
ingestData ($inputpipe, '=', \%valid_entries, \%nodeData, '', 'Node name','','','');

if ( $debugLevel > 0 ) { # print out the available keys
  foreach my $key ( sort keys %nodeData ) { # looping through the 'Node data records'
    displayDebug("Key: $key Data: $nodeData{$key}",1,$currentRoutine);
    foreach my $key2 ( sort keys %{$nodeData{$key}} ) { # looping through the 'Node data records keys'
      displayDebug("sub-Key: $key2 Data: $nodeData{$key}{$key2}",1,$currentRoutine);
    }
  }
}

# close the input file

close $inputpipe;

# now process the loaded data

my $firstEntryInfo = 1;      # flag for printing headings for app data
my $dirNode = '';            # directory or node information
my $node = '';               # node information


if ( $displayDBs ) {
  foreach my $entry ( sort by_type_name_value keys %databaseData) { # looping through each of the database records

    if ( $DBName_Sel ne '' ) { # some selection is being done
      if ( ( uc($databaseData{$entry}{'Database name'}) !~ uc($DBName_Sel) ) &&
           ( uc($databaseData{$entry}{'Node name'}) !~ uc($DBName_Sel) ) &&
           ( uc($databaseData{$entry}{'Database alias'}) !~ uc($DBName_Sel) ) ) { 
        next; 
      } # skip this record as not selected 
    }

    if ( $NodeName_Sel ne '' ) { # some selection is being done
      if ( uc($databaseData{$entry}{'Node name'}) !~ uc($NodeName_Sel) ) {
        next; 
      } # skip this record as not selected 
    }
  
    displayDebug("Database Entry $entry being processed",1, $currentRoutine);

    if ( $entry eq 'root' ) { next; } # skip root entry

    if ( $printDetail ) { # print out the database detail
      if ( $firstEntryInfo ) {
        print "Database listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($NowTS) .... \n\n";
        printf " %-10s %-10s %-8s %-20s %-30s", 'DB Alias','DB Name','Type','Comment','Directory/Node(Authentication)';
        printf " %-20s %-10s %-10s\n", 'Hostname', 'Protocol', 'Port/Service';
        printf " %10s %-10s %-8s %-20s %30s", '----------','----------','--------','--------------------','------------------------------';
        printf " %-20s %-10s %-10s\n", '--------------------', '----------', '------------';
        $firstEntryInfo = 0;
      }
    }

    $node = '';
    $dirNode = '';
    if ( defined($databaseData{$entry}{'Node name'}) ) { 
      $dirNode = $databaseData{$entry}{'Node name'}; 
      $node = $databaseData{$entry}{'Node name'};
    } 

    if ( defined($databaseData{$entry}{'Authentication'}) ) { $dirNode .= ' (' . $databaseData{$entry}{'Authentication'} . ')' ; } 
    elsif ( defined($databaseData{$entry}{'Local database directory'}) ) { $dirNode = $databaseData{$entry}{'Local database directory'};  }  

    if ( $printDetail ) { # print out the database detail
      # print out the database information
      printf " %-10s %-10s %-8s %20s %-30s", $databaseData{$entry}{'Database alias'}, $databaseData{$entry}{'Database name'}, $databaseData{$entry}{'Directory entry type'}, $databaseData{$entry}{'Comment'}, $dirNode;
  
      # print out the node information
      printf " %-20s %-10s %-10s\n", $nodeData{$node}{'Hostname'}, $nodeData{$node}{'Protocol'}, $nodeData{$node}{'Service name'};
    }
  
    # generate the definitions as necessary
    if ( $generateDefs ) {
      # construct the Node def
      if ( defined($nodeData{$node}{'Hostname'}) ) {
        if (  $nodeData{$node}{'Protocol'} eq 'TCPIP' ) {
          $generateNode{$node} = "${cmdPref}catalog  $nodeData{$node}{'Protocol'} node $node remote $nodeData{$node}{'Hostname'} server $nodeData{$node}{'Service name'}$cmdSuff";
        }
        else { # treat the same as TCPIP
          $generateNode{$node} = "${cmdPref}catalog  $nodeData{$node}{'Protocol'} node $node remote $nodeData{$node}{'Hostname'} server $nodeData{$node}{'Service name'}$cmdSuff";
        }
      }
      # construct the DB def
      my $commLit = '';
      if ( defined($databaseData{$entry}{'Comment'})  && ( $databaseData{$entry}{'Comment'} ne '' ) ) { $commLit = " with \"" . $databaseData{$entry}{'Comment'} . "\" "; }
      my $authLit = '';
      if ( defined($databaseData{$entry}{'Authentication'}) ) { $authLit = " authentication \"" . $databaseData{$entry}{'Authentication'} . "\" "; }
  
      if ( defined($nodeData{$node}{'Hostname'}) ) {
        $generateDB{$databaseData{$entry}{'Database alias'}} = "${cmdPref}catalog db $databaseData{$entry}{'Database name'} as $databaseData{$entry}{'Database alias'} at node $node $authLit $commLit $cmdSuff";
      }
      else {
        $generateDB{$databaseData{$entry}{'Database alias'}} = "${cmdPref}catalog db $databaseData{$entry}{'Database name'} as $databaseData{$entry}{'Database alias'} on '$dirNode' $authLit $commLit $cmdSuff";
      }
    }
  }
}
elsif ( $displayNodes ) {
  foreach my $node ( sort keys %nodeData) { # looping through each of the node records

    if ( $NodeName_Sel ne '' ) { # some selection is being done
      if ( uc($node) !~ uc($NodeName_Sel) ) {
        next;
      } # skip this record as not selected
    }

    displayDebug("Node Entry $node being processed",1, $currentRoutine);

    if ( $node eq 'root' ) { next; } # skip root entry

    if ( $printDetail ) { # print out the database detail
      if ( $firstEntryInfo ) {
        print "Node listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($NowTS) .... \n\n";
        printf "%-20s %-30s %-10s %-10s\n", 'Node', 'Hostname', 'Protocol', 'Port/Service';
        printf "%-20s %-30s %-10s %-10s\n", '--------------------', '------------------------------', '----------', '----------';
        $firstEntryInfo = 0;
      }
    }

    if ( $printDetail ) { # print out the node detail
      # print out the node information
      printf "%-20s %-30s %-10s %-10s\n", $node, $nodeData{$node}{'Hostname'}, $nodeData{$node}{'Protocol'}, $nodeData{$node}{'Service name'};
    }

    # generate the definitions as necessary
    if ( $generateDefs ) {
      # construct the Node def
      if (  $nodeData{$node}{'Protocol'} eq 'TCPIP' ) {
        $generateNode{$node} = "${cmdPref}catalog  $nodeData{$node}{'Protocol'} node $node remote $nodeData{$node}{'Hostname'} server $nodeData{$node}{'Service name'}$cmdSuff";
      }
      else { # treat the same as TCPIP
        $generateNode{$node} = "${cmdPref}catalog  $nodeData{$node}{'Protocol'} node $node remote $nodeData{$node}{'Hostname'} server $nodeData{$node}{'Service name'}$cmdSuff";
      }
    }
  }
}

# print out catalog definitions if required

if ( $generateDefs ) {
  if ( $displayNodes ) {
    print "\n\nGenerated node definitons entries ........\n";
    foreach my $node ( sort keys %generateNode ) {
      print "$generateNode{$node}\n";
    }
  }
  if ( $displayDBs ) {
    print "\nGenerated database definitons entries ........\n";
    foreach my $db ( sort keys %generateDB ) {
      print "$generateDB{$db}\n";
    }
  }
}

# Subroutines and functions ......

sub by_type_name_value {
  $databaseData{$a}{'Directory entry type'} . $databaseData{$a}{'Database name'} cmp $databaseData{$b}{'Directory entry type'} . $databaseData{$b}{'Database name'};
}

