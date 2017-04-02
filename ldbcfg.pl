#!/usr/bin/perl
# --------------------------------------------------------------------
# ldbcfg.pl
#
# $Id: ldbcfg.pl,v 1.14 2014/05/25 22:26:22 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a GET DB CFG command
#
# Usage:
#   ldbcmd.pl  database  [parameter]
#
# $Name:  $
#
# ChangeLog:
# $Log: ldbcfg.pl,v $
# Revision 1.14  2014/05/25 22:26:22  db2admin
# correct the allocation of windows include directory
#
# Revision 1.13  2013/07/23 00:50:22  db2admin
# make sure there are no leading spaces on the file strings
#
# Revision 1.12  2013/07/23 00:44:27  db2admin
# make the machine name lower case
#
# Revision 1.11  2013/07/23 00:32:16  db2admin
# Add in the generation of dir commands if the -S option is selected
#
# Revision 1.10  2013/02/21 23:57:45  db2admin
# Add in timestamp to heading
#
# Revision 1.9  2011/06/08 04:21:03  db2admin
# Add in show detail
#
# Revision 1.8  2010/01/24 21:26:56  db2admin
# Add in a parm to search the value component as well
#
# Revision 1.7  2009/11/11 02:02:06  db2admin
# ALter program to optionally only print out different configs
#
# Revision 1.6  2009/07/02 23:40:45  db2admin
# Modify to also work for DB2 V7 (requires FOR keyword on command)
#
# Revision 1.5  2009/01/13 23:26:47  db2admin
# Standardise parameters - align with other CFG list programs
#
# Revision 1.4  2009/01/05 21:50:28  db2admin
# BUG: Using delete command on windows
# RESOLVED: Changed to del command
#
# Revision 1.3  2008/11/13 22:28:55  m08802
# Correct error when allocating database name
#
# Revision 1.2  2008/11/04 21:41:57  m08802
# Implemented better parameter code
#
# Revision 1.1  2008/10/26 23:20:20  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

$ID = '$Id: ldbcfg.pl,v 1.14 2014/05/25 22:26:22 db2admin Exp db2admin $';
@V = split(/ /,$ID);
$Version=$V[2];
$Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs [-D] -d <database> [-p <search parm>] [-V <search string>] [-o | ONLY]  [-g | GENDATA] [-f <filename> [-x|X]] [-v[v]] [-S]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -d               : database to list
       -D               : show detail
       -p               : parameter to list (default: All) [case insensitive]
       -V               : search string anywhere (in either parm, desc or value)
       -o or ONLY       : Only print out the generated defines (implies -g)
       -g or GENDATA    : Generate define statements to recreate the config
       -f               : Input comparison file
       -x               : only print out differing values from the comparison file
       -X               : only print out differing values from the comparison file (use file values for the commands)
       -S               : Create dir <drive> commands as necessary
       -v               : set debug level

       NOTE: -x only has an effect if -g is specified
             -X only has an effect if -f and -g are specified
     \n";
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
    $scriptDir = "/udbdba/scripts";
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
$genData = "No";
$printRep = "Yes";
$PARMName = "All";
$database = "";
$compFile = "";
$debugLevel = 0;
$onlyDiff = "No";
$useFile = "No";
$search = "All";
$showDetail = "No";
$dirCmds = "No";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsf:vxXDd:SV:p:og|^ONLY|^GENDATA";

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
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be listed\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "D"))  {
   $showDetail = "Yes";
   if ( $silent ne "Yes") {
     print "Detail will be shown\n";
   }
 }
 elsif (($getOpt_optName eq "x"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing different comparison values will be displayed\n";
   }
   $onlyDiff = "Yes";
 }
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print "The update commands will use the values from the file\n";
   }
   $useFile = "Yes";
   $onlyDiff = "Yes";
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "Comparison file will be $getOpt_optValue\n";
   }
   $compFile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "Dir commands will be generated\n";
   }
   $dirCmds = "Yes";
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "Only entries containing $getOpt_optValue will be displayed\n";
   }
   $PARMName = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "V"))  {
   if ( $silent ne "Yes") {
     print "Entries containing $getOpt_optValue anywhere will be displayed\n";
   }
   $search = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "o") || ($getOpt_optName eq "ONLY") )  {
   if ( $silent ne "Yes") {
     print "Only the created definitions will be output\n";
   }
   $genData = "Yes";
   $printRep = "No";
 }
 elsif (($getOpt_optName eq "g") || ($getOpt_optName eq "GENDATA") )  {
   if ( $silent ne "Yes") {
     print "Update configuration definitions will be generated\n";
   }
   $genData = "Yes";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "") {
     if ( $silent ne "Yes") {
       print "Database $getOpt_optValue will be listed\n";
     }
     $database = $getOpt_optValue;
   }
   elsif ( $PARMName eq "All") {
     if ( $silent ne "Yes") {
       print "Only entries containing $getOpt_optValue will be displayed\n";
     }
     $PARMName = uc($getOpt_optValue);
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
$machine = lc($machine);
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

if ( $database eq "" ) {
  die "Database name MUST be entered\n";
}

if ($silent ne "Yes") {
  if ($PARMName eq "All") {
    print "All parameters will be displayed for database $database\n";
  }
}

if ( $compFile ne "" ) {
  # load up comparison file
  if (! open(COMPF, "<$compFile") ) { die "Unable to open $compFile for input \n $!\n"; }
  while (<COMPF>) {

    if ( $debugLevel > 0 ) { print ">> $_";}

    if ( $_ =~ /Database Manager Configuration/ ) { 
      die "File $compFile is a Database Manager Configuration file.\nA Database Configuration file is required\n\n";
    }

    $COMPF_input = $_;
    @COMPF_dbcfginfo = split(/=/);
    @COMPF_wordinfo = split(/\s+/);

    $COMPF_PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $COMPF_PRMNAME = $1;
      $validPARM{$COMPF_PRMNAME} = 1;
    }
    if ( ($COMPF_PRMNAME eq "") && ( defined($COMPF_dbcfginfo[0])) ) {
      $COMPF_PRMNAME = trim($COMPF_dbcfginfo[0]);
    }
    
    if ( $debugLevel > 0 ) { print "COMPF ParmName is $COMPF_PRMNAME\n"; }

    if ($COMPF_PRMNAME ne "") {
      chomp  $COMPF_dbcfginfo[1];
      if ( $COMPF_dbcfginfo[1] =~ /AUTOMATIC\(/ ) { # dont keep the current value
        if ( $debugLevel > 0 ) { print "COMPF_dbcfginfo[1] set to AUTOMATIC\n"; }
        $COMPF_dbcfginfo[1] = "AUTOMATIC";
      }
      $compDBCFG{$COMPF_PRMNAME} = $COMPF_dbcfginfo[1];
      if ( $debugLevel > 0 ) { print "Parameter $COMPF_PRMNAME has been loaded with parm $COMPF_dbcfginfo[1]\n"; }
    }
  }
  close COMPF;
}

if (! open(STDCMD, ">getdbcfgcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n"; 
} 

print STDCMD "db2 connect to $database\n";
if ( $showDetail eq "Yes" ) {
  print STDCMD "db2 get db cfg for $database show detail\n";
}
else {
  print STDCMD "db2 get db cfg for $database\n";
}

close STDCMD;

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x getdbcfgcmd.bat`;
  $pos = "./";
}

if (! open (GETDBCMDPIPE,"${pos}getdbcfgcmd.bat |"))  {
        die "Can't run getdbcfgcmd.bat! $!\n";
    }

$maxData = 0;
while (<GETDBCMDPIPE>) {
    # parse the db2 get db cfg output

    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

    $input = $_;
    chomp $_;
    @dbcfginfo = split(/=/);
    @wordinfo = split(/\s+/);

    $PRMNAME = "";
    if ( /\(([^\(]*)\) =/ ) {
      $PRMNAME = $1;
    }
    if ( ($PRMNAME eq "") && ( defined($dbcfginfo[0])) ) {
      $PRMNAME = trim($dbcfginfo[0]);
    }

    if ( $debugLevel > 0 ) { print "Parm Name $PRMNAME is being processed\n"; }

    $compValue = "";
    if ( defined ( $compDBCFG{$PRMNAME} ) ) { # if the entry exists in the comparison file
      if ( $debugLevel > 1 ) { print "Comparison value exists and is $compDBCFG{$PRMNAME}\n"; }
      $compValue = $compDBCFG{$PRMNAME};
    }
    if ( $debugLevel > 1 ) { print "Lookup for parameter '$PRMNAME' has finished\n"; }

    if ( $input =~ /Database Configuration for Database/ ) {
      $DBName = $wordinfo[5];
      if ( $DBName ne "" ) {
        if ($printRep eq "Yes") {
          print ">>>>>> Processing for database $DBName ($NowTS)\n";
        }
      }
    }

    $display = "Yes";
    if ( ($PARMName ne "All") && ( uc($dbcfginfo[0]) !~ /$PARMName/ ) ) { # search parm not found
      $display = "No";
    }
    elsif ( ($search ne "All") && ( uc($input) !~ /$search/ ) ) {     # search parm not found
      $display = "No";
    }

    if ( $display eq "Yes" ) {

      chomp  $dbcfginfo[1];
      $prmval = $dbcfginfo[1];

      if ( $debugLevel > 1 ) { print "Parm Name $PRMNAME has been selected for processing\n"; }

      if ( $dirCmds eq "Yes" ) {
        if ( ($_ =~ /Path to log files/) || ($_ =~ /DISK:/) ) {
          $fileStr = trim($prmval);
          if ($_ =~ /DISK:/) { $fileStr = substr($prmval,6); }
          if ( $OS eq "Windows" ) {
            $mountpt = uc(substr($fileStr,0,2));
            $usedDrives{$mountpt} = "1"; # keep track of the drives being used
          }
          else {
            $mountpt_temp = `df -k $fileStr | grep -v Filesystem`;
            if ( $mountpt_temp eq "") { # file not a path or perhaps lacking permissions ......
              $temp_CName = substr($fileStr,0,rindex($fileStr,"/"));
              $mountpt_temp = `df -k $temp_CName | grep -v Filesystem`;
            }
            @mountpt_info = split(/\s+/,$mountpt_temp);
            $mountpt = $mountpt_info[5];
            chomp $mountpt;
            $usedDrives{$mountpt} = "1"; # keep track of the drives being used
          }
        }
      }

      if ( $dbcfginfo[1] =~ /AUTOMATIC\(/ ) {
        if ( $debugLevel > 1 ) { print "AUTO Check : $dbcfginfo[1] contains AUTO\n"; }
        $prmval = "AUTOMATIC";
      }
      if ( $debugLevel > 1 ) { print "$dbcfginfo[1] \>\> $prmval\n"; }

      if ( $debugLevel > 1 ) { print "Parm Name $dbcfginfo[0] has a value of $prmval\n"; }

      # generate the update commands if they are required

      if ( $genData eq "Yes" ) {
        if ($PRMNAME ne "") {
          if ( defined($validPARM{$PRMNAME}) ) {
            if ( $onlyDiff eq "Yes" ) {
              if ( $compValue ne  $prmval ) {
                $maxData++;
                if ( $useFile eq "Yes" ) {
                  $Data[$maxData] = "db2 update db cfg using $PRMNAME $compValue";
                }
                else { 
                  $Data[$maxData] = "db2 update db cfg using $PRMNAME $prmval";
                }
              }
            }
            else { # print it even if the values are the same
              $maxData++;
              $Data[$maxData] = "db2 update db cfg using $PRMNAME $prmval";
            }
          }
        }
      }

      # Generate the report if it is required

      if ( $printRep eq "Yes" ) {
        if ( $PRMNAME ne "" ) {
          if ( $compFile ne "" ) {
            if ( $compValue ne  $prmval ) {
              print "$_  << File Value = $compDBCFG{$PRMNAME}\n";
            }
            else {
              print "$_ \n";
            }
          }
          else {
            print "$_ \n";
          }
        }      
        else {
          print "$_ \n";
        }
      }
    }
}

if ($genData eq "Yes") {
  for ( $i = 0; $i <= $maxData; $i++) {
    print "$Data[$i] \n";
  }
}

if ( $dirCmds eq "Yes" ) {

  if (! open(DIRCMD, ">>dircmd_$database.bat") ) { die "Unable to open a file to hold the dir commands to run $!\n"; }
  print DIRCMD "echo \"SERVER: $machine\"\n";

  foreach $drive ( keys %usedDrives ) {
    if ($OS eq "Windows" ) {
      print DIRCMD "dir $drive\n";
    }
    else {
      print DIRCMD "df -k $drive\n";
    }
  }

  close DIRCMD;

}

if ($OS eq "Windows" ) {
 `del getdbcfgcmd.bat`;
}
else {
 `rm getdbcfgcmd.bat`;
}
