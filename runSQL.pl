#!/usr/bin/perl
# --------------------------------------------------------------------
# runSQL.pl
#
# $Id: runSQL.pl,v 1.10 2017/02/27 09:13:23 db2admin Exp db2admin $
#
# Description:
# Script to process multiple parameter changes toa file and output the result to STDOUT
#
# Typical usage would be:
#   runSQL.pl -sp %%DATABASE%%=CQCOMMON,%%MACHINE%%=MPLB2B002 -f sql/cleanupSQL.sql | db2 -vm
#
# $Name:  $
#
# ChangeLog:
# $Log: runSQL.pl,v $
# Revision 1.10  2017/02/27 09:13:23  db2admin
# Convert to use the commonFunctions package
#
# Revision 1.9  2016/08/08 05:05:33  db2admin
# display the run time of the script if not in solent mode
#
# Revision 1.8  2014/05/25 22:32:31  db2admin
# correct the allocation of windows include directory
#
# Revision 1.7  2012/12/05 05:27:54  db2admin
# Add in lower case substitution values for database and instance
#
# Revision 1.6  2012/02/07 04:45:28  db2admin
# Add in parameter to specify the parameter delimiter
#
# Revision 1.5  2010/10/27 05:18:39  db2admin
# add in oracle script library
#
# Revision 1.4  2010/10/21 05:08:05  db2admin
# add in ORACLE_SID for ##INSTANCE## and home directory for ##HOME##
#
# Revision 1.3  2010/03/05 00:15:30  db2admin
# Alter script to allow passed parameters to include ## variables
#
# Revision 1.2  2009/12/30 03:21:09  db2admin
# Add in version detail
#
# Revision 1.1  2009/12/30 02:48:08  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

$ID = '$Id: runSQL.pl,v 1.10 2017/02/27 09:13:23 db2admin Exp db2admin $';
@V = split(/ /,$ID);
$Version=$V[2];
$Changed="$V[3] $V[4]";

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs -p <parameters> [-f <filename>] [-d <parm delimiter>]
       -h or -?        : This help message
       -s              : Silent mode 
       -p              : parameters to change of the form \"parm=value,parm=value\"
       -d              : parameter delimiter (defaults to comma)
       -f              : File to be processed
       -v              : verbose mode (debugging)

       Version $Version Last Changed on $Changed (UTC)

  NOTE: Command may include the following variables that will be substituted:
             ##MACHINE##  - Will be replaced by the machine name the command is running on
             ##INSTANCE## - Will be replaced by the value of the DB2INSTANCE or ORACLE_SID environment variable
             ##YYYYMMDD## - Will be replaced by the date in YYYYMMDD format
             ##TS##       - Will be replaced by the current timestamp (at start of script) in YY-MM-DD-HH.MM.SS format
             ##HOME##     - Will be replaced by the home directory of the current user (for windows it will be replaced with c:\users\oraadmin)
             ##NL##       - Will be replaced by a new line 
     \n";
}

BEGIN {
  if ( $^O eq "MSWin32") {
    $machine = `hostname`;
    $OS = "Windows";
    $scriptDir = 'c:\udbdba\scrxipts';
    $tmp = rindex($0,'\\');
    $user = $ENV{'USERNAME'};
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $dirsep = '\\';
  }
  else {
    $machine = `uname -n`;
    $machine_info = `uname -a`;
    @mach_info = split(/\s+/,$machine_info);
    $OS = $mach_info[0] . " " . $mach_info[2];
    $scriptDir = "scripts";
    $user = `id | cut -d '(' -f 2 | cut -d ')' -f 1`;
    $tmp = rindex($0,'/');
    if ($tmp > -1) {
      $scriptDir = substr($0,0,$tmp+1)  ;
    }
    $dirsep = '/';
  }
}

use lib "$scriptDir";

use commonFunctions qw(getOpt myDate trim $getOpt_optName $getOpt_optValue @myDate_ReturnDesc $myDate_debugLevel);

# Set default values for variables

$silent = "No";
$parameter = "";
$inFile = "";
$debugLevel = 0;
$delim = ',';

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsvp:d:f:";

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
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print STDERR "Debug level now set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print STDERR "Parameters to be substituted are : $getOpt_optValue\n";
   }
   $parameter = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print STDERR "Parameter delimiter to be used will be $getOpt_optValue\n";
   }
   $delim = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print STDERR "File to be processed is $getOpt_optValue\n";
   }
   $inFile = $getOpt_optValue;
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $parameter eq "" ) {
     $parameter = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print STDERR "Parameters to be substituted are : $getOpt_optValue\n";
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
$NowTS = "$year-$month-$day-$hour.$minute.$second";
$YYYYMMDD = "$year$month$day";

if ( $silent ne "Yes") { print STDERR "Starting $Now\n"; }

# process the parameters. They are of the form parm=value,parm=value,etc

@fsplit = split($delim,$parameter);

foreach $tuple (@fsplit) {
  ($parm,$val) = split("=",$tuple);
  if ($debugLevel > 0 ) { print "Parameter $parm has a value of $val\n"; }
  if ( trim($parm) ne "" ) {
    $parms{$parm} = $val;
  }
}

# open the file to process ....
if ( $inFile ne "" ) {
  if (! open (INFILE,"<$inFile"))  { die "Can't open $inFile! $!\n"; }
}
else {
  if (! open (INFILE,"-"))  { die "Can't open STDIN ! $!\n"; }
}

undef $/;
# Read input file as one long record.
$prtdata=<INFILE>;
close INFILE;

$instance = $ENV{'DB2INSTANCE'};
if ( $instance eq "" ) {
  $instance = $ENV{'ORACLE_SID'};
}

# substitute each of the entered parameters ...

foreach $prm (keys %parms) {
  if ( $debugLevel > 0 ) { print "Parameter $prm is being substituted with a value of $parms{$prm}\n"; }
  $prtdata =~ s/$prm/$parms{$prm}/gm;
}

# substitute each of the static parameters ...

$lc_machine = lc($machine);
$lc_instance = lc($instance);

$prtdata =~ s/##MACHINE##/$machine/gm;
$prtdata =~ s/##LC_MACHINE##/$lc_machine/gm;
$prtdata =~ s/##YYYYMMDD##/$YYYYMMDD/gm;
$prtdata =~ s/##INSTANCE##/$instance/gm;
$prtdata =~ s/##LC_INSTANCE##/$lc_instance/gm;
$prtdata =~ s/##HOME##/$home/gm;
$prtdata =~ s/##TS##/$NowTS/gm;

#if (! open(OUTPUT,">$filelist[$i]") ) {
#   print STDERR "Can't open file $filelist[$i] for output\n";
#   exit;
#}

print STDOUT "$prtdata";

