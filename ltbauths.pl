#!/usr/bin/perl
# --------------------------------------------------------------------
# ltbauths.pl
#
# $Id: ltbauths.pl,v 1.11 2018/10/21 21:01:51 db2admin Exp db2admin $
#
# Description:
# Script to format the table auths of a selected table
#
# Usage:
#   lauths.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ltbauths.pl,v $
# Revision 1.11  2018/10/21 21:01:51  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.10  2018/10/18 22:58:52  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.9  2018/10/17 03:51:02  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.8  2015/02/02 03:59:09  db2admin
# alter script to generate GRANTS correctly for 9.7
#
# Revision 1.7  2014/05/25 22:28:37  db2admin
# correct the allocation of windows include directory
#
# Revision 1.6  2013/06/24 01:39:12  db2admin
# Correct error produced on upgrade to db2 v9.7 (column GRANTOR TYPE added to syscat tables)
#
# Revision 1.5  2009/12/21 04:22:38  db2admin
# correct proble with un-fuzzy matches
#
# Revision 1.4  2009/10/22 03:48:25  db2admin
# Adjust % signs to work with windows
#
# Revision 1.3  2009/10/22 03:22:17  db2admin
# increase debug information
#
# Revision 1.2  2009/09/02 06:13:58  db2admin
# widen some of the selection criteria
#
# Revision 1.1  2009/09/02 05:51:24  db2admin
# Initial revision
#
#
#
# --------------------------------------------------------------------

my $ID = '$Id: ltbauths.pl,v 1.11 2018/10/21 21:01:51 db2admin Exp db2admin $';
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

  print STDERR "Usage: $0 -?hs -d <database> [-g] -t <table> [-x] [-S <schema>] [-v[v]]

       Script to format the table auths of a selected table

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -d               : Database to list
       -S               : schema name to include
       -t               : table to list
       -x               : table name entered is the exact name 
       -v               : set diag level
       -g               : generate grants

       NOTE: 1. Unless the -x parameter is entered then the table name 
                entered is considered to be a search string and will match
                all tables containing that string.
             2. If -x is selected then it can be overridden by the placement of a
                % sign in either of the -t or -S parameters.

                i.e. to select all tables in schema DBA you could issue:

                  $0 -xd dbadb -t % -S dba -x

     \n";
}

sub generateGrants {

  $numGrants++;
  $withGrant = "n";
  if ( $REPNAME eq "syscat.dbauth" ) {
    $permissionsString = "";
    for ( $A1 = 3 ; $A1 <= $#detail ; $A1++ ) {
      if ( $detail[$A1] ne "N" ) {
        if ( $detail[$A1] eq "G" ) {
          $withGrant = "y";
        }
        if ( trim($heading[$A1]) eq "externalroutineauth" ) {
          $x = "create_external_routine";
        }
        elsif ( trim($heading[$A1]) eq "implschemaauth" ) {
          $x = "implicit_schema";
        }
        elsif ( trim($heading[$A1]) eq "nofenceauth" ) {
          $x = "create_not_fenced_routine";
        }
        elsif ( trim($heading[$A1]) eq "quiesceconnectauth" ) {
          $x = "quiesce_connect";
        }
        elsif ( trim($heading[$A1]) eq "securityadmauth" ) {
          $x = "secadm";
        }
        elsif ( trim($heading[$A1]) eq "libraryadmauth" ) {
          $x = "libadm";
        }
        else { # Just truncate the AUTH off of the heading
          $y = trim($heading[$A1]);
          $x = substr($y,0,length($y)-4);
        }
        if ( $permissionsString eq "" ) {
          $permissionsString = $x;
        }
        else {
          $permissionsString = "$permissionsString, $x";
        }
      }
    }
    # at this point the permissions string should be set
    $granteeType = "USER" ;
    if ( $detail[2] eq "G" ) {
      $granteeType = "GROUP" ;
    }
    $grantee = trim($detail[1]);

    if ( $withGrant eq "y" ) {
      $grant[$numGrants] = "grant $permissionsString on database to $granteeType $grantee with grant;"
    }
    else {
      $grant[$numGrants] = "grant $permissionsString on database to $granteeType $grantee;"
    }
  }
  elsif ( $REPNAME eq "syscat.tbspaceauth" ) {
    $granteeType = "USER" ;
    if ( $detail[2] eq "G" ) {
      $granteeType = "GROUP" ;
    }
    $grantee = trim($detail[1]);

    if ( $detail[4] eq "G" ) {
      $grant[$numGrants] = "grant use of tablespace $detail[3] to $granteeType $grantee with grant;"
    }
    else {
      $grant[$numGrants] = "grant use of tablespace $detail[3] to $granteeType $grantee;"
    }
  }
  elsif ( $REPNAME eq "syscat.tabauth" ) {
    $allWithGrant="Y";
    $granteeType = "USER" ;
    if ( $detail[2] eq "G" ) {
      $granteeType = "GROUP" ;
    }
    $grantee = trim($detail[1]);

    $permissionsString = "";
    $permissionsStringWithGrant = "";
    for ( $A1 = 6 ; $A1 <= $#detail ; $A1++ ) {
      if ( $detail[$A1] ne "N" ) {
        if ( trim($heading[$A1]) eq "refauth" ) {
          $x = "references";
        }
        else {
          # Just truncate the AUTH off of the heading to get the literal
          $y = trim($heading[$A1]);
          $x = substr($y,0,length($y)-4);
        }

        if ( $detail[$A1] eq "G" ) {
          if ( $permissionsStringWithGrant eq "" ) {
            $permissionsStringWithGrant = $x;
          }
          else {
            $permissionsStringWithGrant = "$permissionsStringWithGrant, $x";
          }
        }
        else { # permissions not 'WITH GRANT OPTION'
          if ( $permissionsString eq "" ) {
            $permissionsString = $x;
          }
          else {
            $permissionsString = "$permissionsString, $x";
          }
        }
      }
    }
    # at this point the permissions string should be set
    $granteeType = "USER" ;
    if ( $detail[2] eq "G" ) {
      $granteeType = "GROUP" ;
    }
    $grantee = trim($detail[2]);

    # Grant out the different permissions
    if ( $permissionsStringWithGrant ne "" ) {
      $grant[$numGrants] = "grant $permissionsStringWithGrant on table $detail[4].$detail[5] to $granteeType $grantee with grant option;";
      if ( $permissionsString ne "" ) { # only increment the index if a 'NOT WITH GRANT' entry exists
        $numGrants++;
      }
    }
    if ( $permissionsString ne "" ) {
      $grant[$numGrants] = "grant $permissionsString on table $detail[4].$detail[5] to $granteeType $grantee;";
    }

  }

}

# Set default values for variables

$silent = "No";
$database = "All";
$generate = "No";
$tabname = "";
$exact = "No";
$schema = "%";
$debugLevel = 0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?shvd:t:gxS:";

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
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "Table schema to be selected is $getOpt_optValue\n";
   }
   $schema = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be listed\n";
   }
   $database = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "x"))  {
   if ( $silent ne "Yes") {
     print "The database name entered is the exact name of the database\n";
   }
   $exact = "Yes";
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "Table $getOpt_optValue will be listed\n";
   }
   $tabname = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "g"))  {
   if ( $silent ne "Yes") {
     print "Grants will be generated\n";
   }
   $generate = "Yes";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "All" ) {
     $database = uc($getOpt_optValue);
     if ( $silent ne "Yes") {
       print STDERR "Database $getOpt_optValue will be listed\n";
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

if ( $tabname eq "" ) {
  usage ("Table Parameter must be entered\nIf you want all databases then enter '%' for the database");
  exit;
}

if ( $database eq "" ) {
  usage ("Database Parameter must be entered");
  exit;
}

if (! open(STDCMD, ">lauthcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n";
}

print STDCMD "db2 connect to $database\n";
if ( $debugLevel > 0 ) { print "db2 connect to $database\n"; }
print STDCMD "db2 \"select 'REPORT: syscat.tabauth' from sysibm.sysdummy1\"\n";
if ( $debugLevel > 0 ) { print "db2 \"select 'REPORT: syscat.tabauth' from sysibm.sysdummy1\"\n"; }
if  ( $ exact eq "Yes") {
  $scond = "=";
  if ( $schema =~ /\%/ ) {
    $scond = "like";
  }
  $tcond = "=";
  if ( $tabname =~ /\%/ ) {
    $tcond = "like";
  }
  print STDCMD "db2 \"select * from syscat.tabauth where tabname $tcond '$tabname' and tabschema $scond '$schema' \"\n";
  if ( $debugLevel > 0 ) { print "db2 \"select * from syscat.tabauth where tabname $tcond '$tabname' and tabschema $scond '$schema' \"\n"; } 
}
else {
  if ( $OS eq "Windows" ) { 
    print STDCMD "db2 \"select * from syscat.tabauth where tabname like '%%$tabname%%' and tabschema like '${schema}%%'\"\n";
    if ( $debugLevel > 0 ) { print "db2 \"select * from syscat.tabauth where tabname like '%%$tabname%%' and tabschema like '${schema}%%'\"\n"; }
  }
  else {
    print STDCMD "db2 \"select * from syscat.tabauth where tabname like '%$tabname%' and tabschema like '${schema}%%'\"\n";
    if ( $debugLevel > 0 ) { print "db2 \"select * from syscat.tabauth where tabname like '%$tabname%' and tabschema like '${schema}%%'\"\n"; }
  }
}
close STDCMD;

$pos = "";
if ($OS ne "Windows") {
  $t = `chmod a+x lauthcmd.bat`;
  $pos = "./";
}

if (! open (AUTHPIPE,"${pos}lauthcmd.bat |"))  {
        die "Can't run ltscmd.bat! $!\n";
    }

# Print Headings ....
print "Authority Listing from $database table $tabname ($Now) .... \n\n";

$Current = "n";
$inHeading = "n";
$utilCNT = 0;
$listCNT = 0;
$report = "";
$nextRep = 0;
$numGrants = 0;

$dash25 = "-------------------------";
$space25 = "                         ";
$dash100 = "$dash25$dash25$dash25$dash25";
$space100 = "$space25$space25$space25$space25";

while (<AUTHPIPE>) {

    if ( $debugLevel > 1 ) { print "Input : $_\n"; } 
    $linein = $_;

    if ( $inHeading eq "y" ) {
      if ( $_ =~ /---------/ ) { # End of headings .....

        $inHeading = "n";
        $underline = "";

        if ( $authCount > 0 ) {
          print "\n$authCount auth entries printed\n";
        }

        $authCount = 0;

        if ( $REPNAME ne "" ) {
          # only the columns to be listed horizontally need be listed here 
          if ( $REPNAME eq "syscat.dbauth" ) {
            $heading[0] = "Grantor  ";
            $heading[1] = "Grantee  ";
            $inReport = "y";
          }
          elsif ( $REPNAME eq "syscat.tbspaceauth" ) {
            $heading[0] = "Grantor  ";
            $heading[1] = "Grantee  ";
            $heading[2] = "Granteetype";
            $heading[3] = "Tablespace        ";
            $inReport = "y";
          }
          elsif ( $REPNAME eq "syscat.tabauth" ) {
            $heading[0] = "Grantor  ";
            $heading[1] = "Grantor Type";
            $heading[2] = "Grantee  ";
            $heading[3] = "Granteetype";
            $heading[4] = "Tabschema   ";
            $heading[5] = "Tab Name                  ";
            $inReport = "y";
          }

          # Print out the headings

          for ( $j = 0 ; $j <= $maxLen -1 ; $j++ ) { # for each heading line
            for ( $k = 0 ; $k <= $#heading ; $k++ ) { # for each column .....
              if ( $k >= $horiz_end ) { # doing vertical headings
                $x =  substr($heading[$k],$j,1); 
                print "$x ";
                if ( $j == $maxLen -1 ) { # if it is the last line .....
                  $underline = "${underline}- ";
                }
              }
              else { # still processing horiz headings ....
                if ( $j == $maxLen -1 ) { # if it is the last line .....
                  print "$heading[$k] ";
                  $x = substr($dash100,0,length($heading[$k]));
                  $underline = "${underline}$x ";
                }
                else { # just put in spaces .....
                  $y = length($heading[$k])+1;
                  $x = substr($space100,0,$y);
                  print "$x"; 
                }
              }
            }
            print "\n"; # terminate the line
          }
          print "$underline\n"; # underline it
        }
      }
      else { # deemed to be in a heading ...
        if ( $REPNAME ne "" ) {
          if ( trim( $_ ) ne "" ) { # skip blank lines 
            @heading = split ;
            $spaceFill = 0;
            $maxLen = 1;
            $nextRep = 0;
            for ( $i = 0; $i <= $#heading; $i++ ) {
              if ( $i >= $horiz_end ) {
                if ( length($heading[$i]) > $maxLen ) {
                  $maxLen = length($heading[$i]);
                }
              }
              else {
                $spaceFill = 1 + $spaceFill + length($heading[$i]);
              }
            } 
            # adjust the heading lengths to be the same (space filled at front) ......
            for ( $i = 0; $i <= $#heading; $i++ ) {
              $heading[$i] = lc($heading[$i]);
              if ( $i >= $horiz_end ) {
                $spos = 25 + length($heading[$i]) - $maxLen;
                $x = "$space25$heading[$i]";
                $heading[$i] = substr($x, $spos, $maxLen);
              }
            }
          }
        }
      }
    }
    else { # not in heading ......
      if ( $_ =~ /Local database alias/ ) { # end of connection information
        $inHeading = "y";
        $inReport = "n";
      }
      elsif ( $_ =~ /selected./ ) { # end of records output
        $inHeading = "y";
        $inReport = "n";
        if ( $nextRep == 0 ) {
          $REPNAME = "";
        }
        else {
          $nextRep--;
        }
      } 

      if ( ($inReport eq "y" ) && ( trim($_) ne "" ) ) {
        @detail = split;
        if ( $generate eq "Yes" ) { generateGrants(); } 

        for ( $i = 0 ; $i <= $#detail ; $i++ ) {
          $x = trim($detail[$i]) . $space100;
          if ( $i >= $horiz_end ) { # one of the vertical columns
            $y = substr($x,0,1);
          }
          else {
            $y = substr($x,0,length($heading[$i]));
          }
          print "$y ";
        }
        $authCount++; 
        print "\n";
      }
    }

    if ( $_ =~ /REPORT:/ ) {
      $nextRep = 1;
      $inReport = "n";
      ($x, $REPNAME) = split ;
      chomp $REPNAME;
      if ( $REPNAME eq "syscat.dbauth" ) {
        $horiz_end = 2;
      }
      elsif ( $REPNAME eq "syscat.tbspaceauth" ) {
        $horiz_end = 4;
      }
      elsif ( $REPNAME eq "syscat.tabauth" ) {
        $horiz_end = 6;
      }
    }
        
    if ( $_ =~ /SQL1024N/) {
      die "A database connection must be established before running this program\n";
    }

}

if ( $authCount > 0 ) {
  print "\n$authCount auth entries printed\n";
}

if ( $generate eq "Yes" ) {
  print "\nThe generated grants: \n";
  for ( $i = 0 ; $i <= $#grant ; $i++ ) {
    print "$grant[$i]\n";
  }
}

if ( $OS eq "Windows" ) {
  $x = `del lauthcmd.bat`;
}
else {
  $x = `rm lauthcmd.bat`;
}
