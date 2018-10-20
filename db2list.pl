#!/usr/bin/perl
# --------------------------------------------------------------------
# db2list.pl
#
# $Id: db2list.pl,v 1.7 2018/10/18 22:30:24 db2admin Exp db2admin $
#
# Description:
# List out all databases on a machine
#
# $Name:  $
#
# ChangeLog:
# $Log: db2list.pl,v $
# Revision 1.7  2018/10/18 22:30:24  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.5  2018/10/16 03:37:27  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.4  2015/03/06 06:34:18  db2admin
# adjust to allow for instance homes that are not local logins
#
# Revision 1.3  2014/05/25 22:18:11  db2admin
# correct the allocation of windows include directory
#
# Revision 1.2  2010/06/21 05:40:12  db2admin
# minor comment change to force retention of the file permissions
#
# Revision 1.1  2010/06/21 05:34:52  db2admin
# Initial revision
#
# 
#
# --------------------------------------------------------------------

my $ID = '$Id: db2list.pl,v 1.7 2018/10/18 22:30:24 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hs [-A or -I or -i <instance>] [-L] [-R] [-X] [-D Install Directory] 
                               [-C configuration file] [DEBUG | [-v]v] ] 

      List out all databases on a machine

      Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode 
       -L              : Connect to local databases (default)
       -X              : Do NOT list out current Instance (reverse of -I)
       -D              : Directory that db2 was installed into 
       -R              : Connect to remote databases
       -A              : Process all instances for the server (default)
       -I              : Only use the current Instance
       -C              : File containing configuration details 
       -i <instance>   : Use the indicated instance
       -v or DEBUG     : set debug level

       Note: if -X and -I are specified then the last one entered will be processed

     \n";
}

# Set default values for variables

$silent = "No";
$command = "";
$inFile = "";
$connect_to_remote = "No";
$connect_to_local = "XXX";
$instance = "XXX";
if ( $OS ne "Windows" ) {
  $db2ilist_dir=`which db2ilist`;
}
else {
  $db2ilist_dir='db2ilist';
}
$configFile = "";
$installDir_set = "No";
$debugLevel = 0;
$exclude = 'No';             

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsSvO:ALRXIi:D:C:|^DEBUG";

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
 elsif (($getOpt_optName eq "DEBUG") || ($getOpt_optName eq "v") )  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( $silent ne "Yes") {
     print "Only Instance $getOpt_optValue will be processed\n";
   }
   $instance = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "D"))  {
   $installDir_set = "Yes";
   if ( $silent ne "Yes") {
     print "db2ilist will be executed from $getOpt_optValue\n";
   }
   if ( $OS eq "Windows" ) {
     $db2ilist_dir = "$getOpt_optValue\\db2ilist";
   }
   else {
     $db2ilist_dir = "$getOpt_optValue/db2ilist";
   }
 }
 elsif (($getOpt_optName eq "C"))  {
   if ( $silent ne "Yes") {
     print "Configuration file $getOpt_optValue will be used\n";
   }
   $configFile = "$getOpt_optValue";
 }
 elsif (($getOpt_optName eq "A"))  {
   if ( $silent ne "Yes") {
     print "All instances will be processed\n";
   }
   $instance = "";
 }
 elsif (($getOpt_optName eq "I"))  {
   $instance = $ENV{'DB2INSTANCE'};
   if ( $silent ne "Yes") {
     print STDERR "Instance $instance will be processed\n";
   }
 }
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print STDERR "The current instance will be excluded\n";
   }
   $exclude = "Yes";
 }
 elsif (($getOpt_optName eq "L"))  {
   if ( $silent ne "Yes") {
     print STDERR "Local databases will be connected to\n";
   }
   $connect_to_local = "Yes";
 }
 elsif (($getOpt_optName eq "R"))  {
   if ( $silent ne "Yes") {
     print STDERR "Remote databases will be connected to\n";
   }
   $connect_to_remote = "Yes";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   usage ("Parameter $getOpt_optValue is invalid");
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

if ( $instance eq "XXX" ) {
  if ( $silent ne "Yes") {
    print "All Instances will be processed\n";
  }
  $instance = "";
}

my $origInstance = $ENV{'DB2INSTANCE'};

if ( $connect_to_local eq "XXX" ) {
  if ( $silent ne "Yes") {
    print "Local databases will be connected to\n";
  }
  $connect_to_local = "Yes";
}

# if configuration file set then load up some details ....

if ( $configFile ne "" ) {
  if ( $installDir_set eq "No" ) {     # if the insatll directory has been set then skip the config entry
    if ( open (CONFFILE,"<$configFile") ) {
      while ( <CONFFILE> ) {
        if ( $debug eq "Yes" ) { print ">> $_\n"; }
        @conffile_line = split(/#/);
        chomp $conffile_line[1];
        if ( $machine eq $conffile_line[0] ) { # found the configuration line for this machine
          if ( $silent ne "Yes" ) {
            print "Directory $conffile_line[1] will be used to run db2ilist from\n";
          }
          if ( $OS eq "Windows" ) {
            $db2ilist_dir = "$conffile_line[1]\\db2ilist";
            $db2_dir = "$conffile_line[1]\\";
          }
          else {
            $db2ilist_dir = "$conffile_line[1]/db2ilist";
          }
        }
      }
    }
    else {
      die "Configuration file $configFile does not exist or is not accessible\n";
    }
  }
  else {
    print "Install Directory has been set so configuration file will NOT be used\n";
  }
}

# identify all of the Instances on the box .....
if ( $inFile ne "" ) {
  if (! open (INSTPIPE,"<$inFile"))  { die "Can't open $inFile! $!\n"; }
}
else {
  if (! open (INSTPIPE,"$db2ilist_dir | "))  { die "Can't run db2ilist! $!\n"; }
}

while (<INSTPIPE>) {
    if ( $_ =~ /Instance Error encountered/) { next; } # skip this message ....

    if ( $debug eq "Yes" ) { print ">$_\n"; }

    $inst = $_;
    chomp $inst;

    if ( $OS ne "Windows" ) {
      $homeDir=`grep $inst /etc/passwd | cut -d":" -f6`;
      if ( $homeDir eq "" ) {
        $homeDir = `cd ; pwd`;
      }
      chomp $homeDir;
      $excFile="$homeDir/DBPollexceptions.lst";
    }
    else {
      $homeDir="c:";
      $excFile="$homeDir\\DBPollexceptions.lst";
    }

    # Populate the exceptions table
    %dbexceptions = (); # initialise array
    if ( open (EXCPPIPE,"<$excFile"))  { 
      while ( <EXCPPIPE> ) {
        $db_exc = $_;
        chomp $db_exc;
        $dbexceptions{"$db_exc"} = "ignore"; 
      }
      close EXCPPIPE;
    }

    if ( $instance ne "" && $instance ne $inst) { 
      if ( $exclude eq 'Yes' ) { # only printing databases from other instances
      }
      else {
        # skip this instance
        next;
      }
    }
    else { # $instance cound be blank OR eq $inst
      if ( $instance eq $inst ) { 
        if ( $exclude eq 'Yes' ) { # skip when it matches
          next;
        }
      }
      else { # $instance is blank
        if ( $inst eq $origInstance ) { # instance is the original instance
          if ( $exclude eq 'Yes' ) { # skip the entry
            next;
          }
        }
      }
    }

    $ENV{'DB2INSTANCE'} = $inst;

    # Run the command file and process out the databases .....
    if ( $OS eq "Windows" ) {
      if ( ! open (CMDFILE, ">tmpcmd1_db2poll.bat" ) ) {die "Unable to allocate tmpcmd1_db2poll.bat\n $!\n"; }
      print CMDFILE "set DB2INSTANCE=$inst\n";
      print CMDFILE "db2 list db directory >tmpcmd1_db2poll.out\n";
      print CMDFILE "exit\n";
      close CMDFILE;
      $x = `$db2_dir\db2cmd -c -i -w tmpcmd1_db2poll.bat`;
      if (! open (DBPIPE,"<tmpcmd1_db2poll.out"))  { die "Can't open tmpcmd1_db2poll.out !\n $!\n"; }
    }
    else {
      if (! open (DBPIPE,". $homeDir/sqllib/db2profile; db2 list db directory | "))  { die "Can't run db2 list ! $!\n"; }
    }

    while (<DBPIPE>) {

      if ( $debug eq "Yes" ) { print "### $_\n"; }
    
      $linein = $_;
      chomp $linein;
      @cmdout_info = split(/=/,$linein);
      $ENV{'DB2INSTANCE'} = $inst;

      if ($linein =~ /Database alias/) {
        $dbalias = trim($cmdout_info[1]);
      }
      elsif ($linein =~ /Database name/) {
        $dbname = trim($cmdout_info[1]);
      }
      elsif ($linein =~ /Directory entry type/) {
        if ($linein =~ /Indirect/) { # local database
          if ( $connect_to_local eq "Yes" ) {
            print ">>>> $inst\\$dbalias (local)\n";
          }
        }
        else { # remote database
          print ">>>> $inst\\$dbalias (remote)\n";
        }
      }
    }
    $lastInst = $inst;
}

# Print out the OpenView messages if requested ....

if ( $openView eq "Yes") {
  foreach $key (sort by_key keys %instDBS ) {
    print "$Now : Unable to connect to $instDBS{$key} on instance $key ($machine)\n";
  }
}

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}


