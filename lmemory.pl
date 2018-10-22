#!/usr/bin/perl
# --------------------------------------------------------------------
# lmemory.pl
#
# $Id: lmemory.pl,v 1.9 2018/10/21 21:01:50 db2admin Exp db2admin $
#
# Description:
# Script to print out DB2 memory usage
#
# Usage:
#   lmemory.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lmemory.pl,v $
# Revision 1.9  2018/10/21 21:01:50  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.8  2018/10/18 22:58:52  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.7  2018/10/17 01:17:55  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.6  2014/05/25 22:27:33  db2admin
# correct the allocation of windows include directory
#
# Revision 1.5  2011/08/12 02:39:21  db2admin
# add in total by owner
#
# Revision 1.3  2011/08/10 22:23:21  db2admin
# Alter the way that shared memory is identified
#
# Revision 1.2  2011/08/09 07:46:11  db2admin
# add in calculation for swap space
#
#
# --------------------------------------------------------------------

my $ID = '$Id: lmemory.pl,v 1.9 2018/10/21 21:01:50 db2admin Exp db2admin $';
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
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hxXSs -i <instance> [-v[v]]

       Script to print out DB2 memory usage

       convert from commonFunction.pl to commonFunctions.pm

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -S              : Produce the grand total line only and timestamp it
       -o              : order the output by process owner (may cause the script to fail if memory is too short)
       -i              : instance (or process owner) to list [basicall a filter on ps -ef - defaults to db2]
                         ALL will produce a report for all processes
       -x              : produce a file for processing by excel
       -X              : exclude the value specified in the ps -ef filter (option -i) [ignored if -i ALL specified]
       -v              : set debug level 

       This command basicall does the following:

       ps -ef | grep db2     (or instance if that parameter is provided)
       for each pid returned:
         pmap pid
       next

       At the end it provides a summary of the memory information found

       Because of the use of pmap this command must be run as root (or with sudo) to read processes not 
       started by you.

     \n";
}

# Set default values for variables

$silent = "No";
$instance = "db2";
$debugLevel = 0;
$ordered = "No";
$totalOnly = "No";
$excel = "No";
$exclude = "";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hvosXxSi:";

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
 elsif (($getOpt_optName eq "X"))  {
   $exclude = "-v ";
   if ( $silent ne "Yes") {
     print STDERR "The instance value will be excluded\n";
   }
 }
 elsif (($getOpt_optName eq "S"))  {
   $totalOnly = "Yes";
   if ( $silent ne "Yes") {
     print STDERR "Only the total line will be produced\n";
   }
 }
 elsif (($getOpt_optName eq "o"))  {
   $ordered = "Yes";
   if ( $silent ne "Yes") {
     print STDERR "Output will be ordered by process owner\n";
   }
 }
 elsif (($getOpt_optName eq "x"))  {
   $excel = "Yes";
   if ( $silent ne "Yes") {
     print STDERR "A file will be produced for processing by excel\n";
   }
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print STDERR "debug level has now been set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "i"))  {
   $instance = $getOpt_optValue;
   if ( $silent ne "Yes") {
     print STDERR "Only $instance processes will be selected\n";
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $instance eq "" ) {
     $instance = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print STDERR "Only $instance processes will be selected\n";
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

$u = `id`;
($user) = ($u =~ /.*\((.*)\) .*/) ;

if ( $ordered eq "Yes" ) { 
  if ( $instance eq "ALL" ) {
    if (! open (PSEFPIPE,"ps -ef | sort | "))  { die "Can't run ps! $!\n"; }
  }
  else {
    if (! open (PSEFPIPE,"ps -ef | sort | grep $exclude $instance | "))  { die "Can't run ps! $!\n"; }
  }
}
else {
  if ( $instance eq "ALL" ) {
    if (! open (PSEFPIPE,"ps -ef | "))  { die "Can't run ps! $!\n"; }
  }
  else {
    if (! open (PSEFPIPE,"ps -ef | grep $exclude $instance | "))  { die "Can't run ps! $!\n"; }
  }
}

if ( $totalOnly eq "No" ) {
  if ( $excel eq "Yes" ) {
    # Print Headings ....
    print "PID|Owner|ADDR|SWAP|SIZE|MTYPE|CAT|SOURCE\n";
  }
  else {
    # Print Headings ....
    printf "%-5s %-10s %-12s %-12s %-12s %43s %54s \n",
           '','','','','','.............. Shared Memory ..............','................... Private Memory ...................';
    printf "%-5s %-10s %-12s %-12s %-12s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s %-10s\n",
           'PID','Swap','Calc Total','Priv Total','Shared Total','Code','Data','Data NoRes','Unknown','Code','Data (RW)','Data (Stk)','Unknown', 'Owner';
    printf "%-5s %-10s %-12s %-12s %-12s %10s %10s %10s %10s %10s %-10s %10s %-10s %-10s\n",
           '-----','----------','------------','------------','------------','----------','----------',
           '----------','----------','----------','----------','----------','----------','----------';
  }
}

$GT_processType{"Private - Code"} = 0;
$GT_processType{"Private - Data"} = 0;
$GT_processType{"Private - Data (stack)"} = 0;
$GT_processType{"Private - Unknown"} = 0;

$GT_swapsize = 0 ;
$GT_processMemSizeK = 0 ;
$GT_processMemSizeK_shared = 0 ;
$GT_processMemSizeK_private = 0 ;

$convert = "Yes";

while (<PSEFPIPE>) {
  chomp $_;
  if ( $debugLevel > 0 ) { print "ps -ef: $_\n"; }

  $input = $_;
  @psefinfo = split(" ") ;

  $powner = $psefinfo[0];

  $powner = substr($powner,0,10);

  $pid = $psefinfo[1];
  $ppid = $psefinfo[2];
 
  if ($debugLevel > 1) {
    print "Owner=$powner, PID=$pid, PPID=$ppid\n";
  }

  if ( ! defined($processSwap{$powner}) ) {
    $processSwap{$powner} = 0;
  }

  $processType{"Shared - Code"} = 0;
  $processType{"Shared - Data"} = 0;
  $processType{"Shared - Data NoRes"} = 0;
  $processType{"Shared - Unknown"} = 0;
  $processType{"Private - Code"} = 0;
  $processType{"Private - Data"} = 0;
  $processType{"Private - Data (stack)"} = 0;
  $processType{"Private - Unknown"} = 0;

  $processMemSizeK = 0 ;
  $processMemSizeK_shared = 0 ;
  $processMemSizeK_private = 0 ;
  $processSwapSize_private = 0;

  $permissionDenied = "No";

  if (! open (PMAPPIPE,"pmap -S $pid 2>&1 | "))  { die "Can't run pmap - are you running as root? $!\n"; }
 
  while (<PMAPPIPE>) {
    chomp $_;

    if ( $debugLevel > 0 ) { print "PMAP: $_\n"; }

    if ( $_ =~ /Kbytes/ ) { # heading with Kbytes found
      $convert = "No";
      next;
    }

    if ( trim($_) eq "" ) { next; }   # skip blank lines

    if ( $_ =~ /^pmap:.*no such process/ ) {
      # ignore this one as process is already gone
      next;
    }

    if ( $_ =~ /^pmap:.*permission denied/ ) {
      # ignore this one as process is not readable by this login
      $permissionDenied = "Yes";
      next;
    }

    @pmapinfo = split(" ", $_, 5) ;
  
    $memaddr = $pmapinfo[0];
    if ( $memaddr =~ /:$/ ) { # if it ends in a colon then ignore the line - its just the process name
      next;
    }

    $memsize = $pmapinfo[1];

    if ( $memaddr eq "total" ) { # total line
      $totMemory = $pmapinfo[1];
      next;
    }

    if ( $_ =~ "total Kb" ) { # total line
      $totMemory = $pmapinfo[1];
      print ">>>>> $totMemory\n";
      print ">>>>> $_\n";
      next;
    }

    if ( $pmapinfo[0] =~ "^------" ) { next; }

    $swapsize = $pmapinfo[2];
    $memtype = $pmapinfo[3];
    $memsource = $pmapinfo[4];

    # adjust the size to be consistent
    # not much use at the moment as it is converting K to K

    $memSizeK = 0;
    if ( $convert eq "Yes" ) {
      if ( $memsize =~ /K$/ ) { # K already 
        ($x) = ( $memsize =~ /(\d*)K$/ ) ; 
        $memSizeK = $x;
      }
    }
    else { # should already be in Kb
      $memSizeK = $memsize;
    }

    # generate acategory of memory

    $sharedFlag = "Yes";

    if ( $memtype =~ /s/ ) { # shared
      if    ( $memtype eq "r-xs-" ) { $type = "Shared - Code" ; }
      elsif ( $memtype eq "rwxs-" ) { $type = "Shared - Data" ; } 
      elsif ( $memtype eq "rwxsR" ) { $type = "Shared - Data NoRes" ; } 
      else  { $type = "Shared - Unknown" ; } 
    }
    else { # private storage
      $sharedFlag = "No";
      if    ( $memtype eq "r-x--" ) { $type = "Private - Code" ; }
      elsif ( $memtype eq "rwx--" ) { $type = "Private - Data" ; } 
      elsif ( $memtype eq "rw---" ) { $type = "Private - Data (stack)" ; } 
      else  { $type = "Private - Unknown" ; }
    }

    if ( $debugLevel > 0 ) { print "memAddr= $memaddr, memsize=$memsize, memtype=$memtype, type=$type, memsource=$memsource\n"; }

    # Accumulate memory values for this process

    $processType{$type} += $memSizeK ; 
    $processMemSizeK += $memSizeK ; 
    if ( $sharedFlag eq "Yes" ) { # shared
      $processMemSizeK_shared += $memSizeK ; 
    }
    else {
      $processMemSizeK_private += $memSizeK ; 
      $processSwapSize_private += $swapsize;
    }
    if ( $excel eq "Yes") {
      print "$pid|$powner|$memaddr|$swapsize|$memsize|$memtype|$type|$memsource\n";
    }

  }

  if ( $totalOnly eq "No" ) {
    if ( $excel ne "Yes" ) {
      if ( $processMemSizeK != 0 ) {
        printf "%-5s %10s %12s %12s %12s %10s %10s %10s %10s %10s %10s %10s %10s %-10s\n",
               $pid,$processSwapSize_private,$processMemSizeK,$processMemSizeK_private,
               $processMemSizeK_shared,$processType{"Shared - Code"},
               $processType{"Shared - Data"},$processType{"Shared - Data NoRes"},$processType{"Shared - Unknown"},
               $processType{"Private - Code"},$processType{"Private - Data"},$processType{"Private - Data (stack)"},
               $processType{"Private - Unknown"} , $powner;
      }
      else {
        if ( $permissionDenied eq "Yes") {
          if ( $silent ne "Yes" ) {
            printf "%-5s %-40s\n",
                   $pid,"$user does not have access to this process ($powner) - perhaps use sudo or use -s to supress this message";
          }
        }
        else {
          if ( $pid ne "PID" ) {
            printf "%-5s %-40s\n",
                   $pid,'No memory values returned ';
          }
        }
      }
    }
  }

  $GT_processType{"Private - Code"} += $processType{"Private - Code"};
  $GT_processType{"Private - Data"} += $processType{"Private - Data"};
  $GT_processType{"Private - Data (stack)"} += $processType{"Private - Data (stack)"};
  $GT_processType{"Private - Unknown"} += $processType{"Private - Unknown"};

  if ( $sharedFlag eq "No" ) { # Private swap 
    $GT_swapsize += $processSwapSize_private ;
    $processSwap{$powner} += $processSwapSize_private ;
  }
  $GT_processMemSizeK += $processMemSizeK ;
  $GT_processMemSizeK_shared += $processMemSizeK_shared ;
  $GT_processMemSizeK_private += $processMemSizeK_private ;

}

print "\n";
if ( $instance ne "db2" ) {
  if ( $totalOnly eq "Yes" ) {
    printf "%-19s %12s %12s %12s %10s %10s %10s %10s %10s %10s %10s %-10s\n",
             $Now,$GT_processMemSizeK,$GT_processMemSizeK_private,
             $GT_processMemSizeK_shared,"",
             "","","",
             $GT_processType{"Private - Code"},$GT_processType{"Private - Data)"},$GT_processType{"Private - Data (stack)"},
             $GT_processType{"Private - Unknown"}, $instance ;
  }
  else {
    if ( $excel ne "Yes" ) {
      printf "%-5s %10s %12s %12s %12s %10s %10s %10s %10s %10s %10s %10s %10s %-10s\n",
               "TOTAL",$GT_swapsize,$GT_processMemSizeK,$GT_processMemSizeK_private,
               $GT_processMemSizeK_shared,"",
               "","","",
               $GT_processType{"Private - Code"},$GT_processType{"Private - Data"},$GT_processType{"Private - Data (stack)"},
               $GT_processType{"Private - Unknown"}, $instance ;
    }    
  }
}
else {
  if ( $totalOnly eq "Yes" ) {
    printf "%-19s %12s %12s %12s %10s %10s %10s %10s %10s %10s %10s %10s\n",
             $Now,$GT_processMemSizeK,$GT_processMemSizeK_private,
             $GT_processMemSizeK_shared,"",
             "","","",
             $GT_processType{"Private - Code"},$GT_processType{"Private - Data"},$GT_processType{"Private - Data (stack)"},
             $GT_processType{"Private - Unknown"} ;
  }
  else {
    if ( $excel ne "Yes" ) {
      printf "%-5s %10s %12s %12s %12s %10s %10s %10s %10s %10s %10s %10s %10s\n",
               "TOTAL",$GT_swapsize,$GT_processMemSizeK,$GT_processMemSizeK_private,
               $GT_processMemSizeK_shared,"",
               "","","",
               $GT_processType{"Private - Code"},$GT_processType{"Private - Data"},$GT_processType{"Private - Data (stack)"},
               $GT_processType{"Private - Unknown"} ;
    }
  }
}

print "\nPer Process Owner Statistics:\n\n";

printf "%-10s  %15s\n",'Owner','Swap Size (Kb)';
foreach $i ( keys %processSwap ) {
  printf "%-10s  %15s\n",$i,$processSwap{$i};
}
