#!/usr/bin/perl
# --------------------------------------------------------------------
# lcont.pl
#
# $Id: lcont.pl,v 1.9 2009/02/23 05:20:22 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST TABLESPACE CONTAINERS FOR <db> command
#
# Usage:
#   lcont.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lcont.pl,v $
# Revision 1.9  2009/02/23 05:20:22  db2admin
# Correct processing of multiple container tablespaces when generating
# SET TABLESPACE CONTAINERS statements
# Also add in new option -C to consolidate containers into a single container
#
# Revision 1.8  2009/01/19 23:53:16  db2admin
# Modify to run in Windows environments
#
# Revision 1.6  2009/01/18 23:41:25  db2admin
# correct delete command in windows
#
# Revision 1.5  2009/01/04 23:14:22  db2admin
# Remove old debug lines
#
# Revision 1.4  2008/11/25 01:51:37  db2admin
# Implement new getOpt subroutine and standardise Usage() sub
#
# Revision 1.3  2008/11/12 01:08:32  m08802
# Add code to set INC path correctly
#
# Revision 1.2  2008/11/11 04:21:40  m08802
# 1. Add in new parameter module
# 2. Correct bug in generation of CONTAINER output records
# 3. Added in numContainers field to TABLESPACE record
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hDOCSs [DATA] [DATAONLY] [SETTSCONT] -d <database> [-t <tablespace>] [-p <container prefix>]
       -h or -?        : This help message
       -D or DATA      : Produce data file
       -O or DATAONLY  : Do not produce the report
       -s              : Silent mode
       -S or SETTSCONT : Generate the SET Tablespace containers commands
       -C              : Consolidate space on set tablespace containers command
       -d              : Database to list
       -t              : Limit output to this tablespace
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

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hCDp:d:t:OSs|^DATA|^DATAONLY|^SETTSCONT";

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
     print "Standard report will not be produced but the data will be output\n";
   }
   $printRep = "No";
   $genData = "Yes";
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

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x ltscmd.bat`;
  $pos = "./";
}

if (! open (LTSPIPE,"${pos}ltscmd.bat |"))  {
        die "Can't run ltscmd.bat! $!\n";
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

    # for early version of HPUX/perl looks like leading spaces generate a NULL in the first array element on SPLIT
    # so we need to identify the offsets to check ....

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

        if (! open(STDCMD, ">lcontcmd.bat") ) {
          die "Unable to open a file to hold the commands to run $!\n"; 
        } 

        print STDCMD "set DB2INSTANCE=$DB2INSTANCE\n";
        print STDCMD "db2 connect to $database\n";
        print STDCMD "db2 list tablespace containers for " . $TSID . " show detail\n";

        close STDCMD;

        $pos = "";
        if ($OS ne "Windows") {
          $t = `chmod a+x lcontcmd.bat`;
          $pos = "./";
        }

        if (! open (LCONTPIPE,"${pos}lcontcmd.bat |"))  {
          die "Can't run lcontcmd.bat! $!\n";
        }

        $TotPages_XX = 0;
        $SetTSCont{$TSID} = "";
        $CHead = "No";
        $numContainers = 0;
        $allocContSpace = "";

        while (<LCONTPIPE>) {
          # print ">>> $_ \n";

          @continfo = split(/=/);

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
                printf "    %-3s %-8s %12s %12s %-10s %10s %-50s\n",
                       'ID','Type','Tot_Pages','Usable_Pages','Accessible','Mb_Alloc','Name';
                printf "    %-3s %-8s %12s %12s %-10s %10s %-50s\n",
                       '---','--------','------------','------------','----------','----------','---------------------------------------------------';
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

            if ($printRep eq "Yes") {
              printf "    %-3s %-8s %12s %12s %-10s %10s %-50s\n",
                     $CID,$CType,$CTotalPages,$CUsable,$Cassessible,$MbSize,$CName;
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
              $Data[$maxData] = "CONTAINER,$NowTS,$machine,$instance,$database,$Name,$TSID,$CID,$CName,$CType,$CTotalPages,$CUsable,$Cassessible,$MbSize";
#              print "$Data[$maxData]\n";
            }

          }

        } # have now looked at all of the containers .....

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
 `del lcontcmd.bat`;
}
else {
 `rm ltscmd.bat`;
 `rm lcontcmd.bat`;
}

