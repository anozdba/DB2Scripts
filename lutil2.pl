#!/usr/bin/perl
# --------------------------------------------------------------------
# ltssnap.pl
#
# $Id: ltssnap.pl,v 1.5 2016/07/11 05:10:38 db2admin Exp db2admin $
#
# Description:
# Script to list out the tablespacespace snap information
#
# Usage:
#   ltssnap.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ltssnap.pl,v $
# Revision 1.5  2016/07/11 05:10:38  db2admin
# clear data if requested to
#
# Revision 1.4  2016/06/15 01:24:01  db2admin
# Exclude some duplicate token names
# Add extra total that excludes asynchronous elapsed times
#
# Revision 1.3  2016/06/15 01:07:52  db2admin
# only retain required fields
#
#
# --------------------------------------------------------------------

use strict;

my $machine;   # machine we are running on 
my $OS;        # OS running on
my $scriptDir; # directory the script ois running out of
my $tmp ;
my $machine_info;
my @mach_info;

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scrxipts';
    $tmp = rindex($0,'\\');
    if ($tmp > -1) {
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
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
}

use lib "$scriptDir";

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $myDate_debugLevel);

# -------------------------------------------------------------------

# variables to retain ....

my %retainedKeywords = (
    'Asynchronous pool data page reads' =>  1,
    'Asynchronous pool data page writes' =>  1,
    'Asynchronous pool index page reads' =>  1,
    'Asynchronous pool index page writes' =>  1,
    'Asynchronous pool xda page reads' =>  1,
    'Asynchronous pool xda page writes' =>  1,
    'Buffer pool data logical reads' =>  1,
    'Buffer pool data physical reads' =>  1,
    'Buffer pool data writes' =>  1,
    'Buffer pool ID currently in use' =>  1,
    'Buffer pool index logical reads' =>  1,
    'Buffer pool index physical reads' =>  1,
    'Buffer pool index writes' =>  1,
    'Buffer pool temporary data logical reads' =>  1,
    'Buffer pool temporary data physical reads' =>  1,
    'Buffer pool temporary index logical reads' =>  1,
    'Buffer pool temporary index physical reads' =>  1,
    'Buffer pool temporary xda logical reads' =>  1,
    'Buffer pool temporary xda physical reads' =>  1,
    'Buffer pool xda logical reads' =>  1,
    'Buffer pool xda physical reads' =>  1,
    'Buffer pool xda writes' =>  1,
    'Direct read requests' =>  1,
    'Direct reads' =>  1,
    'Direct reads elapsed time (ms)' =>  1,
    'Direct write elapsed time (ms)' =>  1,
    'Direct write requests' =>  1,
    'Direct writes' =>  1,
    'No victim buffers available' =>  1,
    'Number of files closed' =>  1,
    'Tablespace ID' =>  1,
    'Tablespace name' =>  1,
    'Total buffer pool read time (millisec)' =>  1,
    'Total buffer pool write time (millisec)' =>  1,
    'Total elapsed asynchronous read time' =>  1,
    'Total elapsed asynchronous write time' =>  1
);

my $ID = '$Id: ltssnap.pl,v 1.5 2016/07/11 05:10:38 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs -d <database> [-v[v]] i[-c] [-C] [-z] [-t <tablespace>] [-p]

       Script to identify lock realtionships as displayed by db2pd

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (in this program only suppesses parameter messages)
       -d              : database to query
       -c              : delta values are cummulative from first run
       -C              : start accumulating again
       -p              : show previous values
       -t              : tablespace to list
       -z              : only display entries that have changed
       -v              : set debug level


       NOTE: Essentially just reformats the output of the following command:

             db2 get snapshot for tablespace on <database>
\n";

}


my $silent = "No";
my $debugLevel = 0;
my $cummulative = 0;
my $clear = 0;
my $onlyChanged = 0;
my $database = '';
my $tablespace = '';
my $showPrevious = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsvcCzpd:t:") ) {
 if (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Databse $getOpt_optValue will be checked\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "Tablespace $getOpt_optValue will be listed\n";
   }
   $tablespace = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "c"))  {
   $cummulative = 1;
   if ( $silent ne "Yes") {
     print "Data will be accumulated\n";
   }
 }
 elsif (($getOpt_optName eq "p"))  {
   $showPrevious = 1;
   if ( $silent ne "Yes") {
     print "Historical data will be displayed\n";
   }
 }
 elsif (($getOpt_optName eq "C"))  {
   $clear = 1;
   if ( $silent ne "Yes") {
     print "Historic data will be cleared\n";
   }
 }
 elsif (($getOpt_optName eq "z"))  {
   $onlyChanged = 1;
   if ( $silent ne "Yes") {
     print "Only changed data will be displayed\n";
   }
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug Level set to $debugLevel\n";
   }
 }
 else { # handle other entered values ....
   usage ("Parameter $getOpt_optName : This parameter is unknown");
   exit;
 }
}

# ----------------------------------------------------
# -- End of Parameter Section
# ----------------------------------------------------

chomp $machine;
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
my $NowTS = "$year.$month.$day $hour:$minute:$second";

if ( ($database eq '') ) {
  usage ("Database parameter must be entered");
  exit;
}

print "Application Snapshot Summary ($NowTS) .... \n\n";

# check if history should be cleared

if ( $clear ) {
  my $a = unlink 'ltssnap.hist';
}

# Load up the historic values

print "Loading old comparison values\n";

my @oldSnap_values = (); # clear out array
my %hist_values = ();
my $TSNAME = ''; 
if ( open(OLDSNAP,"<ltssnap.hist") ) { 
  while (<OLDSNAP>) {
    chomp $_;
    @oldSnap_values = split(/\|/,$_);
    if ( $oldSnap_values[0] eq "SnapTime" ) {
      print "Delta Values obtained are from $oldSnap_values[1]\n";
    }
    else {
      if ($debugLevel > 0 ) { print "$_\n"; }
      my @tmpval ;
      foreach my $tmp (@oldSnap_values) { # loop through the values
        @tmpval = split('=', $tmp);
        if ( $tmpval[0] eq 'TSNAME' ) { # label for this record
          $TSNAME = $tmpval[1];
          if ( ($TSNAME ne $tablespace ) && ( $tablespace ne '') ) { 
            # a spefic tablespace is being checked so only load up that tablespace
            last; # skip to the next tablespace
          }
          else {
            print "$TSNAME history loaded\n";
          }
        }
        else {
          $hist_values{$TSNAME}{$tmpval[0]} = $tmpval[1];
        }
      }
    }
  }
  close OLDSNAP;
}
else {
  print "No history values to display \n";
}

# only overwrite the comparison values if necessary

if ( ! $cummulative ) {
  if (! open (NEWSNAP,">ltssnap.hist"))  { print "Can't create the history file ltssnap.hist! $!\n"; }
  else { print NEWSNAP "SnapTime|$NowTS|SnapTime\n"; } 
}

my @fields;
my $returnCode;
my $headingPrinted = 0;

if (! open (TSSNAP,"db2 get snapshot for tablespaces on $database |"))  { die "Can't run db2 get snapshot! $!\n"; }

my $processSection = "";
my %appHandl = ();  # initialise the array
my %blocked = ();
my %granted = ();
my @parms = ();     # array to hold the parameters
my %rep_values = (); #  Array containing the report values 
my $name = '';
my $value = '';
my $rep_tablespace = '';
my $snapHistoryEntry = '';
my $BP_data_changed = 0;
my $BP_index_changed = 0;
my $BP_xda_changed = 0;
my $Directio_changed = 0;
my $Elapsed_changed = 0;
my $Elapsed_nonAsynch_changed = 0;
my $Elapsed_written = 0;

while (<TSSNAP>) {
  if ( $debugLevel > 1 ) { print ">>>>>$_"; }

  chomp $_; # get rid of the CRLF
  @parms = split('=',$_,2);
  $name = trim($parms[0]);
  $value = trim($parms[1]);
  
  if ( $name eq 'Tablespace name' ) { 
    $rep_tablespace = uc($value);
    $processSection = 'TS';
    if ( $debugLevel > 0 ) { print "Tablespace: $rep_tablespace found\n"; }
    next;
  }
  
  if ( ($rep_tablespace eq $tablespace ) || ( $tablespace eq '') ) {   # tablespace has been selected for processing
    if ( $debugLevel > 0 ) { print "Tablespace: $rep_tablespace being processed : $_\n"; }
    $rep_values{$name} = $value;
    if ( $name eq 'Number of files closed') { 
      
      $BP_data_changed = 0  ;
      # check Data BP
      if ( ($rep_values{'Buffer pool data logical reads'}+$rep_values{'Buffer pool data physical reads'} +
            $rep_values{'Buffer pool temporary data logical reads'}+$rep_values{'Buffer pool temporary data physical reads'} +
            $rep_values{'Buffer pool data writes'}+$rep_values {'Asynchronous pool data page reads'}+$rep_values{'Asynchronous pool data page writes'}) != 
           ($hist_values{$rep_tablespace}{'Buffer pool data logical reads'} + $hist_values{$rep_tablespace}{'Buffer pool data physical reads'} + 
            $hist_values{$rep_tablespace}{'Buffer pool temporary data logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool temporary data physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool data writes'}+$hist_values{$rep_tablespace}{'Asynchronous pool data page reads'} +
            $hist_values{$rep_tablespace}{'Asynchronous pool data page writes'})) { 
        $BP_data_changed = ($rep_values{'Buffer pool data logical reads'}+$rep_values{'Buffer pool data physical reads'} +
            $rep_values{'Buffer pool temporary data logical reads'}+$rep_values{'Buffer pool temporary data physical reads'} +
            $rep_values{'Buffer pool data writes'}+$rep_values {'Asynchronous pool data page reads'}+$rep_values{'Asynchronous pool data page writes'}) -
           ($hist_values{$rep_tablespace}{'Buffer pool data logical reads'} + $hist_values{$rep_tablespace}{'Buffer pool data physical reads'} + 
            $hist_values{$rep_tablespace}{'Buffer pool temporary data logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool temporary data physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool data writes'}+$hist_values{$rep_tablespace}{'Asynchronous pool data page reads'} +
            $hist_values{$rep_tablespace}{'Asynchronous pool data page writes'})  ;
      }
      $BP_index_changed = 0  ;
      # check Index BP
      if ( ($rep_values{'Buffer pool index logical reads'}+$rep_values{'Buffer pool index physical reads'} +
            $rep_values{'Buffer pool temporary index logical reads'}+$rep_values{'Buffer pool temporary index physical reads'} +
            $rep_values{'Buffer pool index writes'}+$rep_values {'Asynchronous pool index page reads'} +
            $rep_values{'Asynchronous pool index page writes'}) != 
           ($hist_values{$rep_tablespace}{'Buffer pool index logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool index physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool temporary index logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool temporary index physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool index writes'}+$hist_values{$rep_tablespace}{'Asynchronous pool index page reads'} +
            $hist_values{$rep_tablespace}{'Asynchronous pool index page writes'})) { 
        $BP_index_changed = ($rep_values{'Buffer pool index logical reads'}+$rep_values{'Buffer pool index physical reads'} +
            $rep_values{'Buffer pool temporary index logical reads'}+$rep_values{'Buffer pool temporary index physical reads'} +
            $rep_values{'Buffer pool index writes'}+$rep_values {'Asynchronous pool index page reads'} +
            $rep_values{'Asynchronous pool index page writes'}) -
           ($hist_values{$rep_tablespace}{'Buffer pool index logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool index physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool temporary index logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool temporary index physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool index writes'}+$hist_values{$rep_tablespace}{'Asynchronous pool index page reads'} +
            $hist_values{$rep_tablespace}{'Asynchronous pool index page writes'})  ;
      }
      # check XDA BP
      $BP_xda_changed = 0  ;
      if ( ($rep_values{'Buffer pool xda logical reads'}+$rep_values{'Buffer pool xda physical reads'} +
            $rep_values{'Buffer pool temporary xda logical reads'}+$rep_values{'Buffer pool temporary xda p  hysical reads'} +
            $rep_values{'Buffer pool xda writes'}+$rep_values {'Asynchronous pool xda page reads'} +
            $rep_values{'Asynchronous pool xda page writes'}) != 
           ($hist_values{$rep_tablespace}{'Buffer pool xda logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool xda physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool temporary xda logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool temporary xda p  hysical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool xda writes'}+$hist_values{$rep_tablespace}{'Asynchronous pool xda page reads'} +
            $hist_values{$rep_tablespace}{'Asynchronous pool xda page writes'}) ) { 
        $BP_xda_changed = ($rep_values{'Buffer pool xda logical reads'}+$rep_values{'Buffer pool xda physical reads'} +
            $rep_values{'Buffer pool temporary xda logical reads'}+$rep_values{'Buffer pool temporary xda p  hysical reads'} +
            $rep_values{'Buffer pool xda writes'}+$rep_values {'Asynchronous pool xda page reads'} +
            $rep_values{'Asynchronous pool xda page writes'}) -
           ($hist_values{$rep_tablespace}{'Buffer pool xda logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool xda physical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool temporary xda logical reads'}+$hist_values{$rep_tablespace}{'Buffer pool temporary xda p  hysical reads'} +
            $hist_values{$rep_tablespace}{'Buffer pool xda writes'}+$hist_values{$rep_tablespace}{'Asynchronous pool xda page reads'} +
            $hist_values{$rep_tablespace}{'Asynchronous pool xda page writes'})  ;
      }
      # check Direct IO
      $Directio_changed = 0;
      if ( ($rep_values{'Direct read requests'}+$rep_values{'Direct reads'} +
            $rep_values{'Direct write requests'}+$rep_values{'Direct writes'}) != 
           ($hist_values{$rep_tablespace}{'Direct read requests'}+$hist_values{$rep_tablespace}{'Direct reads'} +
            $hist_values{$rep_tablespace}{'Direct write requests'}+$hist_values{$rep_tablespace}{'Direct writes'}) ) { 
        $Directio_changed = ($rep_values{'Direct read requests'}+$rep_values{'Direct reads'} +
            $rep_values{'Direct write requests'}+$rep_values{'Direct writes'}) -
           ($hist_values{$rep_tablespace}{'Direct read requests'}+$hist_values{$rep_tablespace}{'Direct reads'} +
            $hist_values{$rep_tablespace}{'Direct write requests'}+$hist_values{$rep_tablespace}{'Direct writes'})  ;
      }
      # check Elapsed Times
      $Elapsed_changed = 0  ;
      if ( ($rep_values{'Total buffer pool read time (millisec)'}+$rep_values{'Total buffer pool write time (millisec)'} +
            $rep_values {'Total elapsed asynchronous read time'}+$rep_values{'Total elapsed asynchronous write time'} +
            $rep_values{'Direct reads elapsed time (ms)'}+$rep_values{'Direct write elapsed time (ms)'}) != 
           ($hist_values{$rep_tablespace}{'Total buffer pool read time (millisec)'}+$hist_values{$rep_tablespace}{'Total buffer pool write time (millisec)'} +
            $hist_values{$rep_tablespace}{'Total elapsed asynchronous read time'}+$hist_values{$rep_tablespace}{'Total elapsed asynchronous write time'} +
            $hist_values{$rep_tablespace}{'Direct reads elapsed time (ms)'}+$hist_values{$rep_tablespace}{'Direct write elapsed time (ms)'}) ) { 
        $Elapsed_changed = ($rep_values{'Total buffer pool read time (millisec)'}+$rep_values{'Total buffer pool write time (millisec)'} +
            $rep_values {'Total elapsed asynchronous read time'}+$rep_values{'Total elapsed asynchronous write time'} +
            $rep_values{'Direct reads elapsed time (ms)'}+$rep_values{'Direct write elapsed time (ms)'}) -
           ($hist_values{$rep_tablespace}{'Total buffer pool read time (millisec)'}+$hist_values{$rep_tablespace}{'Total buffer pool write time (millisec)'} +
            $hist_values{$rep_tablespace}{'Total elapsed asynchronous read time'}+$hist_values{$rep_tablespace}{'Total elapsed asynchronous write time'} +
            $hist_values{$rep_tablespace}{'Direct reads elapsed time (ms)'}+$hist_values{$rep_tablespace}{'Direct write elapsed time (ms)'})  ;
        $Elapsed_nonAsynch_changed = ($rep_values{'Total buffer pool read time (millisec)'}+$rep_values{'Total buffer pool write time (millisec)'} +
            $rep_values{'Direct reads elapsed time (ms)'}+$rep_values{'Direct write elapsed time (ms)'}) -
           ($hist_values{$rep_tablespace}{'Total buffer pool read time (millisec)'}+$hist_values{$rep_tablespace}{'Total buffer pool write time (millisec)'} +
            $hist_values{$rep_tablespace}{'Direct reads elapsed time (ms)'}+$hist_values{$rep_tablespace}{'Direct write elapsed time (ms)'})  ;
      }
      
      if ( ( $onlyChanged && (( $BP_data_changed + $BP_index_changed + $BP_xda_changed + $Directio_changed + $Elapsed_changed ) > 0 )) || ( $onlyChanged == 0) ) { # display it if display all or if selecting only changed and something has changed
      
        printf "\n%25s  %4s %4s %10s %4s %6s %9s \n",'Tablespace', 'ID', 'BPID';
        printf "%25s  %4s %4s %10s %4s %6s %9s \n",$rep_tablespace,$rep_values{'Tablespace ID'}, $rep_values{'Buffer pool ID currently in use'};
        printf "                             %21s %21s %10s %21s %43s \n", '------- reads -------', 
                                                            '----- temporary  -----',
                                                            '- writes -','--- Asynchronous ----', '------------------ Direct -----------------';
        printf "                             %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s        %10s \n",'logical', 'physical', 
                                                                           'log reads','phys reads',
                                                                           '','pg reads','pg writes','Read Req', 'Reads', 'Write Req', 'Writes','Diff';
                                                                         
        if ( $BP_data_changed || ( $onlyChanged == 0 ) ) { 
          printf "Data Buffer Pool  (current): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  \n",$rep_values{'Buffer pool data logical reads'}, $rep_values{'Buffer pool data physical reads'}, 
                                                                             $rep_values{'Buffer pool temporary data logical reads'},$rep_values{'Buffer pool temporary data physical reads'},
                                                                             $rep_values{'Buffer pool data writes'},$rep_values {'Asynchronous pool data page reads'},
                                                                             $rep_values{'Asynchronous pool data page writes'};
          if ( $showPrevious ) { 
            printf "Data Buffer Pool (previous): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  ***** %10s\n",$hist_values{$rep_tablespace}{'Buffer pool data logical reads'}, $hist_values{$rep_tablespace}{'Buffer pool data physical reads'}, 
                                                                               $hist_values{$rep_tablespace}{'Buffer pool temporary data logical reads'},$hist_values{$rep_tablespace}{'Buffer pool temporary data physical reads'},
                                                                               $hist_values{$rep_tablespace}{'Buffer pool data writes'},$hist_values{$rep_tablespace}{'Asynchronous pool data page reads'},
                                                                               $hist_values{$rep_tablespace}{'Asynchronous pool data page writes'},'','','','',$BP_data_changed;
          }
        }
        
        if ( $BP_index_changed || ( $onlyChanged == 0 ) ) { # print it if print all or if only changed and something in the index pool has changed
          printf "Index Buffer Pool (current): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  \n",$rep_values{'Buffer pool index logical reads'}, $rep_values{'Buffer pool index physical reads'}, 
                                                                             $rep_values{'Buffer pool temporary index logical reads'},$rep_values{'Buffer pool temporary index physical reads'},
                                                                             $rep_values{'Buffer pool index writes'},$rep_values {'Asynchronous pool index page reads'},
                                                                             $rep_values{'Asynchronous pool index page writes'};
          if ( $showPrevious ) { 
            printf "Index Buffer Pool(previous): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  ***** %10s\n",$hist_values{$rep_tablespace}{'Buffer pool index logical reads'}, $hist_values{$rep_tablespace}{'Buffer pool index physical reads'}, 
                                                                             $hist_values{$rep_tablespace}{'Buffer pool temporary index logical reads'},$hist_values{$rep_tablespace}{'Buffer pool temporary index physical reads'},
                                                                             $hist_values{$rep_tablespace}{'Buffer pool index writes'},$hist_values{$rep_tablespace}{'Asynchronous pool index page reads'},
                                                                             $hist_values{$rep_tablespace}{'Asynchronous pool index page writes'},'','','','',$BP_index_changed;
          }  
        }
        
        if ( $BP_xda_changed || ( $onlyChanged == 0 ) ) { # print it if print all or if only changed and something in the xda pool has changed
          if ( $BP_xda_changed || ($rep_values{'Buffer pool xda logical reads'} +  $rep_values{'Buffer pool xda physical reads'} + 
               $rep_values{'Buffer pool temporary xda logical reads'} + $rep_values{'Buffer pool temporary xda physical reads'} +
               $rep_values {'Asynchronous pool xda page reads'} + $rep_values{'Buffer pool xda writes'} + 
               $rep_values{'Asynchronous pool xda page writes'} > 0 )) { # there is something to show or something changed
            printf "XDA Buffer Pool   (current): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s \n",$rep_values{'Buffer pool xda logical reads'}, $rep_values{'Buffer pool xda physical reads'}, 
                                                                               $rep_values{'Buffer pool temporary xda logical reads'},$rep_values{'Buffer pool temporary xda p  hysical reads'},
                                                                               $rep_values{'Buffer pool xda writes'},$rep_values {'Asynchronous pool xda page reads'},  
                                                                               $rep_values{'Asynchronous pool xda page writes'};
          }
          
          if ( $showPrevious ) { 
            if ( $BP_xda_changed ) { 
              printf "XDA Buffer Pool  (previous): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  ***** %10s\n",$hist_values{$rep_tablespace}{'Buffer pool xda logical reads'}, $hist_values{$rep_tablespace}{'Buffer pool xda physical reads'}, 
                                                                                 $hist_values{$rep_tablespace}{'Buffer pool temporary xda logical reads'},$hist_values{$rep_tablespace}{'Buffer pool temporary xda p  hysical reads'},
                                                                                 $hist_values{$rep_tablespace}{'Buffer pool xda writes'},$hist_values{$rep_tablespace}{'Asynchronous pool xda page reads'},  
                                                                                 $hist_values{$rep_tablespace}{'Asynchronous pool xda page writes'},$BP_xda_changed;
            }
          }
      
        }
        
        
        if ( $Directio_changed || ( $onlyChanged == 0 ) ) { # print it if print all or if only changed and something in the directio counts have changed
          printf "Direct IO         (current): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  \n",'','', 
                                                                             '','',
                                                                             '','',
                                                                             '',$rep_values{'Direct read requests'},$rep_values{'Direct reads'},
                                                                             $rep_values{'Direct write requests'},$rep_values{'Direct writes'};
          if ( $showPrevious ) { 
            printf "Direct IO        (previous): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  ***** %10s\n",'','', 
                                                                            '','',
                                                                            '','',
                                                                             '',$hist_values{$rep_tablespace}{'Direct read requests'},$rep_values{'Direct reads'},
                                                                             $hist_values{$rep_tablespace}{'Direct write requests'},$rep_values{'Direct writes'},$Directio_changed;
          }
        }
      
        if ( $Elapsed_changed || ( $onlyChanged == 0 ) ) { # print it if print all or if only changed and something in the elapsed time values have changed
          printf "Tot Elapsed (ms)  (current): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  \n",'', $rep_values{'Total buffer pool read time (millisec)'}, 
                                                                             '<---------','---------+',$rep_values{'Total buffer pool write time (millisec)'},
                                                                              $rep_values {'Total elapsed asynchronous read time'},
                                                                             $rep_values{'Total elapsed asynchronous write time'},
                                                                             '',$rep_values{'Direct reads elapsed time (ms)'},'',$rep_values{'Direct write elapsed time (ms)'};
          if ( $showPrevious ) { 
            printf "Tot Elapsed (ms) (previous): %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s  ***** %10s (%1s)\n",'', $hist_values{$rep_tablespace}{'Total buffer pool read time (millisec)'}, 
                                                                               '','',$hist_values{$rep_tablespace}{'Total buffer pool write time (millisec)'},
                                                                                $hist_values{$rep_tablespace}{'Total elapsed asynchronous read time'},
                                                                               $hist_values{$rep_tablespace}{'Total elapsed asynchronous write time'},
                                                                               '',$hist_values{$rep_tablespace}{'Direct reads elapsed time (ms)'},'',$hist_values{$rep_tablespace}{'Direct write elapsed time (ms)'},$Elapsed_changed,$Elapsed_nonAsynch_changed;
            $Elapsed_written = 1;
          }
        }
        
      } # end of display changed if
      
      # if necessary generate the array of historic values
      
      if ( ! $cummulative ) { # reset values every run
        foreach my $tmp (sort by_key keys %rep_values) {      # construct the string variable
          if ( trim($tmp) ne '' ) {
            if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only retain the values that are used
            $snapHistoryEntry .= "|$tmp=$rep_values{$tmp}";
          }
        }
        print NEWSNAP "TSNAME=$rep_tablespace$snapHistoryEntry\n";
      }
                                                                        
      my $nl = "\n";
      if ( $rep_values{'No victim buffers available'} > 0 ) { # print it out for info
        my $DB2_USE_ALTERNATE_PAGE_CLEANING = `db2set | grep 'DB2_USE_ALTERNATE_PAGE_CLEANING' | cut -d'=' -f2`;
        chomp $DB2_USE_ALTERNATE_PAGE_CLEANING;
        if ( uc($DB2_USE_ALTERNATE_PAGE_CLEANING) eq 'ON' ) {
          print "\nNumber of times no victim buffers were available: $rep_values{'No victim buffers available'} [should be near zero]\n";
          $nl = '';
        }  
      }
      if ( $rep_values{'Number of files closed'} > 0 ) { 
        print "${nl}Number of files closed: $rep_values{'Number of files closed'} [should be zero - if not, perhaps DB should be activated. perhaps app is dropping all connections periodically\n";
      }

      next;
    }
  }

}

# if necessary save these values

if ( ! $cummulative ) { # reset values every run
  close NEWSNAP;
}

# write out some information depending on what has been displayed

if ( $Elapsed_written) {
  print "\nNOTE: The elapsed time difference displayed consists of '<total elapsed time difference>(<elapsed time difference excluding asynchronous events>)'\n";
}

exit;
