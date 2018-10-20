#!/usr/bin/perl 
# --------------------------------------------------------------------
# diagLogStrip.pl
#
# $Id: diagLogStrip.pl,v 1.27 2018/10/18 22:58:49 db2admin Exp db2admin $
#
# Description:
# Script to extract significant messages from a DB2 db2diag.log file 
#
# NOTE: Though this script has code checking OS is windows etc it can only be run   
#       in a Unix environment (needs more code to be Windows compliant)
#
# $Name:  $
#
# ChangeLog:
# $Log: diagLogStrip.pl,v $
# Revision 1.27  2018/10/18 22:58:49  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.26  2018/10/16 22:20:31  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.25  2014/05/25 22:20:39  db2admin
# correct the allocation of windows include directory
#
# Revision 1.24  2010/07/19 01:36:56  db2admin
# Adjust the messages put out to the Critical messages file
#
# Revision 1.23  2010/07/02 01:25:58  db2admin
# add in header for the generated Critical message files
#
# Revision 1.22  2010/06/30 22:59:15  db2admin
# add in default instance name
#
# Revision 1.21  2010/06/28 06:09:36  db2admin
# Modify script to try and isolate critical messages in the log
#
# Revision 1.20  2009/10/14 21:47:21  db2admin
# Modify to ensure that where possible Instance is never blank
#
# Revision 1.19  2009/10/09 00:26:38  db2admin
# Correct location of manual exclude list
#
# Revision 1.18  2009/10/08 04:12:57  db2admin
# add in some diagnostic data about retained messages
#
# Revision 1.17  2009/10/08 03:47:29  db2admin
# correct some parse errors
#
# Revision 1.16  2009/10/08 00:21:59  db2admin
# Add in facility to keep/drop records if they dont appear for a day
# DEFAULT is to drop the records -R to retain them
#
# Revision 1.15  2009/10/07 00:12:30  db2admin
# changed the default autoexclude directory to be scripts/autoexclude in UNIX
#
# Revision 1.14  2009/09/25 01:39:29  db2admin
# correct bug which meant new records weren't being added
#
# Revision 1.13  2009/09/24 05:08:09  db2admin
# Add in autoexclude feature
#
# Revision 1.12  2009/04/14 22:49:02  db2admin
# Display machine specific messages loaded
#
# Revision 1.11  2009/04/14 22:21:07  db2admin
# Print out version information and start timestamp to output report
#
# Revision 1.10  2009/04/14 06:27:28  db2admin
# modify exclude strings to allow machine specific comparisons
# remove machine specific checks from the program
#
# Revision 1.9  2009/04/08 02:45:01  db2admin
# suppress log archive errors on ratprdapp
#
# Revision 1.8  2009/04/01 21:24:29  db2admin
# Allow the overriding of the machine name
#
# Revision 1.7  2009/04/01 04:47:15  db2admin
# Exclude Probe:80 records from the SMVUMEC162 logs
#
# Revision 1.6  2009/03/16 22:08:53  db2admin
# Do not load up null strings into the exclude table
#
# Revision 1.5  2009/03/12 23:36:09  db2admin
# Correct exclusions for 09db comm errors
#
# Revision 1.4  2009/01/12 21:08:35  db2admin
# standardise messaging and add in some options to select the location of the exclude file
# Also add in a summary of the run to the output file
#
# Revision 1.3  2008/11/27 01:47:37  m08802
# Add in new exclusions for STMM messages on SAP boxes
#
# Revision 1.2  2008/11/10 01:34:26  m08802
# Add in automatic rejection for db2hmon connections being refused
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

my $ID = '$Id: diagLogStrip.pl,v 1.27 2018/10/18 22:58:49 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hs [-n <number of records to output>] [-R] [-v[v]] [-a nn] [-r nn] [-D <directory>] [-x <file name>] [-c <critical message file name>] [-c <critical message directory>] [-m <machine>] [DIAG] <db2Diaglog >strippedDiagLog

       Script to extract significant messages from a DB2 db2diag.log file

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -n               : Number of output records to produce
       -a nn            : Autoexclude: only show messages for a period of nn days ( if not entered autoexclude is turned off)
       -r nn            : Autoexclude: resume showing messages after nn days (default 30)
       -R               : retain autoexclude records even if they dont appear for a day
       -D               : Directory holding the exclude list file (Default: the directory the script resides in)
       -x               : File name of the file holding the exclude list (Default: diagLogStrip_exclude)
       -c               : File name of the file holding the critical message list (Default: diagLogStrip_critical)
       -C               : Directory to place the critcal messages (Default: ~/logs on Unix, Current directory on Windows)
       -S               : Produce a summary at the end of the output file
       -m               : machine that this log is from (if not run on the same machine)
       -i               : instance that the log is from 
       DIAG             : Turn on diagnostic output
       -v               : vary the levels of diagnostic data

       NOTE: diag log is read from STDIN and filtered log is output to STDOUT

     \n";
}

sub logMessage {

  if ( $diagLevel > 0 ) { print "Logging Message: $logMessage_text\n"; }

#  if ( $#_ > -1 ) {
#    if ( trim("$_") eq "" ) {
#      return;
#    }
#  }

  if ( trim("$logMessage_text") eq "" ) {
    return;
  }

  $tmpMsg = "$logMessage_text";

  $serverInstance = "$machine:$instance";
  if ( $serverInstance ne $currServerInstance ) {
    if ( $diagLevel > 0 ) { print "Change of Server/Instance. From $currServerInstance to $serverInstance\n"; }
    if ( $currServerInstance ne "" ) { # some data already collected so print out these details
      if ( $diagLevel > 1 ) { print "Data already collected - flushing array first\n"; }
      if ( !open (AUTOEXCL,">${autoexcludeDir}autoExclude_$currServerInstance") ) { 
        die "Unable to open ${autoexcludeDir}autoExclude_$currServerInstance -2\n$!\n";
      }
      else {
        # Able to open the file so just output the detail ......

        $totalMessages = 0;
        $retainedMessages = 0;

        if ( $diagLevel > 1 ) { print "Open of ${autoexcludeDir}autoExclude_$currServerInstance was successful - saving array\n"; }
        if ( $retain eq "Yes" ) { # keep all of the keys 
          foreach $key (keys %recKey ) {
            $totalMessages++;
            $retainedMessages++;
            print AUTOEXCL "$recKey{$key}:$key\n";
          }
          close AUTOEXCL;
        }
        else {
          foreach $key (keys %recKey ) {
            $totalMessages++;
            if ( defined($retainKey{$key}) ) {
              $retainedMessages = 0;
              print AUTOEXCL "$recKey{$key}:$key\n";
            }
          }
        }
        # print out details .....
        if ($summary = "Yes") {
          print "\nTotal AUTOEXCLUDE messages processed: $totalMessages\nTotal AUTOEXCLUDE messages retained: $retainedMessages\n";
        }
        print STDERR "\nTotal AUTOEXCLUDE messages processed: $totalMessages\nTotal AUTOEXCLUDE messages retained: $retainedMessages\n";
      }
    }
    if ( $diagLevel > 0 ) { print "recKey table now cleared\n"; }
    # first time through for this instance so load up the existing autoexclude messages .....
    @recKey = (); # clear out the array
    @retainKey = (); # clear out the array used to identify messages that have occurred in this run
    
    # if an autoexclude file exists then load it up ......
    $/ = "\n";
    if ( open(AUTOEXCL,"<${autoexcludeDir}autoExclude_$serverInstance"))  { 
      while ( <AUTOEXCL> ) {
         chomp $_;
         @tmp = split(':',$_,2);
         if (  $tmp[0] > -1 ) { # if the first printed value is -1 then leave it there
           $recKey{$tmp[1]} = $tmp[0]+1; # increment the first printed count by 1
         }
         if ( $recKey{$tmp[1]} > $autoexcludeResume ) { # reset the counts when they reach the Resume figure
           $recKey{$tmp[1]} = -1;
         }
         if ( $diagLevel > 1 ) { print "Message loaded from file with a count of $recKey{$tmp[1]}: >>>>$tmp[1]<<<<\n"; }
      }
      close AUTOEXCL;
    }
    $/ = "\n\n";
 
    $currServerInstance = $serverInstance; 
    $suppressedMessages = 0;
    if ( $diagLevel > 0 ) { print "Server/Instance now changed to $serverInstance\n"; }
  }

  $tmpKey = trim("$tmpMsg");

  if ( $diagLevel > 1 ) { print "Table count is $#recKey\n"; }
  if ( $diagLevel > 1 ) { print "Message             has a count of       0: >>>>$tmpKey<<<<\n"; }
  if ( defined ( $recKey{$tmpKey} ) ) {
    if ( $recKey{$tmpKey} == -1 ) { # if the message hasn't been printed yet then flag it as printed today
      if ( $diagLevel > 1 ) { print "Inserting the key\n"; }
      $recKey{$tmpKey} = 0; # just set the first printed count to zero (ie seen today)
    }
  }
  else { # not yet defined .....
    if ( $diagLevel > 1 ) { print "Inserting the key\n"; }
    $recKey{$tmpKey} = 0; # just set the first printed count to zero (ie seen today)
  }
  if ( $diagLevel > 1 ) { print "Message $tmpKey has had its count set to 0 \n"; }
  if ( $diagLevel > 1 ) { print "Table count is $#recKey\n"; }

}

$logMessage_text = "";

if ( $OS eq "Windows" ) {
  $user = "db2admin";
  $userHome = "c:\docume~1\db2admin";
}
else {
  $user = `id  | cut -d"(" -f2 | cut -d")" -f 1`;
  chomp $user;
  $userHome = `grep $user /etc/passwd | cut -d":" -f6`;
  chomp $userHome;
}
print STDERR "User=$user\n";
print STDERR "Home=$userHome\n";

# Set default values for variables

$silent = "No";
$numOutRecs = -1;
$excludeFile = "diagLogStrip_exclude";
$criticalFile = "diagLogStrip_critical";
if ( $OS eq "Windows") {
  $criticalDir = "";
}
else {
  $criticalDir = "$userHome/logs/";
}
$criticalFile = "diagLogStrip_critical";
$excludeDir = "";
$summary = "No";
$diagLevel = 0;
$autoexcludeResume = 30;
$autoexcludeDays = 0;
$retain = "No";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?shvRa:r:m:i:n:D:x:Sc:C:|^DIAG";

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
 elsif (($getOpt_optName eq "n"))  {
   if ( $silent ne "Yes") {
     print "Only $getOpt_optValue records will be listed\n";
   }
   $numOutRecs = $getOpt_optValue;
   $numOutRecs--;
 }
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "A summary of input records will be appended to the end of the output file\n";
   }
   $summary = "Yes";
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( $silent ne "Yes") {
     print "If no instance is found in the diag file then it will assumed the instance is $getOpt_optValue days\n";
   }
   $instance = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "a"))  {
   if ( $silent ne "Yes") {
     print "Autoexclude has been turned on.\nMessages will only be shown for $getOpt_optValue days\n";
   }
   $autoexcludeDays = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "R"))  {
   if ( $silent ne "Yes") {
     print "Autoexclude entries will be retained even if they dont appear in the input file\n";
   }
   $retain = "Yes";
 }
 elsif (($getOpt_optName eq "r"))  {
   if ( $silent ne "Yes") {
     print "Autoexclude day timings will be reset after $getOpt_optValue days\n";
   }
   $autoexcludeResume = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "c"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be used as the source of the critical message definitions\n";
   }
   $criticalFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "x"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be used as the source of the exclude definitions\n";
   }
   $excludeFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "m"))  {
   if ( $silent ne "Yes") {
     print "Machine $getOpt_optValue will be used as the source of the db2diag.log file\n";
   }
   $machine = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "C"))  {
   if ( $silent ne "Yes") {
     print "Directory $getOpt_optValue will be used to put the critical messages in\n";
   }
   $criticalDir = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "D"))  {
   if ( $silent ne "Yes") {
     print "Directory $getOpt_optValue will be used as the source of the exclude file\n";
   }
   $excludeDir = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "DIAG"))  {
   if ( $silent ne "Yes") {
     print "Diagnostic mode selected (level=1)\n";
   }
   $diagLevel = 1;
 }
 elsif (($getOpt_optName eq "v"))  {
   $diagLevel++;
   if ( $silent ne "Yes") {
     print "Diagnostic level increased to $diagLevel\n";
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $numOutRecs eq "-1" ) {
     $numOutRecs = $getOpt_optValue;
     $numOutRecs--;
     if ( $silent ne "Yes") {
       print STDERR "Only $getOpt_optValue records will be listed\n";
     }
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

$inLines = 0;
$outLines = 0;
$discLines = 0;
$critLines = 0;
$msgSet = 0;
$numDiscStr = 0;
$numCritStr = 0;

$currServerInstance = "";

$scriptDir = "";
if ( $OS eq "Windows" ) {
  $levelDelim = "\\";
  $tmp = rindex($0,"\\");
}
else {
  $levelDelim = "/";
  $tmp = rindex($0,'/');
}

if ($tmp > -1) {
  $scriptDir = substr($0,0,$tmp+1);
}
print STDERR "Script Dir : $scriptDir (from $0)\n";
print STDERR "Exclude File : $excludeFile\n";
if ( $OS eq "Windows" ) {
  $autoexcludeDir = "autoexclude";
}
else {
  $autoexcludeDir = "$userHome/scripts/autoexclude";
}
if ( substr($autoexcludeDir,length($autoexcludeDir),1)  ne $levelDelim ) { # if the directory doesnt end in a level delimiter ....
  $autoexcludeDir = $autoexcludeDir . $levelDelim;
}

$excludeDir = $scriptDir;

if ( substr($excludeDir,length($excludeDir),1)  ne $levelDelim ) { # if the directory doesnt end in a level delimiter ....
  $excludeDir = $excludeDir . $levelDelim;
}

print STDERR "Starting $0 (Version $Version) - $NowTS\n";
print "Starting $0 (Version $Version) - $NowTS\n";

print STDERR "Exclude Dir : $excludeDir\n";
print STDERR "Auto Exclude Dir : $autoexcludeDir\n";

if (! open(EXCSTR,"<${excludeDir}$excludeFile"))  { 
      print STDERR "Can't open file ${excludeDir}$excludeFile - no exclude strings loaded\n";
}
else {
  while ( <EXCSTR> ) {
    chomp $_;
    # Skip lines starting with #! (Comments) 
    if ( substr($_,0,2) ne "#!" ) {
      # a #! pair within a line is the start of comments
      if ( $_ =~ /#!/ ) {
        ($msg_srv,$msg_msg,$msg_cmt)  = ($_ =~ /\<\<(.*)\>\>(.*)\#\!(.*)/);
        if ( trim($msg_msg) ne "" ) { # ignore null strings
          if ( ($msg_srv eq "ALL") || ($msg_srv eq $machine) ) { 
            $discardStr[$numDiscStr] = trim($msg_msg);
            print STDERR "$discardStr[$numDiscStr]  loaded ($msg_cmt)\n";
            if ( $msg_srv eq $machine ) { # machine specific message ....
              print "Message '$discardStr[$numDiscStr] ($msg_cmt)' loaded explicitly for this machine\n";
            }
            $numDiscStr++;
          }
        }
      }
      else {     
        if ( trim($_) ne "" ) { # ignore null strings
          ($msg_srv,$msg_msg)  = ($_ =~ /\<\<(.*)\>\>(.*)/);
          if ( trim($msg_msg) ne "" ) { # ignore null strings
            if ( ($msg_srv eq "ALL") || ($msg_srv eq $machine) ) {
              $discardStr[$numDiscStr] = trim($msg_msg);
              print STDERR "$discardStr[$numDiscStr]  loaded\n";
              if ( $msg_srv eq $machine ) { # machine specific message ....
                print "Message '$discardStr[$numDiscStr]' loaded explicitly for this machine\n";
              }
              $numDiscStr++;
            }
          }
        }
      }
    }
  }
  print STDERR "$numDiscStr exclude strings loaded\n";
}

if (! open(CRTSTR,"<${excludeDir}$criticalFile"))  {
      print STDERR "Can't open file ${excludeDir}$criticalFile - no critical strings loaded\n";
}
else {
  while ( <CRTSTR> ) {
    chomp $_;
    # Skip lines starting with #! (Comments)
    if ( substr($_,0,2) ne "#!" ) {
      # a #! pair within a line is the start of comments
      if ( $_ =~ /#!/ ) {
        ($msg_srv,$msg_msg,$msg_cmt)  = ($_ =~ /\<\<(.*)\>\>(.*)\#\!(.*)/);
        if ( trim($msg_msg) ne "" ) { # ignore null strings
          if ( ($msg_srv eq "ALL") || ($msg_srv eq $machine) ) {
            $criticalStr[$numCritStr] = trim($msg_msg);
            $criticalStrCNT[$numCritStr] = 0; # will hold a count of the critical messages found
            print STDERR "$criticalStr[$numCritStr]  loaded ($msg_cmt)\n";
            if ( $msg_srv eq $machine ) { # machine specific message ....
              print " Critical Message '$criticalStr[$numCritStr] ($msg_cmt)' loaded explicitly for this machine\n";
            }
            $numCritStr++;
          }
        }
      }
      else {
        if ( trim($_) ne "" ) { # ignore null strings
          ($msg_srv,$msg_msg)  = ($_ =~ /\<\<(.*)\>\>(.*)/);
          if ( trim($msg_msg) ne "" ) { # ignore null strings
            if ( ($msg_srv eq "ALL") || ($msg_srv eq $machine) ) {
              $criticalStr[$numCritStr] = trim($msg_msg);
              $criticalStrCNT[$numCritStr] = 0; # will hold a count of the critical messages found
              print STDERR "$criticalStr[$numCritStr]  loaded\n";
              if ( $msg_srv eq $machine ) { # machine specific message ....
                print "Critical Message '$criticalStr[$numCritStr]' loaded explicitly for this machine\n";
              }
              $numCritStr++;
            }
          }
        }
      }
    }
  }
  print STDERR "$numCritStr critical strings loaded\n";
}

$eventDisc = 0;
$stringDisc = 0;
$stringCrit = 0;
$suppressedMessages = 0;

$/ = "\n\n";
# Read input file as blocks

print STDERR "starting loop\n";
while ( <STDIN> ) {
  $inLines++;

  if ( ($outLines > $numOutRecs) && ($numOutRecs != -1) ) { last; } # limit processing to a certain number of output records ....

  $modCount = $inLines % 1000; 
  if ( $modCount == 0 ) {
    print STDERR "Rows processed: $inLines\n";
  }

  $msgin = $_;

  # find some values of interest

  $instanceHold = $instance;

  ($dts) = /^([^+]*)\+/; # timestamp is all of the chars in the message prior to the first '+'
  ($oserr) = /OSERR   :\s*(.*)/;
  ($level) = /LEVEL:\s*([^\s]*)/;
  ($instance) = /INSTANCE:\s*([^\s]*)/;
  ($db) = /DB   :\s*([^\s]*)/;
  ($node) = /NODE :\s*([^\s]*)/;
  ($message) = /MESSAGE :\s*([^\s]*)/;
  ($proc) = /PROC :\s*([^\s]*)/;
  ($sqlcode) = /sqlcode:\s*(.*)/;
  ($retcode) = /RETCODE :\s*(.*)/;
  ($function) = /FUNCTION:\s*(.*)/;
  if (! defined($function) ) { $function = ""};
  if (! defined($level) ) { $level = ""};
  if (! defined($instance) ) { $instance = ""};
  if (! defined($db) ) { $db = ""};
  if (! defined($message) ) { $message = ""};
  if (! defined($proc) ) { $proc = ""};
  if (! defined($oserr) ) { $oserr = ""};
  if (! defined($node) ) { $node = ""};

  if ( $instance eq "" ) { $instance = $instanceHold ; } # if instance is blank just assume same as previous

  if (! defined($retcode) ) { 
    $retcode = ""
  }
  else {
    if ( $retcode =~ /\,/) {
      $_ = $retcode;
      ($retcode_name,$retcode_message) = /([^\,]*),(.*)/;
    }
    else {
      $retcode_name = $retcode;
      $retcode_message = "";
    }
  }

  if ( $oserr ne "" ) {
    if ( $oserr =~ /\"/) {
      $_HOLD = $_;
      $_ = $oserr;
      ($oserr_name,$oserr_message) = /([^\"]*)(.*)/;
      $_ = $_HOLD;
    }
  }

  if ($message ne "") {
    $i = index($_,$message);
    $i = $i + length($message);
    $_ = substr($_,$i);
    ($messageSTR) = /\s*(.*)/;
  }
  elsif ($oserr ne "") {
    $message = $oserr_name;
    $messageSTR = $oserr_message;
  }
  elsif ($retcode ne "") {
    $message = $retcode_name;
    $messageSTR = $retcode_message;
  }
  elsif ( $function ne "") {
    $message = $function;
    $messageSTR = "";
  }
  else {
    if ( $msgin =~ /\s/ ) {
      ($message,$messageSTR) = ( $msgin =~ /(^[\s]*)\s(.*)/);
    }
    else {
      $message = $msgin;
      $messageSTR = "";
    }
  }

  if (! defined($messageSTR) ) { $messageSTR = ""};
  if ($diagLevel > 0) {
    print ">>>>> Record $inLines ($level - $instance - $db - $message) :\n $_ #####\n";
  }

  # Keep some totals ....

  if ( defined($levelCount{$level}) ) {
    $levelCount{$level}++;
  }
  else {
    $levelCount{$level} = 1;
    if ( $diagLevel > 1 ) { print ">>>>> First $level Record ($inLines - $level - $instance - $db - $message) :\n $_ #####\n"; }
  }

  # Exclude those records that are uninteresting .......  

  if ( $level eq "Event" ) { # Ignore all Event records
    $discLines++;
    $eventDisc++;
    $messageDropped{$message} = "Dropped";
    next;
  }

  # Exclude those records that are db2hmon connections being rejected .....

  if ( ($proc eq "db2hmon") && ($oserr =~ /\(146\)/) ) { # Health Monitor Error Type 146 records
    $msgSet = 1;
    $discLines++;
    $messageDropped{"db2hmon"} = "Dropped";
    if ( defined($messageCount{"db2hmon"}) ) {
      $messageCount{"db2hmon"}++;
    }
    else {
      $messageCount{"db2hmon"} = 1;
      $messageDesc{"db2hmon"} = "db2hmon Connection refused";
    }
    next;
  }

  # Look for discardable strings ....

  $_ = $msgin;
  $discRecord = "N";
  for ($i=0 ; $i <= $#discardStr ; $i++ ) {
    if ($_ =~ /$discardStr[$i]/) { # if the string is found in the record then ignore the record
      if ( $diagLevel > 1 ) { print "Matching String: Entry $i >$discardStr[$i]<\n"; }
      $discRecord = "Y";
      $stringDisc++;
      $message = $discardStr[$i];
      $msgSet = 1;

      if ( defined($messageCount{"$message"}) ) {
        $messageCount{"$message"}++;
      }
      else {
        $messageCount{"$message"} = 1;
        $messageDesc{"$message"} = "";
      }
      last;
    }  
  }
 
  if ($discRecord eq "Y") {
    $discLines++;
    $messageDropped{$message} = "Dropped";
    if ( $diagLevel > 1) { print "Record dropped as string match\n"; }
    next;
  }

  # Look for critical strings ....

  for ($i=0 ; $i <= $#criticalStr ; $i++ ) {
    if ($_ =~ /$criticalStr[$i]/) { # if the string is found in the record then it is critical
      if ( $diagLevel > 1 ) { print "Matching Critical String: Entry $i >$criticalStr[$i]<\n"; }
      $criticalStrCNT[$i]++;
      $stringCrit++;
      $l = index( $msgin, "FUNCTION:" ) ;
      if ( $l == -1 ) {
        $critMSG = "$machine $instance $db \n $msgin";
      }
      else {
        $m = substr( $msgin, $l - 1) ;
        $critMSG = "$machine $instance $db \n $m";
      }

      if ( defined($criticalMSG{"$critMSG"}) ) {
        $criticalMSGCNT{"$critMSG"}++;
      }
      else {
        $firstCriticalMSG{"$critMSG"} = $dts;
        $criticalMSGCNT{"$critMSG"} = 1;
        $criticalMSG{"$critMSG"} = "";
      }
    }
  }

  # Up message counts

  if ( $message ne "") {
    $msgSet = 1;
    if ( defined($messageCount{$message}) ) {
      $messageCount{$message}++;
    }
    else {
      $messageCount{$message} = 1;
      ($mdesc) = substr($messageSTR,0,40);
      $messageDesc{$message} = $mdesc;
      if ( $diagLevel > 1 ) { print ">>>>> First $message Record ($inLines - $level - $instance - $db - $message) :\n $_ #####\n"; }
    }
  }

  # At this stage just print the record .....

  if ( "$proc#$instance#$node#$db#$function#$retcode#$sqlcode" ne "####-1#") { # only log real messages
    if ( $diagLevel > 0 )  { print "Message key is \"$proc#$instance#$node#$db#$function#$retcode#$sqlcode\"\n"; }
    $logMessage_text = "$proc#$instance#$node#$db#$function#$retcode#$sqlcode";
    logMessage("$proc#$instance#$node#$db#$function#$retcode#$sqlcode");
    $retainKey{"$proc#$instance#$node#$db#$function#$retcode#$sqlcode"} = 1;
  }

  if ( $autoexcludeDays == 0 ) { # AUTOEXCLUDE not turned on so just print out all messages
    $outLines++;
    print STDOUT "$msgin";
  }
  elsif ( $recKey {"$proc#$instance#$node#$db#$function#$retcode#$sqlcode"} <= $autoexcludeDays ) { # print the message .....
    $outLines++;
    print STDOUT "$msgin";
  }
  else {
    $suppressedMessages++;
  }

}

$/ = "\n";

print STDERR "finished loop \n";

# sort out the critical messages ....

$critCOUNT = 0;

if ( !open (CRITOUT,">$criticalDir/diagLogCRIT_${machine}_${instance}.log") ) {
        die "Unable to open logs/diagLogCRIT_${machine}_${instance}.log\n$!\n";
   }
else {
  $firstCMSG = "Yes";
  foreach $key (sort by_key keys %criticalMSGCNT ) {
    if ( $criticalMSGCNT{$key} > 0 ) { # ie there were some of these ....
      if ( $firstCMSG eq "Yes" ) { # if there are some messages
        print CRITOUT "--------------------------------------------------------------\n";
        print CRITOUT "-- Critical messages issued by instance $instance on $machine \n";
        print CRITOUT "--     Note: This is only a summary of unique messages and not \n";
        print CRITOUT "--           all of the messages found.                        \n";
        print CRITOUT "--------------------------------------------------------------\n";
        $firstCMSG = "No";
      }
      print CRITOUT "First Occurrance: $firstCriticalMSG{$key} Total Occurrances: $criticalMSGCNT{$key}\n$key\n";
      $critCOUNT = $critCOUNT + $criticalMSGCNT{$key};
    }
  }
}

print STDERR "Records processed : $inLines \n";
print STDERR "Records discarded : $discLines \n";
print STDERR "        Events    : $eventDisc \n";
print STDERR "        Strings   : $stringDisc \n";
print STDERR "Records output    : $outLines \n\n";
print STDERR "Records Suppressed: $suppressedMessages \n\n";
print STDERR "Critical Messages : $critCOUNT \n\n";

if ($summary = "Yes") {
  print "Records processed : $inLines \n";
  print "Records discarded : $discLines \n";
  print "        Events    : $eventDisc \n";
  print "        Strings   : $stringDisc \n";
  print "Records output    : $outLines \n";
  print "Records Suppressed: $suppressedMessages \n\n";
  print "Critical Messages : $critCOUNT \n\n";
}

# Print out the counts ....

if ($summary = "Yes") {
  print "Level Counts      : \n";
}
print STDERR "Level Counts      : \n";
foreach $key (sort by_key keys %levelCount ) {
  if ($summary = "Yes") {
    printf "%-12s  %8s\n", $key, $levelCount{$key};
  }
  printf STDERR "%-12s  %8s\n", $key, $levelCount{$key};
}

print STDERR "\nThe following counts are for all input records - both retained and dropped\n";

if ( $msgSet == 1 ) {
  if ($summary = "Yes") {
    print "\nMessage Counts    : \n";
  }
  print STDERR "\nMessage Counts    : \n";
  foreach $key (sort by_key keys %messageCount ) {
    if ( ! defined($messageDropped{$key}) ) {
      if ($summary = "Yes") {
        printf "    %8s %-12s   %-40s\n", $messageCount{$key}, $key, $messageDesc{$key};
      }
      printf STDERR "    %8s %-12s   %-40s\n", $messageCount{$key}, $key, $messageDesc{$key};
    }
    elsif ($messageDropped{$key} eq "Dropped") {
      if ($summary = "Yes") {
        printf " ** %8s %-12s   %-40s\n", $messageCount{$key}, $key, $messageDesc{$key};
      }
      printf STDERR " ** %8s %-12s   %-40s\n", $messageCount{$key}, $key, $messageDesc{$key};
    }
    else {
      if ($summary = "Yes") {
        printf "    %8s %-12s   %-40s\n", $messageCount{$key}, $key, $messageDesc{$key};
      }
      printf STDERR "    %8s %-12s   %-40s\n", $messageCount{$key}, $key, $messageDesc{$key};
    }
  }
}

print STDERR "\nNote: ** indicates that at least one of this type of messages was dropped\n";

if ( $diagLevel > 1 ) { print "Saving the autoexclude table at the end .....\n"; }
if ( $diagLevel > 1 ) { print "Writing to ${autoexcludeDir}autoExclude_$currServerInstance\n"; }
if ( !open (AUTOEXCL,">${autoexcludeDir}autoExclude_$currServerInstance") ) {
  die "Unable to open ${autoexcludeDir}autoExclude_$currServerInstance -1\n$!\n";
}
else {
  $totalMessages = 0;
  $retainedMessages = 0;
  # Able to open the file so just output the detail ......
  if ( $diagLevel > 1 ) { print "About to save the data $#recKey .....\n"; }
  if ( $retain eq "Yes" ) { # keep all of the keys
    foreach $key (keys %recKey ) {
      $totalMessages++;
      $retainedMessages++;
      if ( $diagLevel > 1 ) { print "saving record >>>>$key<<<< with a value of $recKey{$key}\n"; }
      print AUTOEXCL "$recKey{$key}:$key\n";
    }
    close AUTOEXCL;
  }
  else {
    foreach $key (keys %recKey ) {
      $totalMessages++;
      if ( defined($retainKey{$key}) ) {
        $retainedMessages++;
        if ( $diagLevel > 1 ) { print "saving record >>>>$key<<<< with a value of $recKey{$key}\n"; }
        print AUTOEXCL "$recKey{$key}:$key\n";
      }
    }
  }
  close AUTOEXCL;
}


if ($summary = "Yes") {
  print "\nTotal AUTOEXCLUDE messages processed: $totalMessages\nTotal AUTOEXCLUDE messages retained: $retainedMessages\n";
}
print STDERR "\nTotal AUTOEXCLUDE messages processed: $totalMessages\nTotal AUTOEXCLUDE messages retained: $retainedMessages\n";

print STDERR "\nEnding $0\n";

exit(0);

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

