#!/usr/bin/perl
# --------------------------------------------------------------------
# ldball.pl
#
# $Id: ldball.pl,v 1.4 2018/10/18 22:58:51 db2admin Exp db2admin $
#
# Description:
# Script to format the output of a LIST DB DIRECTORY command
# this command varies from the original ldb.pl script in that 
# it will loop through all instances on a server (at least those
# listed by a db2ilist command - so limited to instances at an
# identical software release level).
#
# Usage:
#   ldb.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: ldball.pl,v $
# Revision 1.4  2018/10/18 22:58:51  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.3  2018/10/17 00:56:23  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.2  2014/05/25 22:26:11  db2admin
# correct the allocation of windows include directory
#
# Revision 1.1  2009/08/27 03:57:12  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

my $ID = '$Id: ldball.pl,v 1.4 2018/10/18 22:58:51 db2admin Exp db2admin $';
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
    $scriptDir = 'c:\udbdba\scrxipts';
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

  print STDERR "Usage: $0 -?hsg [-A or -I or -i <instance> or -f <filename>] [-d <database>] [-v[v]] 

      Script to format the output of a LIST DB DIRECTORY command
      this command varies for the original ldb.pl script in that
      it will loop through all instances on a server (at least those
      listed by a db2ilist command - so limited to instances at an
      identical software release level).

      Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode 
       -d              : Database to list (if not entered defaults to ALL)
       -A              : Process all instances for the server
       -I              : Use the current Instance (this is the default)
       -i <instance>   : Use the indicated instance
       -v              : debug level
       -g              : Generate the CATALOG statements to reproduce the entry
       -f              : File name to process 

     \n";
}

# Set default values for variables

$silent = "No";
$inFile = "";
$instance = "XXX";
if ( $OS ne "Windows" ) {
  $db2ilist_dir=`which db2ilist`;
}
else {
  $db2ilist_dir='db2ilist';
}
$debug_level = 0 ;
$database_sel = "";
$genDefs = "No";
$infile = "";
$database_sel="";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsvgf:i:IAd:|^GENDATA";

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
 elsif (($getOpt_optName eq "d") )  {
   $database_sel = $getOpt_optValue;
   if ( $silent ne "Yes") {
     print "Database to select is $database_sel\n";
   }
 }
 elsif (($getOpt_optName eq "g") || ($getOpt_optName eq "GENDATA") )  {
   $genDefs = "Yes";
   if ( $silent ne "Yes") {
     print "Definitions will be generated\n";
   }
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "File $getOpt_optValue will be read instead of accessing the DB2 Catalog\n";
   }
   $infile = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v") )  {
   $debug_level++;
   if ( $silent ne "Yes") {
     print "Debug level set to $debug_level\n";
   }
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( $silent ne "Yes") {
     print "Only Instance $getOpt_optValue will be processed\n";
   }
   $instance = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "A"))  {
   if ( $silent ne "Yes") {
     print "All instances will be processed\n";
   }
   $instance = "";
 }
 elsif (($getOpt_optName eq "I"))  {
   $instance = $ENV{'DB2INSTANCE'};
   if ( $silent ne "Yes") {
     print STDERR "Instance $instance will be processed\n";
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   usage ("Parameter $getOpt_optValue is invalid");
   exit;
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

if ( $instance eq "XXX" ) {
  if ( $silent ne "Yes") {
    print "All Instances will be processed\n";
  }
  $instance = "";
}

# identify all of the Instances on the box ....
if ( $inFile ne "" ) {
  if (! open (INSTPIPE,"<$inFile"))  { die "Can't open $inFile! $!\n"; }
}
else {
  if (! open (INSTPIPE,"$db2ilist_dir | "))  { die "Can't run db2ilist! $!\n"; }
}

while (<INSTPIPE>) {
    if ( $_ =~ /Instance Error encountered/) { next; } # skip this message ....

    if ( $debug_level > 0 ) { print ">$_\n"; }

    $inst = $_;
    chomp $inst;

    if ( $OS ne "Windows" ) {
      $homeDir=`grep $inst /etc/passwd | cut -d":" -f6`;
      chomp $homeDir;
    }
    else {
      $homeDir="c:";
    }

    if ( $instance ne "" && uc($instance) ne uc($inst)) { 
      # skip this instance
      next;
    }
    $ENV{'DB2INSTANCE'} = $inst;

    # Run the command file and process out the databases .....
    if ( $OS eq "Windows" ) {
      if ( ! open (CMDFILE, ">tmpcmd1_db2poll.bat" ) ) {die "Unable to allocate tmpcmd1_db2poll.bat\n $!\n"; }
      print CMDFILE "set DB2INSTANCE=$inst\n";
      print CMDFILE "db2 list db directory >tmpcmd1_db2poll.out\n";
      print CMDFILE "exit\n";
      close CMDFILE;
      $x = `$db2_dir\db2cmd -w tmpcmd1_db2poll.bat`;
      if (! open (DBPIPE,"<tmpcmd1_db2poll.out"))  { die "Can't open tmpcmd1_db2poll.out !\n $!\n"; }
    }
    else {
      if (! open (DBPIPE,". $homeDir/sqllib/db2profile; db2 list db directory | "))  { die "Can't run db2 list ! $!\n"; }
    }

    # Print Headings ....
    if ( $silent ne "Yes") {
      print "Database listing from Machine: $machine Instance: $inst ($Now) .... \n\n";
      printf "%-8s %-8s %-10s %4s %-20s %-40s \n",
             'Alias', 'Database', 'Type', 'Part', 'Comment', 'Directory/Node(Authentication)';
      printf "%-8s %-8s %-10s %4s %-20s %-40s \n",
             '--------', '--------', '----------', '----', '--------------------', '----------------------------------------';
    }

    %catalogDefs = ();

    while (<DBPIPE>) {

      if ( $debug_level > 0 ) { print "### $_\n"; }
    
      #   Database 1 entry:

      #    Database alias                       = GM2STTST
      #    Database name                        = GM2STTST
      #    Local database directory             = /db2/gm2sttst
      #    Database release level               = a.00
      #    Comment                              =
      #    Directory entry type                 = Indirect
      #    Catalog database partition number    = 0
      #    Alternate server hostname            =
      #    Alternate server port number         =


      chomp $_;
      @ldbinfo = split(/=/);

      if ( $debug_level > 0 ) {  print "$ldbinfo[0] : $ldbinfo[1]\n";}

      if ( trim($ldbinfo[0]) eq "Database alias") {
        $DBName = "";
        $NodeName = "";
        $Authentication = "";
        $commlit = "";
        $DBAlias = trim($ldbinfo[1]);
      }

      if ( trim($ldbinfo[0]) eq "Database name") {
        $DBName = trim($ldbinfo[1]);
      }

      if ( trim($ldbinfo[0]) eq "Node name") {
        $NodeName = trim($ldbinfo[1]);
      }

      if ( (trim($ldbinfo[0]) eq "Local database directory") || (trim($ldbinfo[0]) eq "Database drive") ) {
        $localDir = trim($ldbinfo[1]);
      }

      if ( trim($ldbinfo[0]) eq "Authentication") {
        $Authentication = trim($ldbinfo[1]);
      }

      if ( trim($ldbinfo[0]) eq "Comment") {
        $Comment = trim($ldbinfo[1]);
      }

      if ( trim($ldbinfo[0]) eq "Directory entry type") {
        $dirEntryType = trim($ldbinfo[1]);
      }

      if ( (trim($ldbinfo[0]) eq "Catalog database partition number") || (trim($ldbinfo[0]) eq "Catalog node number") ) {
        $catDBPartNum = trim($ldbinfo[1]);
        if ( $dirEntryType eq "Remote") {
          if ( $Authentication eq "" ) {
            $localDir = "$NodeName";
          }
          else {
            $localDir = "$NodeName ($Authentication)";
          }
        }
        if ( $debug_level > 1) { print "catDBPartNum=$catDBPartNum   >>> $database_sel\n";}

        if ( (uc($database_sel) eq uc($DBName)) || (uc($database_sel) eq "") ||  (uc($database_sel) eq uc($DBAlias)) ) {
          $commlit = "";
          if ($comment ne "") {
            $commlit = "with \"$comment\"";
          }
          if ( $dirEntryType eq "Indirect") {
            if ( $silent ne "Yes") {
              printf "%-8s %-8s %-10s %4s %-20s %-40s\n",
                   $DBAlias,$DBName,$dirEntryType,$catDBPartNum,$Comment,$localDir;
            }
            if ( $genDefs eq "Yes") {
              $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias on $localDir $commlit\n";
            }
          }
          else {
            # not a local database so save and print later ....
            $hold{$DBName} = sprintf "%-8s %-8s %-10s %4s %-20s %-40s\n",
                 $DBAlias,$DBName,$dirEntryType,$catDBPartNum,$Comment,$localDir;
            if ( $genDefs eq "Yes") {
              if ( $Authentication eq "" ) {
                $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias at node $NodeName $commlit\n";
              }
              else {
                $catalogDefs{$DBAlias} = "catalog db $DBName as $DBAlias at node $NodeName authentication $Authentication $commlit\n";
              }
            }
            $DBName = "";
            $DBAlias = "";
            $NodeName = "";
            $Authentication = "";
            $commlit = "";
          }
        }
      }
    }

    # Print out the remote databases at the end ....

    if ( $silent ne "Yes") {
      foreach $key (sort by_key keys %hold ) {
        print "$hold{$key}";
      }
    }

    # Print out definitions if required ....

    if ($genDefs eq "Yes") {

      if ( $silent ne "Yes") {
        print "\nGenerated CATALOG DB definitions:\n\n";
      }

      foreach $key (sort by_key keys %catalogDefs ) {
        print "$catalogDefs{$key}";
      }
    }

    if ( $silent ne "Yes") {
      print "\n";
    }
    $lastInst = $inst;
}

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}


