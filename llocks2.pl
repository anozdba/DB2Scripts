#!/usr/bin/perl
# --------------------------------------------------------------------
# llocks2.pl
#
# $Id: llocks2.pl,v 1.3 2016/09/21 02:35:38 db2admin Exp db2admin $
#
# Description:
# Script to identify lock realtionships as displayed by db2pd
#
# Usage:
#   llocks2.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: llocks2.pl,v $
# Revision 1.3  2016/09/21 02:35:38  db2admin
# correct code to cope with transactions waiting on transactions that are waiting
#
# Revision 1.2  2015/06/04 09:34:38  db2admin
# modify checking to only enforce the database parameter if no input file is provided
#
# Revision 1.1  2015/06/04 09:30:20  db2admin
# Initial revision
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

my $ID = '$Id: llocks2.pl,v 1.3 2016/09/21 02:35:38 db2admin Exp db2admin $';
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

  print "Usage: $0 -?hs -d <database> [-v[v]] [-f <file to be processed>] [-A]

       Script to identify lock realtionships as displayed by db2pd

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (in this program only suppesses parameter messages)
       -d              : database where locking is occurring
       -f              : file containing the output of a db2pd -transactions -db dmg1db -locks wait command
                         if not supplied then the script will execute the command
       -A              : show all locks
       -v              : turn on verbose/debug mode

       NOTE: Essentially just reformats the output of the following command:

             db2pd -transactions -db dmg1db -locks wait
\n";

}


my $silent = "No";
my $debugLevel = 0;
my $inFile = '';
my $database = '';
my $showAll = 'No';

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

while ( getOpt(":?hsvf:d:A") ) {
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
 elsif (($getOpt_optName eq "A"))  {
   if ( $silent ne "Yes") {
     print "All locks will be displayed\n";
   }
   $showAll = 'Yes';
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "Lock information will be read from file $getOpt_optValue\n";
   }
   $inFile = $getOpt_optValue;
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

if ( ($database eq '') && ( $inFile eq '') ) {
  usage ("Database parameter must be entered");
  exit;
}

my @fields;
my $returnCode;
my $headingPrinted = 0;

if ( $inFile eq "" ) { # issue the command
  if (! open (LOCKPIPE,"db2pd -transactions -db $database -locks wait |"))  { die "Can't run du! $!\n"; }
}
else { # read the input from the supplied file name
  if (! open (LOCKPIPE,"<$inFile"))  { die "Can't open $inFile $!\n"; }
}

my $processSection = "";
my %appHandl = ();  # initialise the array
my %blocked = ();
my %granted = ();
my %allTran = ();

printf "%6s   %6s %-26s %10s %4s %6s %9s \n",'Tran', 'Appl','Lock Name','Type','Mode','Status','Owner App';

while (<LOCKPIPE>) {
  if ( $debugLevel > 0 ) { print ">>>>>$_"; }

  chomp $_; # get rid of the CRLF
 
  my @bits  = split ;   # break the line up 
  my $tranHandl; # transaction handle of the lock
  my $lockName;  # $lockName of the lock
  my $type;      # type of lock - Row, etc
  my $mode;      # lock mode
  my $sts;       # lock status - W:waiting, G:granted
  my $owner;     # tran that this lock is granted to

  my $rec;          # print record for the blocked lock
  my $blocking_rec; # print record for the blocking lock

  if ( $_ =~ "^Transactions:" ) { $processSection = "TRAN"; next; }
  if ( $_ =~ "^Locks:" ) { $processSection = "LOCK"; next; }

  if ( $processSection eq "LOCK" ) { # process lock records
    if ( $bits[0] eq "Address" ) { next; } # skip the header line
    $tranHandl = $bits[1];
    $lockName = $bits[2];
    $type = $bits[3];
    if ( $bits[4] eq 'V' ) { # adjust for the space in 'Internal V'
      $type .= ' V';
      $mode = $bits[5];
      $sts = $bits[6];
      $owner = $bits[7];
    }
    else {
      $mode = $bits[4];
      $sts = $bits[5];
      $owner = $bits[6];
    }
    $rec = sprintf "%6s %6s %26s %10s %4s %6s ...... Blocked by %9s\n",$tranHandl, $appHandl{$tranHandl},$lockName,$type,$mode,$sts,$owner;
    $blocking_rec = sprintf "%6s   %6s %26s %10s %4s %6s %9s \n",$tranHandl, $appHandl{$tranHandl},$lockName,$type,$mode,$sts,$owner;

    # place an entry on the waiting queue if it is waiting
    if ( $sts eq "W" ) { # waiting lock ...
      if ( defined($blocked{$owner}) ) { # already created this entry
        $blocked{$owner} .= "  $rec";
      }
      else {
        $blocked{$owner} = "  $rec";
      }
    }

    # place an entry on the granted queue as necessary 

    if ( $sts eq "G" ) { # granted lock ...
      if ( defined($granted{$tranHandl}) ) { # already created this entry
        $granted{$tranHandl} .= "$blocking_rec";
      }
      else {
        $granted{$tranHandl} = "$blocking_rec";
      }
    }

    # Just save off tran information

    if ( defined($allTran{$tranHandl}) ) { # already created this entry
      $allTran{$tranHandl} .= "$blocking_rec";
    }
    else {
      $allTran{$tranHandl} = "$blocking_rec";
    }
  }
  elsif ( $processSection eq "TRAN" ) { # process transaction records
    if ( ( $_ =~ /READ/ ) || ( $_ =~ /WRITE/ )) {  # a line we are interested in 
      $appHandl{$bits[3]} = $bits[1];   # link the tranhandl to the appHandl
    }
  }

}

# now print out the accumulated data .....

print "\nTransactions being Blocked:\n\n";

foreach my $key (sort by_key keys %blocked ) {
  print $allTran{$key};
  if ( defined($blocked{$key}) ) { # if there are entries being blocked by this tranHandl then .....
    print "$blocked{$key}\n";
  }
}

if ( $showAll eq 'Yes' ) {
  print "Transactions Holding locks:\n\n";

  foreach my $key (sort by_key keys %granted ) {
    print $granted{$key};
  }
}

my $num_blocked = scalar(keys(%blocked));

if ( $num_blocked == 0 ) { # No waiting locks found 
  print "\nNo waiting locks found\n";
}

exit;
