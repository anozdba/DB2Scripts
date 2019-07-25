#!/usr/bin/perl
# --------------------------------------------------------------------
# db2Machine.pl
#
# $Id: db2Machine.pl,v 1.26 2019/07/11 22:11:29 db2admin Exp db2admin $
#
# Description:
# Loops through all Instances/Databases on the machine (as identified by db2ilist) and display's config information
#
# $Name:  $
#
# ChangeLog:
# $Log: db2Machine.pl,v $
# Revision 1.26  2019/07/11 22:11:29  db2admin
# add in option to exclude the netbackup check
# covert to use strict
#
# Revision 1.25  2019/02/07 04:18:52  db2admin
# remove timeAdd from the use list as the module is no longer provided
#
# Revision 1.24  2019/01/29 00:04:11  db2admin
# change the parameter names referenced in commonFunctions.pm
#
# Revision 1.23  2018/10/21 21:01:47  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.22  2018/10/18 22:36:52  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.21  2018/10/16 21:54:59  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.20  2014/08/13 06:29:19  db2admin
# Add in db2 log location
#
# Revision 1.19  2014/05/25 22:18:20  db2admin
# correct the allocation of windows include directory
#
# Revision 1.18  2013/07/22 01:53:46  db2admin
# change column name from db2vers to dbvers
#
# Revision 1.17  2012/11/05 01:03:41  db2admin
# A couple of changes:
# 1. Correct the Windows parsing of Netbackup information
# 2. Add in collections of current connections to each DB
#
# Revision 1.16  2012/03/06 00:40:01  db2admin
# ensure the database name returned is in upper case
#
# Revision 1.15  2011/08/30 02:26:28  db2admin
# Alter the location to get the Netbackup version number from
#
# Revision 1.14  2011/04/17 23:17:52  db2admin
# Alter db2 fix pack identification for SAP db2 regions
# on DB2 9.5
#
# Revision 1.13  2011/03/02 01:12:43  db2admin
# Add in support for identifying Netbackup version on Windows
#
# Revision 1.12  2010/12/08 04:50:02  db2admin
# add in code to work with Windows 2000
#
# Revision 1.11  2010/12/01 22:25:46  db2admin
# change comparison for db2 v9.7
#
# Revision 1.10  2010/10/17 22:32:35  db2admin
# if no service name is found just use the svcename entry
#
# Revision 1.9  2009/08/05 02:18:13  db2admin
# Correct Month literal
#
# Revision 1.8  2009/07/13 06:20:29  db2admin
# Corrected output when no databases found (ie db2 gateway)
#
# Revision 1.7  2009/06/16 03:05:31  db2admin
# Add in the collection of Netbackup version for unix boxes
#
# Revision 1.6  2009/03/23 01:40:56  db2admin
# correct syntax error
#
# Revision 1.5  2009/03/23 01:39:45  db2admin
# add in code to output instance info if no databases
#
# Revision 1.4  2009/01/22 00:07:47  db2admin
# Initialise SYSPath variable if it isn't automatically set in Windows
#
# Revision 1.3  2009/01/07 23:43:32  db2admin
# standardise parameters
# add in database selection, report format and instance selection from a file
#
# Revision 1.2  2008/11/14 01:03:34  m08802
# Add collection of DB2 install directory
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: db2Machine.pl,v 1.26 2019/07/11 22:11:29 db2admin Exp db2admin $';
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
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs[F][r] [-d <database>] [-f <filename>] [-N]

       Script to loop through all Instances/Databases on the machine (as identified by db2ilist) and display's config information

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database to generate the DB2LOOK for (defaults to All)
       -f              : File name to use as input instead of doing a db2ilist command
       -F              : Use default file input (identical to -f db2ilist.txt)
       -N              : dont get netbackup information
       -r              : Generate a report of the information
       \n";
}

# Set default values for variables

my $silent = 0;
my $database = "All";
my $inFile = "";
my $report = "No";
my $getNB = 1;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

while ( getOpt(":?hsd:f:FrN") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = 1;
 }
 elsif (($getOpt_optName eq "r"))  {
   if ( ! $silent ) {
     print "A report will be produced instead of the default load format output\n";
   }
   $report = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( ! $silent ) {
     print "Instance list will be read from $getOpt_optValue\n";
   }
   $inFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "N"))  {
   if ( ! $silent ) {
     print "Netbackup information wont be collected\n";
   }
   $getNB = 0;
 }
 elsif (($getOpt_optName eq "F"))  {
   if ( ! $silent ) {
     print "Instance list will be read from db2ilist.txt\n";
   }
   $inFile = "db2ilist.txt";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( ! $silent ) {
     print "Only database $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 else { # handle other entered values ....
   if ( $database eq "All" ) {
     $database = $getOpt_optValue;
     if ( ! $silent ) {
       print "Only database $getOpt_optValue will be listed\n";
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
my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
my @monthName = ('January','February','March','April','May','June','July','August','September','October','November','December');
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $Now = "$year.$month.$day $hour:$minute:$second";
my $NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
my $NowDay = "$year$month$day";
my $NowMonth = "$day $monthName[$month-1], $year at $hour:$minute";

my $intallDir = "";

# Global variables

my @cmdout_info;
my @cmp_info;
my @cmp;
my @nbv;
my %appConns;
my $dbname;
my $dbvers;
my $fp;
my $fplevel;
my $installDir;
my $service_port;
my $serviceFile;
my $svcLine;
my $SYSPath;
my $tmpDB;
my $tmpLogDir;

my $NBVersion = "";
my $lastPatch = "";
my $patchName = '';
my $liveUpdateSeqNum;
my $maxSeq = 0;
my $section;
my $result = '';
my @prm = ();

# if windows then find out Netbackup version 

if ($OS eq "Windows") {
  
  if ( $getNB ) { # get the netbackup information
    my $result = `del c:\\nbregedit.dmp`;
    $result = `regedit /E:A c:\\nbregedit.dmp HKEY_LOCAL_MACHINE\\SOFTWARE\\Veritas`;
    if ( !open (REGKEY,"<c\:\\nbregedit.dmp") )  { die "Cant open c\:\\nbregedit.dmp! $!\n"; }
    while ( <REGKEY> ) {
#        print $_;
      if ( $_ =~ /NetBackup\\CurrentVersion\]/ ) { 
        $section = "CurrentVersion"; 
        next;
      }
      if ( $_ =~ /NetBackup\\CurrentVersion\\Agents\]/ ) { 
        $section = ""; 
        next;
      }
      if ( ($_ =~ /VERSION"=/) && ($section eq "CurrentVersion" ) ) { 
        @prm = split(/=/,$_) ;
        $NBVersion = substr($prm[1],1,length($prm[1])-3);
        next;
      }
      if ( $_ =~ /Patches\\NetBackup\]/ ) { 
        $section = "Patches"; 
        next;
      }
      if ( $_ =~ /Veritas\\Symantec\]/ ) { 
        $section = ""; 
        next;
      }
      if ( $_ =~ /NetBackup for Lotus Notes/ ) { 
        $section = ""; 
        next;
      }
      if ( ($_ =~ /PatchName/) && ($section eq "Patches" ) ) { 
        @prm = split(/=/,$_) ;
        $patchName = substr($prm[1],1,length($prm[1])-3);
        next;
      }
      if ( ($_ =~ /LiveUpdateSeqNum/) && ($section eq "Patches" ) ) { 
        @prm = split(/=/,$_) ;
        $liveUpdateSeqNum = substr($prm[1],1,length($prm[1])-3);
        if ( $liveUpdateSeqNum > $maxSeq ) {
          $maxSeq = $liveUpdateSeqNum;
          $lastPatch = $patchName;
        }
        next;
      }
    }
    close REGKEY;
  }
}

$lastPatch =~ s/Veritas NetBackup //;
#print "Latest Patch was $lastPatch (seq: $maxSeq)\n";
if ( $lastPatch ne "" ) {
  $NBVersion = $lastPatch;
}

# List out all of the Instances on the box ....
if ( $inFile ne "" ) {
  if (! open (INSTPIPE,"<$inFile"))  { die "Can't open $inFile! $!\n"; }
}
else {
  if (! open (INSTPIPE,"db2ilist | "))  { die "Can't run db2ilist! $!\n"; }
}

$machine = lc($machine);

my $linein = '';
my $instance = '';
my $currSection = "";
my $autostart = "NO";
my $dbalias = "";
my $recordListed = "No";
my @appConns = ();

while (<INSTPIPE>) {
    if ( $_ =~ /Instance Error encountered/) { next; } # skip this message ....

    $instance = $_;
    chomp $instance;
    # print "Processing Instance $instance\n";
    # print "instance=$instance , machine = $machine\n";
    if ( ($instance eq "dbamainr") && ($machine eq "ratprdapp.mplcan.mplnet") ) {
      # skip this instance
      next;
    }

    # Construct the Command file that will be interpreted ..... 
    if (! open (CMDFILE, ">cmdfile.tmp")) {die "Can't open output cmd file! $!\n"; }
    $ENV{'DB2INSTANCE'}=$instance;
    if ($OS eq "Windows") {
      $result = `db2 get dbm cfg`;
      print CMDFILE $result;
      $result = `db2level `;
      print CMDFILE $result;
      print CMDFILE "DB2SET\n";
      $result = `db2set `;
      print CMDFILE $result;
      print CMDFILE "LIST APPLICATIONS\n";
      $result = `db2 list active databases `;
      print CMDFILE $result;
      $result = `db2 list db directory `;
      print CMDFILE $result;
      close CMDFILE;
    }
    else {
      $NBVersion = "";
      $result = `cat /usr/openv/netbackup/bin/version`;
      print CMDFILE $result;
      $result = `db2 get dbm cfg  | cat`;
      print CMDFILE $result;
      $result = `db2level | cat`;
      print CMDFILE $result;
      print CMDFILE "DB2SET\n";
      $result = `db2set | cat`;
      print CMDFILE $result;
      print CMDFILE "LIST APPLICATIONS\n";
      $result = `db2 list active databases | cat`;
      print CMDFILE $result;
      $result = `db2 list db directory | cat`;
      print CMDFILE $result;
      close CMDFILE;
    }

    # Run the command file and process the results .....
    if (! open (DBPIPE,"<cmdfile.tmp"))  { die "Can't open cmdfile.tmp! $!\n"; }
    $currSection = "";
    $autostart = "NO";
    $dbalias = "";
    $recordListed = "No";
    @appConns = ();

    $instance = lc($instance);

    while (<DBPIPE>) {

#      print "$_\n";
      $linein = $_;
      chomp $linein;
      @cmdout_info = split(/=/,$linein);

      if ($fp eq "yes") {
        @cmdout_info = split(/"/);
        $fplevel = $cmdout_info[1];
      }

      $fp= "";
      if ($linein =~ /tabase Manager Configuration/) {
        $currSection = "DBMCFG";
      }
      elsif ($linein =~ /System Database Directory/) {
        $currSection = "DBDIR";
      }
      elsif ($linein =~ /DB2SET/) {
        $currSection = "DB2SET";
      }
      elsif ($linein =~ /LIST APPLICATIONS/) {
        $currSection = "LISTAPP";
        @appConns = ();
      }
      elsif ($linein =~ /NetBackup-/) {
        $currSection = "NetBackup";
      }
      elsif ($linein =~ /formational tokens/) {
        $currSection = "DB2LEVEL";
      }

      if ($currSection eq "LISTAPP") {
        @prm = split ('=', $linein); 
        $prm[0] = trim($prm[0]);
        if ( $prm[0] eq "Database name" ) { 
          $tmpDB = trim($prm[1]);
          $appConns{$tmpDB} = 0;
        }
        elsif ( $prm[0] eq "Applications connected currently" ) { 
          $appConns{$tmpDB} = trim($prm[1]);
        }
      }

      if ($currSection eq "DBMCFG") {
        if ($linein =~ /\(SVCENAME\)/) {
          if ($OS eq "Windows") {
            $service_port = trim($cmdout_info[1]);
            if ( $SYSPath eq "" ) {
              $SYSPath = "c:\\windows";
              if (! -e "$SYSPath\\system32\\drivers\\etc\\services") {
                $SYSPath = "c:\\winnt";
              }
            }
            $serviceFile = "$SYSPath\\system32\\drivers\\etc\\services";
            if ( open (SVCPIPE, $serviceFile ))  { 
              $svcLine = "";
              while (<SVCPIPE>) {
                if ($_ =~ /$service_port/) {
                  $svcLine = $_;
                  last;
                }
              }
              if ($svcLine ne "") {
                @cmp = split(/\s+/,$svcLine);
                @cmp_info = split(/\//,$cmp[1]);
                $service_port = $cmp_info[0];
              }
            }
            else {  # die "Can't open input services file! $!\n"; 
             print "Unable to open $SYSPath\\system32\\drivers\\etc\\services \n $! \n";  
            }
          }
          else {
            if (trim($cmdout_info[1]) ne "") {
              $svcLine = `grep $cmdout_info[1] \/etc\/services`;
              if ( $svcLine ne '' ) {
                @cmp = split(/\s+/,$svcLine);
                @cmp_info = split(/\//,$cmp[1]);
                $service_port = $cmp_info[0];
              }
              else {
                $service_port = trim($cmdout_info[1]);
              }
            }
          }
        }
      }

      if ($currSection eq "DB2SET") {
        if ($linein =~ /DB2AUTOSTART/) {
          @cmp = split(/=/,$linein);
          $autostart = $cmp[1];
        }
      }

      if ($currSection eq "NetBackup") {
        @nbv = split(/\s/,$linein);
        $NBVersion = $nbv[1];
        $currSection = "Unknown";
      }

      if ($currSection eq "DB2LEVEL") {
        @cmdout_info = split(/"/);
        if ($linein =~ /Informational tokens are/) {
          $dbvers = $cmdout_info[1];
        }
        elsif ($linein =~ / and informational tokens /) {
          $dbvers = $cmdout_info[3];
        }
        elsif ($linein =~ /Product is installed at/ ) {
          $installDir = $cmdout_info[1];
        }
        if ($linein =~ /Fix/) {
          if ($linein =~ /^Fix/) {
            $fplevel = $cmdout_info[1]; 
            $fp = "no";
          }
          else {
            $fp = "yes";
          }
        }
      }

      if ($currSection eq "DBDIR") {
        if ($linein =~ /Database alias/) {
          $dbalias = uc(trim($cmdout_info[1]));
#          print "Processing Database $dbname\n";
        }
        elsif ($linein =~ /Database name/) {
          $dbname =uc(trim($cmdout_info[1]));
#          print "Processing Database $dbname\n";
        }
        elsif ($linein =~ /Directory entry type/) {
          if ($linein =~ /Indirect/) {
            if ( (uc($database) eq uc($dbname)) || ($database eq "All") ) {
              if ( $OS eq "Windows" ) {
                $tmpLogDir = `db2 get db cfg for $dbname | find "Path to log files"`
              }
              else {
                $tmpLogDir = `db2 get db cfg for $dbname | grep "Path to log files"`
              }
              ($logDir) = ($tmpLogDir =~ /.*\=(.*)/);
              $logDir = trim($logDir);
              $recordListed = "Yes";
              if ( $report eq "Yes" ) {
                if ( defined($appConns{$dbalias}) )  { # connections found
                  print "Database configuration for $dbname at $Now\n
                   Instance       : $instance
                   DBalias        : $dbalias
                   Machine        : $machine
                   Service Port   : $service_port
                   DB2 Version    : $dbvers
                   Fix Pack Level : $fplevel
                   OS             : $OS
                   Autostart      : $autostart
                   Inst Dir       : $installDir
                   Netbackup Vers : $NBVersion
                   Connections    : $appConns{$dbalias}
                   \n\n";
                }
                else { # no Connections found
                  print "Database configuration for $dbname at $Now\n
                   Instance       : $instance
                   DBalias        : $dbalias
                   Machine        : $machine
                   Service Port   : $service_port
                   DB2 Version    : $dbvers
                   Fix Pack Level : $fplevel
                   OS             : $OS
                   Autostart      : $autostart
                   Inst Dir       : $installDir
                   Netbackup Vers : $NBVersion
                   Connections    : None Found
                   \n\n";
                }
              }
              else {
                if ( defined($appConns{$dbalias}) ) { # connections found
                  print "$Now,$machine,$instance,$dbname,$dbalias,$service_port,$dbvers,$fplevel,$OS,$autostart,$installDir,$NBVersion,$appConns{$dbalias},$logDir\n";
                }
                else { # no Connections found
                  print "$Now,$machine,$instance,$dbname,$dbalias,$service_port,$dbvers,$fplevel,$OS,$autostart,$installDir,$NBVersion,0,$logDir\n";
                }
              }
            }
          }
        }
      }
    }

    if ( $recordListed eq "No" ) {
      # if nothing has been printed and we weren't looking for a specific database then print out the Instance stuff
      if ( $database eq "All" ) {
        if ( $report eq "Yes") {
          print "Instance Information at $Now\n
           Instance       : $instance
           DBalias        : NONE
           Machine        : $machine
           Service Port   : $service_port
           DB2 Version    : $dbvers
           Fix Pack Level : $fplevel
           OS             : $OS
           Autostart      : $autostart
           Inst Dir       : $installDir
           Netbackup Vers : $NBVersion
           Connections    : None Found
           \n\n";
        }
        else {
          print "$Now,$machine,$instance,NONE,NONE,$service_port,$dbvers,$fplevel,$OS,$autostart,$installDir,$NBVersion,0,NONE\n";
        }
      }
    }
    # print "Finished with Instance $instance\n";
}


