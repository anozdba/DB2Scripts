#!/usr/bin/perl
# --------------------------------------------------------------------
# ldbMon.pl
#
# $Id: ldbMon.pl,v 1.5 2018/06/19 23:29:58 db2admin Exp db2admin $
#
# Description:
# Script to list out the db snap information
#
# Usage:
#   ldbMon.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ldbMon.pl,v $
# Revision 1.5  2018/06/19 23:29:58  db2admin
# correct help information
#
# Revision 1.4  2017/04/15 01:02:03  db2admin
# modify the note commentary
#
# Revision 1.3  2017/04/12 03:23:19  db2admin
# change the comparison literals and improve report
#
# Revision 1.2  2017/04/12 02:37:14  db2admin
# add in option to dump the data in load format
#
# Revision 1.1  2017/04/10 23:29:23  db2admin
# Initial revision
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

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $myDate_debugLevel timeDiff);

# -------------------------------------------------------------------

# variables to retain ....

my %retainedKeywords = (
    'High water mark for connections' =>  1,
    'Application connects' =>  1,
    'Applications connected currently' =>  1,
    'Appls. executing in db manager currently' =>  1,
    'Locks held currently' =>  1,
    'Lock waits' =>  1,
    'Lock list memory in use (Bytes)' =>  1,
    'Lock Timeouts' =>  1,
    'Total sorts' =>  1,
    'Total sort time (ms)' =>  1,
    'Sort overflows' =>  1,
    'Buffer pool data logical reads' =>  1,
    'Buffer pool data physical reads' =>  1,
    'Buffer pool data writes' =>  1,
    'Buffer pool index logical reads' =>  1,
    'Buffer pool index physical reads' =>  1,
    'Total buffer pool read time (milliseconds)' =>  1,
    'Total buffer pool write time (milliseconds)' =>  1,
    'Total elapsed asynchronous read time' =>  1,
    'Total elapsed asynchronous write time' =>  1,
    'Dirty page steal cleaner triggers' =>  1,
    'Dirty page threshold cleaner triggers' =>  1,
    'Direct reads' =>  1,
    'Direct writes' =>  1,
    'Direct reads elapsed time (ms)' =>  1,
    'Direct write elapsed time (ms)' =>  1,
    'Database files closed' =>  1,
    'Rows deleted' =>  1,
    'Rows inserted' =>  1,
    'Rows updated' =>  1,
    'Rows selected' =>  1,
    'Rows read' =>  1,
    'Binds/precompiles attempted' =>  1,
    'Log pages written' => 1,
    'Log write time (sec.ns)' =>  1,
    'Number write log IOs' =>  1,
    'Number log buffer full' =>  1,
    'Package cache lookups' =>  1,
    'Package cache inserts' =>  1,
    'Package cache high water mark (Bytes)' =>  1,
    'Catalog cache lookups' =>  1,
    'Catalog cache inserts' =>  1,
    'Catalog cache high water mark' =>  1
);

my %diffKeywords = (
    'Application connects' =>  1,
    'Lock list memory in use (Bytes)' =>  1,
    'Lock Timeouts' =>  1,
    'Total sorts' =>  1,
    'Total sort time (ms)' =>  1,
    'Sort overflows' =>  1,
    'Buffer pool data logical reads' =>  1,
    'Buffer pool data physical reads' =>  1,
    'Buffer pool data writes' =>  1,
    'Buffer pool index logical reads' =>  1,
    'Buffer pool index physical reads' =>  1,
    'Total buffer pool read time (milliseconds)' =>  1,
    'Total buffer pool write time (milliseconds)' =>  1,
    'Total elapsed asynchronous read time' =>  1,
    'Total elapsed asynchronous write time' =>  1,
    'Dirty page steal cleaner triggers' =>  1,
    'Dirty page threshold cleaner triggers' =>  1,
    'Direct reads' =>  1,
    'Direct writes' =>  1,
    'Direct reads elapsed time (ms)' =>  1,
    'Direct write elapsed time (ms)' =>  1,
    'Database files closed' =>  1,
    'Rows deleted' =>  1,
    'Rows inserted' =>  1,
    'Rows updated' =>  1,
    'Rows selected' =>  1,
    'Rows read' =>  1,
    'Binds/precompiles attempted' =>  1,
    'Log pages written' => 1,
    'Log write time (sec.ns)' =>  1,
    'Number write log IOs' =>  1,
    'Number log buffer full' =>  1,
    'Package cache lookups' =>  1,
    'Package cache inserts' =>  1,
    'Package cache high water mark (Bytes)' =>  1,
    'Catalog cache lookups' =>  1,
    'Catalog cache inserts' =>  1
);

my $ID = '$Id: ldbMon.pl,v 1.5 2018/06/19 23:29:58 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

my $wait  = 60;
my $number = 1;
my $waitMS = $wait * 1000;
my %hld_values;
my %rep_values;
my %diff_values;
my $rep_database = '';
my $debugModules = 'ALL';
my $maxSubroutineLen = 20;
my $call_debugLevel;
my $debugLevel = 0;

# Subroutines and functions ......

sub getDate {
  # -----------------------------------------------------------
  #  Routine to return a formatted Date in YYYY.MM.DD format
  #
  # Usage: getDate()
  # Returns: YYYY.MM.DD
  # -----------------------------------------------------------

  my $currentSubroutine = 'getDate';
  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
  my $year = 1900 + $yearOffset;
  $month = $month + 1;
  $month = substr("0" . $month, length($month)-1,2);
  my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
  return "$year.$month.$day";
} # end of getDate

sub getTime {
  # -----------------------------------------------------------
  # Routine to return a formatted time in HH:MM:SS format
  #
  # Usage: getTime()
  # Returns: HH:MM:SS
  # -----------------------------------------------------------

  my $currentSubroutine = 'getTime';
  #my $second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings, $year;
  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
  $hour = substr("0" . $hour, length($hour)-1,2);
  $minute = substr("0" . $minute, length($minute)-1,2);
  $second = substr("0" . $second, length($second)-1,2);
  return "$hour:$minute:$second"
} # end of getTime

sub displayDebug {
  # -----------------------------------------------------------
  # this routine will display the debug information as required
  # based on the passed debugLevel
  #
  # usage: displayDebug("<message>",<debugLevel at which to display>);
  # returns: nothing
  # -----------------------------------------------------------

  my $lit = shift;
  my $call_debugLevel = shift;
  my $sub = shift;                            # get the subroutine name of the calling

  if ( ! defined($lit) ) { $lit = "" } # if nothing passed then default to empty string
  if ( ! defined($sub) ) { $sub = "Unknown Subroutine" } # if nothing passed then default
  my $uc_sub = uc($sub);

  # only print messages if the message comes from a specified subroutine, processDEBUG or the modules to check var is 'ALL'
  if ( (uc($debugModules) eq 'ALL') || ( uc("$debugModules") =~ /$uc_sub/ ) ) {  # check if ok to print

    if ( length($sub) > $maxSubroutineLen ) { $maxSubroutineLen = length($sub) ; }       # reset length as necessary
    $sub = substr($sub . '                                                                 ',0,$maxSubroutineLen);  # pad out subroutine name as necessary

    if ( ! defined($call_debugLevel) ) { # if debug level not specified then set it to 1
      $call_debugLevel = 1;
    }

    # Display a passed message with timestamp if the skelDebugLevel has been set

    if ( $call_debugLevel <= $debugLevel ) {
      my $tDate = getDate();
      my $tTime = getTime();

      if ( $lit eq "") { # Nothing to display so just display the date and time
        print STDERR "$sub - $tDate $tTime - DEBUG\n";
      }
      else {
        print STDERR "$sub - $tDate $tTime : DEBUG : $lit\n";
      }
    }
  }
} # end of displayDebug

sub isNumeric {
  # -----------------------------------------------------------
  # Routine to check if a supplied parameter is a number or not
  #
  # Usage: isnumeric('123');
  # Returns: 0 - not numeric , 1 numeric
  # -----------------------------------------------------------

  my $currentSubroutine = 'isNumeric';

  my $var = shift;
  displayDebug("var is: $var",2,$currentSubroutine);

  if ($var =~ /^\d+\z/)         { return 1; } # only contains digits between the start and the end of the bufer
  displayDebug("Not Only Digits",1,$currentSubroutine);
  if ($var =~ /^-?\d+\z/)       { return 1; } # may contain a leading minus sign
  displayDebug("Doesn't have a leading minus",1,$currentSubroutine);
  if ($var =~ /^[+-]?\d+\z/)    { return 1; } # may have a leading minus or plus
  displayDebug("No leading minus or plus",1,$currentSubroutine);
  if ($var =~ /^-?\d+\.?\d*\z/) { return 1; } # may have a leading minus , digits , decimal point and then digits
  displayDebug("Not a negative decimal number",1,$currentSubroutine);
  if ($var =~ /^[+-]?(?:\d*\.\d)?\d*(?:[Ee][+-]?\d+)\z/) { return 1; }
  displayDebug("Not scientific notation",1,$currentSubroutine);

  return 0;

} # end of isNumeric

sub waitSeconds {

  # wait the specified number of seconds

  my $x;

  # wait a while
  if ( $number > 0 ) {
    if ( $OS eq "Windows" ) {
      $x = `PING 1.1.1.1 -n 1 -w $waitMS`;
    }
    else {
      $x = `/usr/sbin/ping 192.168.1.1 $wait`;
    }
  }
}

sub getTimestamp {

  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
  my $year = 1900 + $yearOffset;
  $month = $month + 1;
  $hour = substr("0" . $hour, length($hour)-1,2);
  $minute = substr("0" . $minute, length($minute)-1,2);
  $second = substr("0" . $second, length($second)-1,2);
  $month = substr("0" . $month, length($month)-1,2);
  my $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
  my $NowTS = "$year.$month.$day $hour:$minute:$second";

  return $NowTS;

}

sub by_key {
  $a cmp $b ;
}

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs -d <database> [-v[v]] [-w <seconds>] [-n <iterations>] [-l]

       Script to list out db statistics

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (in this program only suppesses parameter messages)
       -d              : database to query
       -w              : wait time between iterations (defaults to 60 seconds)
       -n              : number of iterations - default 1
       -c              : show change from pevious iterations
       -C              : show change from first iteration
       -l              : Output database load records to STDERR
       -v              : set debug level

       NOTE: Essentially just reformats the output of the following command:

             db2 get snapshot for db on <database>
\n";

}

my $headingPrinted = 0;
my $silent = "No";
my $database = '';
my $changes = 0;  # 1 => from last time, 2 => from beginning
my $inFile = '';
my $loadFile = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsvcCn:w:d:f:l") ) {
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
 elsif (($getOpt_optName eq "l"))  {
   if ( $silent ne "Yes") {
     print "Data load records will be generated\n";
   }
   $loadFile = 1;
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be used rather than a realtime snapshot\n";
   }
   $inFile = $getOpt_optValue;
 }
 elsif ($getOpt_optName eq "w")  {
   $wait = "";
   ($wait) = ($getOpt_optValue =~ /(\d*)/);
   if ($wait eq "") {
      usage ("Value supplied for the wait parameter (-w) is not numeric");
      exit;
   }
   if ( $silent ne "Yes") {
     print "Monitor will wait $wait seconds before iteration\n";
   }
   $waitMS = $wait * 1000;
 }
 elsif ($getOpt_optName eq "n")  {
   $number = "";
   ($number) = ($getOpt_optValue =~ /(\d*)/);
   if ($number eq "") {
      usage ("Value supplied for number parameter (-n) is not numeric");
      exit;
   }
   if ( $silent ne "Yes") {
     print "Monitor will iterate $number times\n";
   }
 }
 elsif (($getOpt_optName eq "c"))  {
   $changes = 1;
   if ( $silent ne "Yes") {
     print "Data changes from last entry will be displayed\n";
   }
 }
 elsif (($getOpt_optName eq "C"))  {
   $changes = 2;
   if ( $silent ne "Yes") {
     print "Data changes from first entry will be displayed\n";
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
my $TS;

if ( ($database eq '') ) {
  usage ("Database parameter must be entered");
  exit;
}

# Load up the historic values

print "Loading old comparison values\n";

my @oldSnap_values = ();
my %hist_values = ();
my $DBNAME = '';
if ( open(OLDSNAP,"<ldbmon.hist") ) {
  while (<OLDSNAP>) {
    chomp $_;
    @oldSnap_values = split(/\|/,$_);
    if ( $oldSnap_values[0] eq "SnapTime" ) {
      $TS = $oldSnap_values[1]; # set the last timestamp as the timestamp from the history file
      print "Delta Values obtained are from $oldSnap_values[1]\n";
    }
    else {
      if ($debugLevel > 0 ) { print "$_\n"; }
      my @tmpval ;
      foreach my $tmp (@oldSnap_values) { # loop through the values
        @tmpval = split('=', $tmp);
        if ( $tmpval[0] eq 'DBNAME' ) { # label for this record
          $DBNAME = $tmpval[1];
        }
        else {
          $hist_values{$DBNAME}{$tmpval[0]} = $tmpval[1];
          $hld_values{$tmpval[0]} = $tmpval[1];
        }
      }
    }
  }
  close OLDSNAP;
}
else {
  print "No history values to display \n";
}

my $first = 1;

while ( $number > 0 ) {

  if ( ! defined($TS) ) { # first time through
    $TS = getTimestamp();
    print "\n$TS - Iteration $number\n\n";
  }
  else {
    my $tmpTS = getTimestamp();
    my $unit = 'seconds';
    my $diff = timeDiff($TS, $tmpTS,'S');
    if ( $diff > 300 ) { # if it is too big then convert to minutes
      $diff = int($diff/60);
      $unit = 'minutes';
    }
    print "\n$tmpTS - Iteration $number ($diff $unit since last)\n\n";
    if ( $changes < 2 ) { # if not timing from the history file values then reset the timesatmp
      $TS = $tmpTS;
    }
  }

  if (! open (NEWSNAP,">ldbmon.hist"))  { print "Can't create the history file ltssnap.hist! $!\n"; }
  else { print NEWSNAP "SnapTime|$NowTS|SnapTime\n"; }

  processDBSNAP();

  $number--;
  if ( $number > 0 ) { waitSeconds(); }

}

# save the last results

my $snapHistoryEntry = '';
foreach my $tmp (sort by_key keys %rep_values) {      # construct the string variable
  if ( trim($tmp) ne '' ) {
    if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only retain the values that are used

    $snapHistoryEntry .= "|$tmp=$rep_values{$tmp}";
  }
}

print NEWSNAP "DBNAME=$rep_database$snapHistoryEntry\n";

close NEWSNAP;

sub outputLoadData { 

  if ( ! $headingPrinted ) {
    print STDERR "HEAD";
    foreach my $tmp (sort by_key keys %rep_values) {        # construct the string variable
      if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only print the values that are retained
      print STDERR ",'$tmp'";
    }
    $headingPrinted = 1;
    print STDERR "\n";
  }
  
  print STDERR "DATA";
  foreach my $tmp (sort by_key keys %rep_values) {      # construct the string variable
    if ( trim($tmp) ne '' ) {
      if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only print the values that are retained
      if ( isNumeric($rep_values{$tmp}) ) { # dont put quotes around numbers
        print STDERR ",$rep_values{$tmp}";
      }
      else {
        print STDERR ",'$rep_values{$tmp}'";
      }
    }
  }
  print STDERR "\n";
}

sub processDBSNAP {

  # create input stream to read

  my $currentSubroutine = 'processDBSNAP';

  if ( $inFile eq "" ) {              # no input file was specified ....
    if (! open (DBSNAP,"db2 get snapshot for db on $database |") )  {       # Open the stream
      die "Can't run snapshot! \n$!\n";
    }
  }
  else { # just process the supplied file
    if ( ! open( DBSNAP, "<",$inFile ) ) {
      die "Can't open $inFile! \n$!\n";
    }
  }

  my @fields;
  my $returnCode;
  my $headingPrinted = 0;

  my $processSection = "";
  my @parms = ();     # array to hold the parameters
  %rep_values = (); #  Array containing the report values 
  my $name = '';
  my $value = '';
  my $rep_database = '';

  while (<DBSNAP>) {
    if ( $debugLevel > 1 ) { print ">>>>>$_"; }

    chomp $_; # get rid of the CRLF
    @parms = split('=',$_,2);
    $name = trim($parms[0]);
    $value = trim($parms[1]);
  
    if ( $name eq 'Database name' ) { 
    $rep_database = uc($value);
    $processSection = 'TS';
    if ( $debugLevel > 0 ) { print "Database: $rep_database found\n"; }
      next  ;
    }
  
    if ( (uc($rep_database) eq uc($database) ) || ( $database eq '') ) {   # database has been selected for processing
      if ( $debugLevel > 0 ) { print "Database: $rep_database being processed : $_\n"; }

      $rep_values{$name} = $value;   # actually assign the value

      if ( $name eq 'Catalog cache statistics size') { # Past the last entry I was interested in
        last; 
      }
    }
  }  
  # process the gathered data

  foreach my $tmp (sort by_key keys %rep_values) {      # process each of the reatined keyword values
    if ( trim($tmp) ne '' ) {
      if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only process the values that are retained

      if ( $changes == 0 ) {
        $diff_values{$tmp} = $rep_values{$tmp};
      }
      else { # we need to calculate the changed value
        displayDebug("held: $hld_values{$tmp} current: $rep_values{$tmp}",1,$currentSubroutine);

        if ( isNumeric ($hld_values{$tmp}) && isNumeric($rep_values{$tmp}) ) { # both number are numeric
          if ( defined($diffKeywords{$tmp}) ) { # value should be subtracted to identify change
            if ( $first  && ( ! defined($hld_values{$tmp})) ) { # no previous values
              displayDebug("Diff value just assigned reporting value: $rep_values{$tmp}",1,$currentSubroutine);
              $diff_values{$tmp} = $rep_values{$tmp};
            }
            else {
              $diff_values{$tmp} = $rep_values{$tmp} - $hld_values{$tmp};
            }
          }
          else { # just show the current value (diff makes no sense)
            $diff_values{$tmp} = $rep_values{$tmp};
          }
        }
        else { # if it's not numeric just show the current value
          $diff_values{$tmp} = $rep_values{$tmp};
        }
      }

      if ( $first && ( ! defined($hld_values{$tmp})) ) {   # dont use the difference
        print "        >> $tmp => $rep_values{$tmp}\n";
      }
      else { # There are historic values to compare against
        if ( defined($diffKeywords{$tmp}) ) { # value should be subtracted to identify change
          if ( $changes == 0 ) { # dont do differences
            print "      >> $tmp => $diff_values{$tmp} ($hld_values{$tmp})\n";
          }
          elsif ( $changes == 1) { # difference to last iteration 
            print "Delta >> $tmp => $diff_values{$tmp} ($hld_values{$tmp})\n";
          }
          else { # difference to first iteration 
            print "Delta >> $tmp => $diff_values{$tmp} ($hld_values{$tmp})\n";
          }
        }
        else { # just display the returned value
          if ( $diff_values{$tmp} eq $hld_values{$tmp} ) { # the current and last values are the same
            print "      >> $tmp => $diff_values{$tmp}\n";
          }
          else {
            print "      >> $tmp => $diff_values{$tmp} [changed from $hld_values{$tmp}]\n";
          }
        }
      }
    }
  }

  print "\n";
  if ( $changes == 1 ) { print "Note: Delta: Difference with last iteration\n"; }
  if ( $changes == 2 ) { print "Note: Delta: Difference with first iteration\n"; }
  if ( $changes == 0 ) {
    print "      The number in brackets () is the historic value (the value displayed is the current value)\n"; 
  }
  else {
    print "      The number in brackets () is the value that the current value was subtracted from (the historic value) \n"; 
  }
  print "      The number in brackets [] is always the historic value for that entry (only displayed if different to the displayed entry)\n\n"; 

  if ( $loadFile ) { # LOAd data should be produced
    outputLoadData;
  }

  # copy the values to the held array (depending on the comparison entry)
  %hld_values = ();
    
  if ( $first && ( $changes == 2 ) ) { # comparing to first values
    foreach my $tmp (sort by_key keys %rep_values) {      # construct the string variable
      if ( trim($tmp) ne '' ) {
        if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only retain the values that are used
        $hld_values{$tmp} = $rep_values{$tmp};
      }
    }
  }
  elsif ( $changes == 1 ) { # just compare to the last snapshot
    foreach my $tmp (sort by_key keys %rep_values) {      # construct the string variable
      if ( trim($tmp) ne '' ) {
        if ( ! defined ($retainedKeywords{$tmp}) ) { next; }  # only retain the values that are used
        $hld_values{$tmp} = $rep_values{$tmp};
      }
    }
  }
  $first = 0;    # no longer the first time through
}

exit;
