#!/usr/bin/perl
# --------------------------------------------------------------------
# lspace.pl
#
# $Id: lspace.pl,v 1.2 2009/07/20 02:38:17 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST TABLESPACE CONTAINERS FOR <db> command
#
# Usage:
#   lspace.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lspace.pl,v $
# Revision 1.2  2009/07/20 02:38:17  db2admin
# Add in Windows support
#
# Revision 1.1  2009/07/20 00:46:44  db2admin
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

  print "Usage: $0 -?hDOCSs [DATA] [DATAONLY] [SETTSCONT] -d <database> [-t <tablespace>] [-p <container prefix>] [-q[q etc]]
       -h or -?        : This help message
       -D or DATA      : Produce data file
       -O or DATAONLY  : Do not produce the report
       -s              : Silent mode
       -S or SETTSCONT : Generate the SET Tablespace containers commands
       -C              : Consolidate space on set tablespace containers command
       -d              : Database to list
       -t              : Limit output to this tablespace
       -q              : sets the debug level -qq set it to 2 -qqq sets it to 3 etc
       -p              : When printing SET TS CONTAINER commands prefix the file names with this string\n";
}


if ( $^O eq "MSWin32") {
  $machine = `hostname`;
  $OS = "Windows";
  $levDelim = '\\';
  use lib 'c:\udbdba\scripts';
}
else {
  $machine = `uname -n`;
  $machine_info = `uname -a`;
  @mach_info = split(/\s+/,$machine_info);
  $OS = $mach_info[0] . " " . $mach_info[2];
  $levDelim = '/';
  BEGIN {
    $scriptDir = "/";
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
  }
  use lib "$scriptDir";
}

require "commonFunctions.pl";

$GenSetTSCont = "No";
$genData = "No";
$printRep = "Yes";
$TSName = "ALL";
$database = "";
$silent = "No";
$stem = "";
$consolidate = "No";
$debugLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hCDqp:d:t:OSs|^DATA|^DATAONLY|^SETTSCONT";

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt($getOpt_opt) ) {
 if (($getOpt_optName eq "D") || ($getOpt_optName eq "DATA") )  {
   if ( $silent ne "Yes") {
     print "Data output file will be produced\n";
   }
   $genData = "Yes";
 }
 elsif (($getOpt_optName eq "O") || ($getOpt_optName eq "DATAONLY") )  {
   if ( $silent ne "Yes") {
     print "Standard report will not be produced\n";
   }
   $printRep = "No";
 }
 elsif (($getOpt_optName eq "h") || ($getOpt_optName eq "?") )  {
   usage ("");
   exit;
 }
 elsif (($getOpt_optName eq "S") || ($getOpt_optName eq "SETTSCONT") )  {
   if ( $silent ne "Yes") {
     print "Set TS Cont commands will be generated\n";
   }
   $GenSetTSCont = "Yes";
 }
 elsif (($getOpt_optName eq "C" ))  {
   if ( $silent ne "Yes") {
     print "Containers will be consolidated into a single container on Set Tablespace Containers\n";
   }
   $consolidate = "Yes";
 }
 elsif (($getOpt_optName eq "q" ))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level will be incremented to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "s"))  {
   $silent = "Yes";
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "File names will be prefixed with $getOpt_optValue\n";
   }
   $stem = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "DB2 connection will be made to $getOpt_optValue\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "Only Tablespace $getOpt_optValue will be listed\n";
   }
   $TSName = uc($getOpt_optValue);
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "DB2 connection will be made to $database\n";
     }
   }
   elsif ( $TSName eq "ALL" ) {
     $TSName = uc($getOpt_optValue);
     if ( $silent ne "Yes") {
       print "Only tablespace $TSName will be listed\n";
     }
   }
   elsif ( $stem eq "" ) {
     $stem = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "File names will be prefixed with $stem\n";
     }
   }
   else {
     usage ("Parameter getOpt_optName : Will be ignored");
     exit;
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
$NowTS = "$year.$month.$day $hour:$minute:$second";

if ( $database eq "" ) {
  usage 'Database must be supplied';
  exit;
}

$zeroes = "00";

if (! open(STDCMD, ">ltscmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 connect to $database\n";
print STDCMD "db2 list tablespaces show detail\n";

close STDCMD;

if (! open(LCONTCMD, ">lcont.sql") ) {
  die "Unable to open a file to hold the lcont commands to run $!\n"; 
} 

print LCONTCMD "connect to $database\n";

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x ltscmd.bat`;
  $pos = "./";
}

if (! open (LTSPIPE,"${pos}ltscmd.bat |"))  {
        die "Can't run ltscmd.bat! $!\n";
    }

while (<LTSPIPE>) {
    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    @ltsinfo = split(/=/);

    if ( trim($ltsinfo[0]) eq "Tablespace ID") {
      print LCONTCMD "list tablespace containers for " . trim($ltsinfo[1]) . " show detail\n";
    }
}

close LCONTCMD;
close LTSPIPE;

if ($OS ne "Windows") {
  $t = `rm lcont.out`;
}
else {
  $t = `del lcont.out`;
}

$t = `db2 -f ${pos}lcont.sql -r lcont.out`;
#print "Cont output: $t\n";

#die "stop here";

if (! open (LTSPIPE,"${pos}ltscmd.bat |"))  {
        die "Can't run second ltscmd.bat! $!\n";
    }

$TotUsed = 0;
$TotAlloc = 0;
$maxIDs = -1;
$maxData = -1;
$instance = $ENV{'DB2INSTANCE'};

# Print Headings ....
if ($printRep eq "Yes") {
  print "Tablespace listing from Machine: $machine Instance: $ENV{'DB2INSTANCE'} Database: $database ($NowTS) .... \n\n";
  printf "%-4s %-16s %-4s %-11s %-6s %9s %9s %9s %9s %7s %10s\n",
       'TSID', 'Tablespace_Name', 'Type', 'Contents', 'State', 'Total_Pgs', 'Used_Pgs', 'Free_Pgs', 'HWM', 'Page_Sz','Mb_Used';
  printf "%-4s %-16s %-4s %-11s %-6s %9s %9s %9s %9s %7s %10s\n",
       '----', '----------------', '----', '-----------', '------', '---------', '---------', '---------', '---------', '-------', '----------';
}

while (<LTSPIPE>) {
    # print "Processing $_\n";
    # parse the db2 list tablespaces show detail
    # Tablespace ID                        = 14
    # Name                                 = S1TXN02
    # Type                                 = Database managed space
    # Contents                             = Any data
    # State                                = 0x0000
    #   Detailed explanation:
    #     Normal
    # Total pages                          = 1986304
    # Useable pages                        = 1986048
    # Used pages                           = 1981888
    # Free pages                           = 4160
    # High water mark (pages)              = 1981888
    # Page size (bytes)                    = 32768
    # Extent size (pages)                  = 64
    # Prefetch size (pages)                = 1536
    # Number of containers                 = 4

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    @ltsinfo = split(/=/);

    if ( trim($ltsinfo[0]) eq "Tablespace ID") {
      $TSID = trim($ltsinfo[1]);
    }

    if ( trim($ltsinfo[0]) eq "Name") {
      $Name = trim($ltsinfo[1]);
    }

    if ( trim($ltsinfo[0]) eq "Type") {
      $Type = trim($ltsinfo[1]);
      if ($Type eq "Database managed space") {
        $Type = "DMS";
      }
      elsif ($Type eq "System managed space") {
        $Type = "SMS";
      }
    }

    if ( trim($ltsinfo[0]) eq "Contents") {
      $Contents = trim($ltsinfo[1]);
      if ($Contents eq "Any data") {
        $Contents = "Any";
      }
      elsif ($Contents eq "User Temporary data") {
        $Contents = "User Temp";
      }
      elsif ($Contents eq "All permanent data. Large table space.") {
        $Contents = "All - LrgTS";
      }
      elsif ($Contents eq "All permanent data. Regular table space.") {
        $Contents = "All - RegTS";
      }
      elsif ($Contents eq "System Temporary data") {
        $Contents = "System Temp";
      }
    }

    if ( trim($ltsinfo[0]) eq "State") {
      $State = trim($ltsinfo[1]);
    }

    if ( trim($ltsinfo[0]) eq "Total pages") {
      $TPages = trim($ltsinfo[1]);
      $TPagesDATA = $TPages;
      if ( $TPages eq "Not applicable" ) {
        $TPagesDATA = "";
        $TPages = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "Used pages") {
      $UPages = trim($ltsinfo[1]);
      $UPagesDATA = $UPages;
      if ( $UPages eq "Not applicable" ) {
        $UPagesDATA = "";
        $UPages = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "High water mark (pages)") {
      $HWM = trim($ltsinfo[1]);
      $HWMDATA = $HWM;
      if ( $HWM eq "Not applicable" ) {
        $HWMDATA = "";
        $HWM = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "Free pages") {
      $FPages = trim($ltsinfo[1]);
      $FPagesDATA = $FPages;
      if ( $FPages eq "Not applicable" ) {
        $FPagesDATA = "";
        $FPages = "N/A";
      }
    }

    if ( trim($ltsinfo[0]) eq "Page size (bytes)") {
      $PSize = trim($ltsinfo[1]);
      # and now the printout .....

      $MbUsed = ($UPages * $PSize)/1024/1024;
      $TotUsed = $TotUsed + $MbUsed;
      $dig = index($MbUsed,".",0);
      if ($dig == -1) {
        $dig  = length($MbUsed) + 1;
        $MbUsed = $MbUsed . ".00";
      }
      else {
        $MbUsed = "$MbUsed$zeroes";
      }
      $MbUsed = substr($MbUsed,0,$dig + 3);

      if ( ($TSName eq uc($Name)) || ($TSName eq "ALL") ) {
        if ($printRep eq "Yes") {
          printf "%-4s %-16s %-4s %-11s %-6s %9s %9s %9s %9s %7s %10s\n",
               $TSID,$Name,$Type,$Contents,$State,$TPages,$UPages,$FPages,$HWM,$PSize,$MbUsed;
        }

        if (! open(LCONTPIPE, "<lcont.out") ) {
          die "Unable to open lcont.out $!\n"; 
        } 

        $TotPages_XX = 0;
        $SetTSCont{$TSID} = "";
        $CHead = "No";
        $numContainers = 0;
        $allocContSpace = "";

        while (<LCONTPIPE>) {
          # print ">>> $_ \n";

          @continfo = split(/=/);

          if ( $_ =~ /Tablespace Containers for Tablespace/) {
            @T = ($_ =~ /Tablespace Containers for Tablespace (.*)/);
            $CTSID = $T[0]; 
            $CTSID = trim($CTSID);
            if ( $CTSID eq $TSID ) {
              $state = "Process";
            }
            else {
              $state = "Dont_Process"; 
            }
          }

          if ( $state ne "Process" ) { # skip this tablespace .....
            next;
          }

#          print "Processing Tablespace $TSID Container TSID $CTSID\n"; 

          if ( trim($continfo[0]) eq "Container ID") {
            $CID = trim($continfo[1]);
            $numContainers++;
          }

          if ( trim($continfo[0]) eq "Name") {
            $CName = trim($continfo[1]);
          }

          if ( trim($continfo[0]) eq "Type") {
            $CType = trim($continfo[1]);
          }

          if ( trim($continfo[0]) eq "Total pages") {
            $CTotalPages = trim($continfo[1]);
            $TotPages_XX = $TotPages_XX + $CTotalPages;
          }

          if ( trim($continfo[0]) eq "Useable pages") {
            $CUsable = trim($continfo[1]);
          }

          if ( trim($continfo[0]) eq "Accessible") {
            $CAccessible = trim($continfo[1]);

            # Print out the container information

            if ($CHead eq "No") {
              if ($printRep eq "Yes") {
                printf "    %-3s %-8s %12s %12s %10s %-50s\n",
                       '','','','Mount Point','','';
                printf "    %-3s %-8s %12s %12s %10s %-50s\n",
                       'ID','Type','Tot_Pages','Free Spc(Mb)','Mb_Alloc','Name';
                printf "    %-3s %-8s %12s %12s %10s %-50s\n",
                       '---','--------','------------','------------','----------','---------------------------------------------------';
                $CHead = "Yes";
              }
            }

            $MbSize = ($PSize * $CUsable)/1024/1024;
            $TotAlloc = $TotAlloc + $MbSize;
            $dig = index($MbSize,".",0);
            if ($dig == -1) {
              $dig  = length($MbSize) + 1;
              $MbSize = $MbSize . ".00";
            }
            else {
              $MbSize = "$MbSize$zeroes";
            }
            $MbSize = substr($MbSize,0,$dig + 3);

            if ( $OS eq "Windows" ) {
              $mountpt = substr($CName,0,2);
              if ($debugLevel > 0) { print "dir $mountpt \n"; }
              if (! open(FSPIPE, "dir $mountpt |" ) ) {
                die "Unable to open dir $mountpt$!\n";
              }
              while ( <FSPIPE> ) {
                if ( $debugLevel > 1 ) { print ">>> $_\n"; }
                if ( $_ =~ /bytes free/ ) { 
                  @fsinfo = split ;
                  if ( $debugLevel > 0 ) { print ">>> $fsinfo[2] , $fsinfo[3]\n"; }
                  $fsinfo[2] =~ s/,//g; # get rid of the commas
                  $MPfreeSpc = $fsinfo[2]/1024/1024;  # convert it to a Mb figure
                  $MPfreeSpc = sprintf("%12.0d",$MPfreeSpc);
                }
              }
            }
            else {
              $mountpt_temp = `df -k $CName | grep -v Filesystem`;
              if ( $mountpt_temp eq "") { # file not a path or perhaps lacking permissions ......
                $temp_CName = substr($CName,0,rindex($CName,"/"));
                $mountpt_temp = `df -k $temp_CName | grep -v Filesystem`;
              }
              @mountpt_info = split(/\s+/,$mountpt_temp);
              $mountpt = $mountpt_info[5]; 
              $MPfreeSpc = $mountpt_info[3];
              $MPfreeSpc = $MPfreeSpc/1024;  # convert it to a Mb figure
              $MPfreeSpc = sprintf("%12.0d",$MPfreeSpc);
              chomp $mountpt;
            }

            if ($printRep eq "Yes") {
              printf "    %-3s %-8s %12s %12s %10s %-50s\n",
                     $CID,$CType,$CTotalPages,$MPfreeSpc,$MbSize,$CName;
            }
 
            # create an allocation string for all of the containers ....

            if ( $OS eq "Windows" ) {
              @levels = split(/\\/,$CName);
              $drv = substr($CName,0,2);
            }
            else {
              @levels = split(/\//,$CName);
              $drv = "";
            }
            $mlevels = $#levels;
            $suff = $levels[$mlevels-1] . $levDelim . $levels[$mlevels]; 
            if ($CType eq "File") {
              if ( $allocContSpace eq "" ) {
                $allocContSpace = "FILE '$drv$stem$levDelim$suff' $CTotalPages";
              }
              else {
                $allocContSpace = "$allocContSpace , FILE '$drv$stem$levDelim$suff' $CTotalPages";
              }
            }
            else {
              if ( $allocContSpace eq "" ) {
                $allocContSpace = "PATH '$drv$stem$levDelim$suff'";
              }
              else {
                $allocContSpace = "$allocContSpace , PATH '$drv$stem$levDelim$suff'";
              }
            }

            if ($genData eq "Yes") {
              $maxData++;
              $Pages4K = int((($MbUsed * 1024) / 4) + 200) ;
              @levels = split(/\$levDelim/,$CName);
              $mlevels = $#levels;
              $Data[$maxData] = "CONTAINER,$NowTS,$machine,$instance,$database,$Name,$TSID,$CID,$CName,$CType,$CTotalPages,$CUsable,$Cassessible,$MbSize,$mountpt";
#              print "$Data[$maxData]\n";
            }

          }

        } # have now looked at all of the containers .....
 
        close LCONTPIPE; 

        if ( $genData eq "Yes" ) {
          $maxData++;
          $Pages4K = int((($MbUsed * 1024) / 4) + 200) ;
          if ( $OS eq "Windows" ) {
            @levels = split(/\\/,$CName);
          }
          else {
            @levels = split(/\//,$CName);
          }
          $mlevels = $#levels;
          $Data[$maxData] = "TABLESPACE,$NowTS,$machine,$instance,$database,$Name,$TSID,$Type,$Contents,$State,$TPagesDATA,$UPagesDATA,$FPagesDATA,$HWMDATA,$PSize,$MbUsed,$numContainers";
#          print "$Data[$maxData]\n";
        }

        if ($GenSetTSCont eq "Yes") {
          $maxIDs++;
          $Pages4K = int((($MbUsed * 1024) / 4) + 200) ; 
          $HWMPages = int($HWM  + 200) ; 
          if ( $OS eq "Windows" ) {
            @levels = split(/\\/,$CName);
            $drv = substr($CName,0,2);
          }
          else {
            @levels = split(/\//,$CName);
            $drv = "";
          }
          $mlevels = $#levels;
          if ( $consolidate eq "Yes" ) {
            if ($CType eq "File") {
              $suff = $levels[$mlevels-1] . $levDelim . $levels[$mlevels]; 
              $SetTSCont[$maxIDs] = "db2 \"set tablespace containers for $TSID using ($CType '$drv$stem$levDelim$suff' $HWMPages )\"";
            }
            else {
              $suff = $levels[$mlevels]; 
              $SetTSCont[$maxIDs] = "db2 \"set tablespace containers for $TSID using ($CType '$drv$stem$levDelim$suff' )\"";
            }
          }
          else { 
            $SetTSCont[$maxIDs] = "db2 \"set tablespace containers for $TSID using ($allocContSpace)\"";
          }
          print "$SetTSCont[$maxIDs]\n";
        }
      }
    }
}

$TotAlloc = $TotAlloc / 1024;
$dig = index($TotAlloc,".",0);
if ($dig == -1) {
  $dig  = length($TotAlloc) + 1;
  $TotAlloc = $TotAlloc . ".00";
}
else {
  $TotAlloc = "$TotAlloc$zeroes";
}
$TotAlloc = substr($TotAlloc,0,$dig + 3);

$TotUsed = $TotUsed / 1024;
$dig = index($TotUsed,".",0);
if ($dig == -1) {
  $dig  = length($TotUsed) + 1;
  $TotUsed = $TotUsed . ".00";
}
else {
  $TotUsed = "$TotUsed$zeroes";
}
$TotUsed = substr($TotUsed,0,$dig + 3);

if ($printRep eq "Yes") {
  print "\nTotal Storage in use for $database is $TotUsed Gb out of $TotAlloc Gb allocated\n\n";
}

if ($GenSetTSCont eq "Yes") {
  for ( $i = 0; $i <= $maxIDs; $i++) {
    print "$SetTSCont[$i] \n";
  }
}

if ($genData eq "Yes") {
  for ( $i = 0; $i <= $maxData; $i++) {
    print "$Data[$i] \n";
  }
}

if ($OS eq "Windows" ) {
 `del ltscmd.bat`;
 `del lcont.sql`;
 `del lcont.out`;
}
else {
 `rm ltscmd.bat`;
 `rm lcont.sql`;
 `rm lcont.out`;
}

