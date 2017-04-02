#!/usr/bin/perl
# --------------------------------------------------------------------
# lbuffers.pl
#
# $Id: lbuffers.pl,v 1.6 2014/05/25 22:25:53 db2admin Exp db2admin $
#
# Description:
# Script to list out the details about buffer pools 
#
# Usage:
#   lbuffers.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lbuffers.pl,v $
# Revision 1.6  2014/05/25 22:25:53  db2admin
# correct the allocation of windows include directory
#
# Revision 1.5  2010/02/28 20:44:56  db2admin
# get rid of windows CRLF
#
# Revision 1.4  2010/02/02 05:31:27  db2admin
# Adjust to accomodate db2mtrk v9 on windows
#
# Revision 1.3  2009/09/07 06:02:57  db2admin
# correct problem with selected database entry
#
# Revision 1.2  2009/09/06 23:42:47  db2admin
# Put out some error checking
#
# Revision 1.1  2009/09/04 04:29:17  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------


sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hsOR -d <database> [-v[v]] 
       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -o or -O        : Only print out the data - dont print out a report
       -d              : Database to be listed
       -r or -R        : Generate the report
       -v              : display debug information
       \n ";
}

if ( $^O eq "MSWin32") {
  $machine = `hostname`;
  $OS = "Windows";
  BEGIN {
    $scriptDir = 'c:\udbdba\scripts';
    $tmp = rindex($0,"\\");
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}
else {
  $machine = `uname -n`;
  $machine_info = `uname -a`;
  @mach_info = split(/\s+/,$machine_info);
  $OS = $mach_info[0] . " " . $mach_info[2];
  BEGIN {
    $scriptDir = "c:\udbdba\scripts";
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}

require "commonFunctions.pl";

# Set default values for variables

$silent = "No";
$database = "";
$genData = "";
$printRep = "Yes";
$debugLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hvsrRoOd:";

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
 elsif ((uc($getOpt_optName) eq "O") )  {
   if ( $silent ne "Yes") {
     print "Only the data will be output\n";
   }
   $genData = "Yes";
   $printRep = "No";
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug Level has been set to $sebugLevel\n"
   }
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (uc($getOpt_optName) eq "R")  {
   if ( $silent ne "Yes") {
     print "The report will be generated\n";
   }
   $printRep = "Yes";
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Database $getOpt_optValue will be listed\n";
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

$instance = $ENV{'DB2INSTANCE'};

if ($printRep eq "Yes") {
  # Print Headings ....
  if ( $database ne "" ) {
    print "Bufferpool listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($Now) .... \n\n";
  }
  else {
    print "Bufferpool listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} ($Now) .... \n\n";
  }
}

# if a database name has been supplied then display information from the syscat.bufferpools table

if ( $database ne "" ) {
  if ( $debugLevel > 0 ) { print "Collecting Information from database syscat tables in $database ...... \n"; } 
  if (! open(STDCMD, ">bpcmd.bat") ) {
    die "Unable to open a file to hold the commands to run $!\n";
  }

  print STDCMD "db2 connect to $database\n";
  print STDCMD "db2 \"select bufferpoolid, bpname, npages, pagesize from syscat.bufferpools order by bufferpoolid\" \n";

  close STDCMD;

  $pos = "";
  if ($OS ne "Windows") {
    $t = `chmod a+x bpcmd.bat`;
    $pos = "./";
  }

  if (! open (LBPTABLE,"${pos}bpcmd.bat |"))  {
    die "Can't read bpcmd.bat! $!\n";
  }

  if ($printRep eq "Yes") {
    print " >>>>>>>>  Bufferpool Details obtained from syscat.bufferpools\n\n";
    printf "%-4s %-20s %10s %10s %10s\n",
         'ID', 'Name', 'Pages', 'Page Size', 'Size Mb';
    printf "%-4s %-20s %10s %10s %10s\n",
         '----', '--------------------', '---------', '----------', '----------';
  }

  $inReport = "No";
  while ( <LBPTABLE>) {
    if ( $debugLevel > 0 ) { print "Database output>$_"; }
    @linein = split;
    if ( $linein[0] =~ "------" ) {
      $inReport = "Yes";
      next;
    }
    if ( $_ =~ "selected" ) {
      $inReport = "No";
      print "\n";
      next;
    }

    if ( $linein[0] eq "" ) {
      next;
    }

    if ( $inReport eq "Yes" ) {
      $sizeMb = int(($linein[2] * $linein[3])/1024/1024);
      printf "%-4s %-20s %10s %10s %10s\n",
           $linein[0], $linein[1], $linein[2], $linein[3], $sizeMb;
    }
  }
}

if ( $debugLevel > 0 ) { print "Processing $instance - $database ...... \n"; } 

if (! open (LBPPIPE,"db2 get snapshot for all bufferpools | " ))  {
        die "Can't run DB2!\n $!\n";
    }

if ($printRep eq "Yes") {
  # Print Headings ....
  print "================================================================================================================\n\n";
  print " >>>>>>>>  Bufferpool Details obtained from 'get snapshot for all bufferpools'\n\n";
  printf "%20s %-32s %21s %5s %10s\n",
         '','........Buffer Pool Data........', '..Asynch Pool Data...', '', 'Current';
  printf "%-20s %10s %10s %10s %10s %10s %5s %10s\n",
         'Buffer Pool Name','Log Reads', 'Phys Reads', 'Writes', 'Page Reads', 'Pg Writes', 'Tbspc', 'Size (pg)';
  printf "%20s %10s %10s %10s %10s %10s %5s %10s\n",
         '-------------------','----------', '----------', '----------', '----------', '----------', '-----', '----------';
}

$currentState = "NotStarted";
$linecnt = -1;
$maxData = -1;
$stuffToPrint = "No";
$currDatabase = "";
if ( $database eq "" ) {
  $printInfo = "Yes";
}
else {
  $printInfo = "No";
}

$printWarning = "Yes";

while (<LBPPIPE>) {

    if ( $linecnt >= 0 ) {
      $linecnt = $linecnt - 1;
    }

    if ( $debugLevel > 0 ) { print "Processing $_"; }

    if ( $_ =~ /SQL1611W/) { # no data returned .....
      print "No data was returned from the get snapshot command. Databases probably not active\n\n";
      next;
    }

    if ( $_ =~ /Not Collected/ ) {
      if ($printWarning eq "Yes" ) {
        print "    Looks like bufferpool monitoring has not been turned on\n    Perhaps \"db2 update monitor switches using BUFFERPOOL on\" needs to be issued\n\n";
        print "    or to set it on permanantly \"db2 update dbm cfg using DFT_MON_BUFPOOL on\" needs to be issued\n\n";
        $printWarning = "No";
      }
    }

    chomp $_ ;
    $linein = $_;

    $linein = ltrim($_);

    @gbuffinfo = split("=",$linein);
    $gbuffinfo[0] = trim($gbuffinfo[0]);
    $gbuffinfo[1] = trim($gbuffinfo[1]);
    if ( $debugLevel > 1 ) { print "gbuffinfo\[0\] = $gbuffinfo[0], gbuffinfo\[1\] = $gbuffinfo[1], gbuffinfo\[2\] = $gbuffinfo[2]\n"; }

    if ( trim($gbuffinfo[0]) eq "Bufferpool name") {
      $bufferPoolName = $gbuffinfo[1];
      $BPName = substr($bufferPoolName,1,20);
    }

    if ( $gbuffinfo[0] eq "Database name") {
      $databaseName = $gbuffinfo[1];
      if ( $database eq "" ) {
        if ( $databaseName ne $currDatabase ) {
          print "Buffers in $databaseName\n\n";
          $currDatabase = $databaseName;
        }
      }
      else { # only displaying a single database
        if ( uc($database) eq uc($databaseName) ) {
          $printInfo = "Yes";
          if ( $databaseName ne $currDatabase ) {
            $currDatabase = $databaseName;
            print "Buffers in $databaseName\n\n";
          }
        }
        else {
          $printInfo = "No";
        }
      }
    }

    if ( $gbuffinfo[0] eq "Buffer pool data logical reads") {
      $logReads = $gbuffinfo[1];
    }

    if ( $gbuffinfo[0] eq "Buffer pool data physical reads") {
      $physReads = $gbuffinfo[1];
    }

    if ( $gbuffinfo[0] eq "Buffer pool data writes") {
      $writes = $gbuffinfo[1];
    }

    if ( $gbuffinfo[0] eq "Asynchronous pool data page reads") {
      $pageReads = $gbuffinfo[1];
    }

    if ( $gbuffinfo[0] eq "Asynchronous pool data page writes") {
      $pageWrites = $gbuffinfo[1];
    }

    if ( $gbuffinfo[0] eq "Tablespaces using bufferpool") {
      $tbSpc = $gbuffinfo[1];
    }

    if ( $gbuffinfo[0] eq "Current size") {
      $currSize = $gbuffinfo[1];
      if ( $printInfo eq "Yes" ) {
        if ($printRep eq "Yes") {
          printf "%-20s %10s %10s %10s %10s %10s %5s %10s\n",
                 $bufferPoolName, $logReads, $physReads, $writes, $pageReads, $pageWrites, $tbSpc, $currSize;
        }
      }
      if ($genData eq "Yes") {
        $maxData++;
        $TS_fmt = formatTS($TS);
        $End_fmt = formatTS($End);
        $TS_Seq = substr $TS, 14;
        $Data[$maxData] = "BACKUP,$Now,$machine,$instance,$database,$Op,$Obj,$TS_fmt,$Type,$Dev,$ELog,$CLog,$BackupID,$numberOfTablespaces,$Comment,$End_fmt,$Status,$Location,$TS_Seq,$TS,$sqlcode,$sqlerrmsg";
      }
    }

}

# Gather memory usage information using db2mtrk .....

if ( $OS eq "Windows" ) {
  if (! open (MTRKPIPE,"db2mtrk -i -d -v |"))  { die "Can't run db2mtrk!\n $!\n"; }
  $usage = "No";
  while ( <MTRKPIPE> ) {
    if ( $_ =~ /Usage:/ ) { $Usage = "Yes"; }
  }
  close MTRKPIPE;
  if ( $Usage eq "Yes" ) { # not yet up to the database stuff (pre V9)
    if (! open (MTRKPIPE,"db2mtrk -i -v |"))  { die "Can't run db2mtrk!\n $!\n"; }
  }
  else {
    if (! open (MTRKPIPE,"db2mtrk -i -d -v |"))  { die "Can't run db2mtrk!\n $!\n"; }
  }
}
else {
  if (! open (MTRKPIPE,"db2mtrk -i -d -v |"))  {
          die "Can't run db2mtrk!\n $!\n";
    }
}

$databaseName = "";
if ( $database eq "" ) {
  $printDatabase = "Yes";
}
else {
  $printDatabase = "No";
}

if ($printRep eq "Yes") {
  # Print Headings ....
  print "\n================================================================================================================\n";
  print "\n >>>>>>>>  Memory usage information obtained using db2mtrk \n\n";
}

$stuffToPrint = "No";

while (<MTRKPIPE>) {
  @mtrkinfo = split;
  if ( $debugLevel > 0 ) { print "MTRK: $stuffToPrint : $_\n"; }

  if ( $mtrkinfo[0] eq "Total:" ) {
    # total memory for a process .....
    $MbSize = int($mtrkinfo[$#mtrkinfo-1]/1024/1024);
    if ( $databaseName eq "" ) { # total memory for instance (Unix Only) 
      print "Instance memory usage : $MbSize Mb\n\n";
      $stuffToPrint = "No";
    }
    else {
      if ( $printDatabase eq "Yes" ) {
        print "Total database $databaseName memory usage : $MbSize Mb\n\n";
      }
    }
    next;
  }

  if ( $_ =~ /Memory for database/ ) {

    if ( $stuffToPrint eq "Yes" ) {

      if ( $debugLevel > 1 ) { print "Printing out last entry : $_\n"; }
      printf " %-30s %10s\n",'Area Type','Size Mb';
      foreach $type ( keys %memSize)  {
        $x = int($memSize{$type}/1024/1024);
        printf " %-30s %10s\n",$type,$x;
      }

      print "\nBuffer Pools ....\n";

      printf " %-10s    %10s\n",  'Pool', 'Size (Mb)' ;
      for ( $i = 0 ; $i <= $#BP ; $i++ ) {
        printf " %-10s    %10s\n",  $i, $BP[$i] ;
      }

      print "\n";

    }

    @memSize = (); # reset the array
    @BP = ();
    $BPindex = -1;
    $databaseName = $mtrkinfo[$#mtrkinfo];
    if ( $database eq "" ) {
      print "Memory usage for Database $databaseName .....\n\n";
    }
    else {
      if ( uc($database) eq uc($databaseName) ) {
        $printDatabase = "Yes";
        print "Memory usage for Database $databaseName .....\n\n";
      }
      else {
        $printDatabase = "No";
      }
    }
  }

  if ( $mtrkinfo[$#mtrkinfo] eq "bytes" ) {
    if ( $printDatabase eq "Yes" ) {
      $stuffToPrint = "Yes";
      @cat = split ("is of size");
      $cat[0] = trim($cat[0]);
      if ( $databaseName ne "" ) { # in a database section
        if ( $_ =~ /Buffer Pool Heap/ ) { # Buffer pools are treated separately .....
          $BPindex++;
          $BP[$BPindex] = int($mtrkinfo[$#mtrkinfo-1]/1024/1024);
          if ( $debugLevel > 0 ) { print ">>> BP $BPindex : $BP[$BPindex] Mb\n"; }
        }
        else { # aggregate all other entries ....
          if ( defined($memSize{$cat[0]}) ) {
            $memSize{$cat[0]} = $memSize{$cat[0]} + $mtrkinfo[$#mtrkinfo-1];
          }
          else {
            $memSize{$cat[0]} = $mtrkinfo[$#mtrkinfo-1];
          }
          $x = int($memSize{$cat[0]}/1024/1024);
          if ( $debugLevel > 0 ) { print ">>> $cat[0] : $x Mb\n"; }
        }
      }
    }
  }

}

if ( $stuffToPrint eq "Yes" ) {

  printf " %-30s %10s\n",'Area Type','Size Mb';
  printf " %-30s %10s\n",'------------------------------','----------';
  foreach $type ( keys %memSize)  {
    $x = int($memSize{$type}/1024/1024);
    printf " %-30s %10s\n",$type,$x;
  }

  print "\nBuffer Pools ....\n\n";

  printf " %-10s    %10s\n",  'Pool', 'Size (Mb)' ;
  printf " %-10s    %10s\n",  '----------', '----------' ;
  for ( $i = 0 ; $i <= $#BP ; $i++ ) {
    printf " %-10s    %10s\n",  $i, $BP[$i] ;
  }

  print "\n";

}
