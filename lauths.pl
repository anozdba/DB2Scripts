#!/usr/bin/perl
# --------------------------------------------------------------------
# lauths.pl
#
# $Id: lauths.pl,v 1.14 2019/01/25 03:12:41 db2admin Exp db2admin $
#
# Description:
# Script to format the database and tablespace auths of a selected database
#
# Usage:
#   lauths.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: lauths.pl,v $
# Revision 1.14  2019/01/25 03:12:41  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.13  2016/04/13 01:00:36  db2admin
# Adjust script to cope with multiple versions of DB2
# Alter script to use commonFunctions.pm module
#
# Revision 1.12  2014/05/25 22:25:33  db2admin
# correct the allocation of windows include directory
#
# Revision 1.11  2013/06/13 22:12:31  db2admin
# increase the size of grantee again
#
# Revision 1.10  2013/06/13 06:06:53  db2admin
# increase grantee display size to 10 characters
#
# Revision 1.9  2011/02/21 03:55:38  db2admin
# take off the windows CRLF characters
#
# Revision 1.8  2010/10/26 05:37:20  db2admin
# Adjust for DB2 v9.7
#
# Revision 1.7  2009/10/22 03:54:18  db2admin
# Increase debug information
#
# Revision 1.6  2009/06/30 22:46:04  db2admin
# Add in silent mode as an option
#
# Revision 1.5  2009/06/30 22:39:45  db2admin
# Correct error in file deletion code
#
# Revision 1.4  2009/06/30 22:38:14  db2admin
# Allow the first entered parameter to be assumed to be the database
#
# Revision 1.3  2009/06/30 22:36:33  db2admin
# Remove temporary command file after use
#
# Revision 1.2  2009/06/30 22:34:00  db2admin
# Correct production of grant statements - only do them when requested
#
# Revision 1.1  2009/06/30 05:54:44  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

use strict;

my $ID = '$Id: lauths.pl,v 1.14 2019/01/25 03:12:41 db2admin Exp db2admin $';
my @V = split(/ /,$ID);
my $Version=$V[2];
my $Changed="$V[3] $V[4]";

my $machine;            # machine name
my $machine_info;       # ** UNIX ONLY ** uname
my @mach_info;          # ** UNIX ONLY ** uname split by spaces
my $OS;                 # OS
my $scriptDir;          # directory where the script is running
my $tmp;

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

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $cF_debugLevel);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs -d <database> [-g] [-v[v]]

       Version $Version Last Changed on $Changed (UTC)

       -h or -?         : This help message
       -s               : Silent mode
       -d               : Database to list
       -g               : generate grants
       -v               : set debug level

  The SQL used for this program is:
     1. select * from syscat.dbauth
     2. select * from syscat.tbspaceauth
     \n";
}

my $numGrants;

my $REPNAME = '';
my $x;
my $y;
my $permissionsString = "";
my @detail = ();
my @heading = ();
my @grant;
my $db2Vers = '';

sub generateGrants {

  my $granteeType;
  my $grantee;

  $numGrants++;
  my $withGrant = "n";
  my $startAuths = 3;
  
  if ( $db2Vers >= 9.7 ) { # earlier versions dont have grantor type in the returned data
    $startAuths = 5;
  }

  if ( $REPNAME eq "syscat.dbauth" ) {
    $permissionsString = "";
    for ( my $A1 = $startAuths ; $A1 <= $#detail ; $A1++ ) {
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
        else { # Just truncate the AUTH of of the heading
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
    my $granteeT = $detail[2];
    if ( $db2Vers >= 9.7 ) { $granteeT = $detail[3]; }
    $granteeType = "USER" ;
    if ( $granteeT eq "G" ) {
      $granteeType = "GROUP" ;
    }

    $grantee = trim($detail[1]);
    if ( $db2Vers >= 9.7 ) { $grantee = trim($detail[2]); }

    if ( $withGrant eq "y" ) {
      $grant[$numGrants] = "grant $permissionsString on database to $granteeType $grantee with grant;"
    }
    else {
      $grant[$numGrants] = "grant $permissionsString on database to $granteeType $grantee;"
    }
  }
  elsif ( $REPNAME eq "syscat.tbspaceauth" ) {
    my $offset = 2;
    if ( $db2Vers >= 9.7 ) { $offset = 3; }
    $granteeType = "USER" ;
    if ( $detail[$offset] eq "G" ) {
      $granteeType = "GROUP" ;
    }

    $grantee = trim($detail[$offset - 1]);
    if ( $db2Vers >= 9.7 ) { $grantee = trim($detail[$offset - 1]); }

    if ( $detail[$offset + 2] eq "G" ) {
      $grant[$numGrants] = "grant use of tablespace $detail[$offset+1] to $granteeType $grantee with grant;"
    }
    else {
      $grant[$numGrants] = "grant use of tablespace $detail[$offset+1] to $granteeType $grantee;"
    }
  }

}

# Set default values for variables

my $silent = "No";
my $database = "All";
my $generate = "No";
my $debugLevel=0;

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_optName = "";
$getOpt_optValue = "";

while ( getOpt(":?shvd:g") ) {
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
   $database = uc($getOpt_optValue);
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

my @ShortDay = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
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
my $NowDayName = "$year/$month/$day ($ShortDay[$dayOfWeek])";
my $date = "$year$month$day";

if (! open(STDCMD, ">lauthcmd.bat") ) {
  die "Unable to open a file to hold the commands to run $!\n";
}

print STDCMD "db2 connect to $database\n";
print STDCMD "db2 \"select 'REPORT: syscat.dbauth' from sysibm.sysdummy1\"\n";
print STDCMD "db2 \"select * from syscat.dbauth\"\n";
print STDCMD "db2 \"select 'REPORT: syscat.tbspaceauth' from sysibm.sysdummy1\"\n";
print STDCMD "db2 \"select * from syscat.tbspaceauth\"\n";
if ( $debugLevel > 0 ) { 
  print "db2 connect to $database\n";
  print "db2 \"select 'REPORT: syscat.dbauth' from sysibm.sysdummy1\"\n";
  print "db2 \"select * from syscat.dbauth\"\n";
  print "db2 \"select 'REPORT: syscat.tbspaceauth' from sysibm.sysdummy1\"\n";
  print "db2 \"select * from syscat.tbspaceauth\"\n";
}

close STDCMD;

my $pos = "";
if ($OS ne "Windows") {
  $x = `chmod a+x lauthcmd.bat`;
  $pos = "./";
}

if (! open (AUTHPIPE,"${pos}lauthcmd.bat |"))  {
        die "Can't run ltscmd.bat! $!\n";
    }

# Print Headings ....
print "Authority Listing from $database ($NowTS) .... \n\n";

my $Current = "n";
my $inHeading = "n";
my $utilCNT = 0;
my $listCNT = 0;
my $report = "";
my $nextRep = 0;
my $numGrants = 0;

my $dash25 = "-------------------------";
my $space25 = "                         ";
my $dash100 = "$dash25$dash25$dash25$dash25";
my $space100 = "$space25$space25$space25$space25";

my $inReport = 'None';
my $authCount = 0;

my $maxLen;
my $horiz_end;
my $spaceFill;
my $abort =0;

while (<AUTHPIPE>) {

  if ( $abort ) { next; }

  if ( $debugLevel > 1 ) { print "$REPNAME : $inReport :  $inHeading : $_\n"; }

  my $linein = $_;

  if ( $_ =~ /Database server/ ) { # find out the release .....
    my @db2V = split;
    my @db2Vparts = split('\.',$db2V[4]);
    $db2Vers = "$db2Vparts[0].$db2Vparts[1]";
    if ( $debugLevel > 1 ) { print "DB2 Version being processed is $db2Vers\n"; }
  }

  if ( $inHeading eq "y" ) {
    if ( $_ =~ /---------/ ) { # End of headings .....

      $inHeading = "n";
      my $underline = "";

      if ( $authCount > 0 ) {
        print "\n$authCount auth entries printed\n";
      }

      $authCount = 0;

      if ( $REPNAME ne "" ) {

        if ( $REPNAME eq "syscat.dbauth" ) {
          if ( $db2Vers >= 9.7 ) {
            $heading[0] = "Grantor      ";
            $heading[1] = "Type";
            $heading[2] = "Grantee      ";
            $heading[3] = "Type";
          }
          else {
            $heading[0] = "Grantor      ";
            $heading[1] = "Grantee      ";
          }
          $inReport = "y";
        }
        elsif ( $REPNAME eq "syscat.tbspaceauth" ) {
          if ( $db2Vers >= 9.7 ) {
            $heading[0] = "Grantor      ";
            $heading[1] = "Type";
            $heading[2] = "Grantee      ";
            $heading[3] = "Type";
            $heading[4] = "Tablespace        ";
          }
          else {
            $heading[0] = "Grantor      ";
            $heading[1] = "Grantee      ";
            $heading[2] = "Granteetype";
            $heading[3] = "Tablespace        ";
          }
          $inReport = "y";
        }

        # Print out the headings

        for ( my $j = 0 ; $j <= $maxLen -1 ; $j++ ) { # for each heading line
          for ( my $k = 0 ; $k <= $#heading ; $k++ ) { # for each column .....
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
          for ( my $i = 0; $i <= $#heading; $i++ ) {
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
          for ( my $i = 0; $i <= $#heading; $i++ ) {
            $heading[$i] = lc($heading[$i]);
            if ( $i >= $horiz_end ) {
              my $spos = 25 + length($heading[$i]) - $maxLen;
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

      for ( my $i = 0 ; $i <= $#detail ; $i++ ) {
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
      if ( $db2Vers >= 9.7 ) {
        $horiz_end = 4;
      }
      else {
        $horiz_end = 2;
      }
    }
    elsif ( $REPNAME eq "syscat.tbspaceauth" ) {
      if ( $db2Vers >= 9.7 ) {
        $horiz_end = 5;
      }
      else {
        $horiz_end = 4;
      }
    }
  }
      
  if ( $_ =~ /SQL1024N/) {
    print "A database connection must be established before running this program\n";
    # 
    # Note this is used rather than next because cancelling of the pipe is very time consuming if it still 
    # has traffic in it. Much (orders of magnitude) quicker to finish reading the data and then close the pipe 
    #
    $abort = 1; 
  }

}

close AUTHPIPE;

if ( $authCount > 0 ) {
  print "\n$authCount auth entries printed\n";
}

if ( $generate eq "Yes" ) {
  print "\nThe generated grants: \n";
  for ( my $i = 0 ; $i <= $#grant ; $i++ ) {
    print "$grant[$i]\n";
  }
}

if ( $OS eq "Windows" ) {
  $x = `del lauthcmd.bat`;
}
else {
  $x = `rm lauthcmd.bat`;
}
