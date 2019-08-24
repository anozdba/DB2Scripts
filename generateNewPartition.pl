#!/usr/bin/perl
# --------------------------------------------------------------------
# generateNewPartition.pl
#
#
# $Id: generateNewPartition.pl,v 1.10 2019/02/11 03:48:26 db2admin Exp db2admin $
#
# Description:
# Script to generate a new partition. The information generated will be:
#
#    Tablespace Create Statement
#    Alter Table Add Partition Statement
#
# Usage:
#   generateNewPartition.pl
#
# $Name:  $
#
# ChangeLog:
# $Log: generateNewPartition.pl,v $
# Revision 1.10  2019/02/11 03:48:26  db2admin
#  remove timeAdd from commonFunctions.pm exported routines
#
# Revision 1.9  2019/01/25 03:12:40  db2admin
# adjust commonFunctions.pm parameter importing to match module definition
#
# Revision 1.8  2018/10/21 21:01:48  db2admin
# correct issue with script when run from windows (initialisation of run directory)
#
# Revision 1.7  2018/10/18 22:58:50  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.6  2018/10/16 23:38:12  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.5  2016/08/02 00:39:33  db2admin
# correct bug that meant lob tablespaces were always created
#
# Revision 1.4  2014/05/22 23:32:40  db2admin
# Add in more diagnostics
# Add in database connect statement
#
# Revision 1.2  2013/08/22 23:24:33  db2admin
# Generate Index and LOB tablespace names even if they aren't created
#
#
# --------------------------------------------------------------------

my $ID = '$Id: generateNewPartition.pl,v 1.10 2019/02/11 03:48:26 db2admin Exp db2admin $';
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
use commonFunctions qw(trim ltrim rtrim commonVersion getOpt myDate $getOpt_web $getOpt_optName $getOpt_min_match $getOpt_optValue getOpt_form @myDate_ReturnDesc $cF_debugLevel  $getOpt_calledBy $parmSeparators processDirectory $maxDepth $fileCnt $dirCnt localDateTime displayMinutes timeDiff  timeAdj convertToTimestamp getCurrentTimestamp);

sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print "\n$_[0]\n\n";
    }
  }

  print "Usage: $0 -?hs -d <database> -S <schema> -T <table> [-k <literal type>] [-g] [-B <tablespace base>] [-t <table partition base>] 
                   [-p <number of partitions>] [-P <pagesize>] [-f file system>] [-b <bufferpool>] [-v[v][v][v]] [-o <STDOUT | FILE>]

       Script to generate a new partition. The information generated will be:

            Tablespace Create Statement
            Alter Table Add Partition Statement

       Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode (dont produce the report)
       -d              : Database in which the partition will exist
       -S              : Table Schema (note that this will be capitalised)
       -T              : Table Name (note that this will be capitalised)
       -k              : literal type [Defaults: YYYYMMDD of low value of new partition]
                         PARTKEY = low value of partition's YYYYMMDD (this is the default)
                         TODAY = today's YYYYMMDD
                         <other> = Just use this literal
       -g              : output all commands to STDOUT
       -o              : Where to place the generated output:
                         STDOUT (same as -g) 
                         FILE (to multiple files in sql directory) 
                         <other> (single filename in sql directory)
       -t              : partition base (Default: same as last partition)
       -B              : base tablespace (Default: same as last partition)
       -p              : number of partitions (Default: same as existing table)
       -P              : pagesize (Default: same as last partition)
       -b              : bufferpool (Default: same as last partition)
       -f              : File system to create partition in (Default: same as last partition)
       -v              : debug level

       Note: Skeletons for the commands produced are in:
                   scripts/SKL_PART_TS_CREATE.skl    - Create a set of new tablespaces for the new partition
                   scripts/SKL_PART_ALTER_TABLE.skl  - Add the new partition to the table
                   scripts/SKL_PART_DETACH.skl       - Drop the old detached table and detach the youngest partition
                   scripts/SKL_PART_TS_DROP.skl      - Drop the tablespaces that the detached table is using

           : You can override the filesystems to be used for specific partitions by using an override file
             A file named scripts/partitionOverrides_<tablename>.txt (where <tablename> is the -T parameter value) should be created
             and populated as :
             partitionKey,data filesystem,indexfilesystem,lob filesystem

             any of the file systems can be blank and then the normal defaults will be used or the partitionKey can be * in which case 
             all partitions will match    
";
}

if ( $OS eq "Windows" ) {
  print "This command only available for Unix at the moment\n\n";
  exit;
}

$database = "";
$table = "";
$schema = "";
$baseTablespace = "";
$basePart = "";
$numPartitions = "";
$pagesize = "";
$fileSystem = "";
$bufferpool = "";
$debugLevel = 0;
$partKeyLit = "";
$display="STDOUT";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsvgo:d:k:S:t:T:b:B:p:P:f:";

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
 elsif (($getOpt_optName eq "f"))  {
   if ( $silent ne "Yes") {
     print "File system $getOpt_optValue will be used\n";
   }
   $fileSystem = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "o"))  {
   if ( $silent ne "Yes") {
     print "Partition key literal will be $getOpt_optValue\n";
   }
   $display = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "k"))  {
   if ( $silent ne "Yes") {
     print "Partition key literal will be $getOpt_optValue\n";
   }
   $partKeyLit = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "d"))  {
   if ( $silent ne "Yes") {
     print "Database $getOpt_optValue will be used\n";
   }
   $database = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "b"))  {
   if ( $silent ne "Yes") {
     print "Bufferpool $getOpt_optValue will be used\n";
   }
   $bufferpool = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "P"))  {
   if ( $silent ne "Yes") {
     print "Pagesize $getOpt_optValue will be used\n";
   }
   $pagesize = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "p"))  {
   if ( $silent ne "Yes") {
     print "Number of Partitions to be used is $getOpt_optValue\n";
   }
   $numPartitions = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "g"))  {
   if ( $silent ne "Yes") {
     print "Commands will be output to STDOUT\n";
   }
   $display = "STDOUT";
 }
 elsif (($getOpt_optName eq "B"))  {
   if ( $silent ne "Yes") {
     print "Base Tablespace $getOpt_optValue will be used\n";
   }
   $baseTablespace = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "Base Table $getOpt_optValue will be used\n";
   }
   $basePart = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "T"))  {
   if ( $silent ne "Yes") {
     print "Table $getOpt_optValue will be used\n";
   }
   $table = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "Schema $getOpt_optValue will be used\n";
   }
   $schema = uc($getOpt_optValue);
 }
 elsif (($getOpt_optName eq "v"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "Debug Level set to $debugLevel\n";
   }
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   if ( $database eq "" ) {
     $database = getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Database $getOpt_optValue will be used\n";
     }
   }
   elsif ( $schema eq "" ) {
     $schema = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Schema $getOpt_optValue will be used\n";
     }
   }
   elsif ( $table eq "" ) {
     $table = $getOpt_optValue;
     if ( $silent ne "Yes") {
       print "Table $getOpt_optValue will be used\n";
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
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$month = $month + 1;
$hour = substr("0" . $hour, length($hour)-1,2);
$minute = substr("0" . $minute, length($minute)-1,2);
$second = substr("0" . $second, length($second)-1,2);
$month = substr("0" . $month, length($month)-1,2);
$day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
$Now = "$year.$month.$day $hour:$minute:$second";
$DS = "$year$month$day";

if ($database eq "") {
  usage ("Database Parameter (-d) must be entered");
  exit;
}
if ($schema eq "") {
  usage ("Schema Parameter (-S) must be entered");
  exit;
}
if ($table eq "") {
  usage ("Table Parameter (-T) must be entered");
  exit;
}

if ( $debugLevel > 2 ) {
  $a = `scripts/runSQL.pl -p %%DATABASE%%=$database,%%SCHEMA%%=$schema,%%TABLE%%=$table -f sql/partitionInformation.sql`;
  print $a;
}

@tbspaceOrideData = (); # clear array
@tbspaceOrideIndex = (); # clear array
@tbspaceOrideLob = (); # clear array
if ( open (STORORIDE, "<scripts/partitionOverrides_$table.txt") ) {
  while ( <STORORIDE> ) {
    @tmp = split (',',$_);
    $tbspaceOrideData{$tmp[0]} = trim($tmp[1]);
    $tbspaceOrideIndex{$tmp[0]} = trim($tmp[2]);
    $tbspaceOrideLob{$tmp[0]} = trim($tmp[3]);
  }
}
else {
  print "No tablespace override information to load\nFile scripts/partitionOverrides_$table.txt not found \n";
}

if ( $debugLevel > 1 ) {
  print "Tablespace Overrides:\n";
  foreach $key (sort by_key keys %tbspaceOride ) {
    print "$key: $tbspaceOride{$key}";
  }
  print "\n";
}

if (! open (PARTPIPE,"scripts/runSQL.pl -sp %%DATABASE%%=$database,%%SCHEMA%%=$schema,%%TABLE%%=$table -f sql/partitionInformation.sql | db2 -tx +wp | grep 'DTL>' | "))  { die "Can't run partition information SQL (sql/partitionInformation.sql)! $!\n"; }

while (<PARTPIPE>) {

   chomp $_;
   if ( $debugLevel > 2 ) { print "$_\n"; }
   @partinfo = split(" ");

   if ( $debugLevel > 1 ) {
     print "Split input string ($#partinfo pieces):\n";
     for ($i=0; $i <= $#partinfo; $i++) {
       print "\$partinfo[$i] = $partinfo[$i]\n";
     }
   }

   $DTL_numParts = $partinfo[1];
   $DTL_maxLPART_High = $partinfo[2];
   $DTL_minLPART_Low = $partinfo[3];
   $DTL_dataTSID = $partinfo[4];
   $DTL_lobTSID = $partinfo[5];
   $DTL_indexTSID = $partinfo[6];
   $DTL_newPART_Low = $partinfo[7];
   $DTL_newPART_High = $partinfo[8];
   $DTL_partName = $partinfo[9];
   $DTL_dataTS = $partinfo[10];
   $DTL_dataPage = $partinfo[11];
   $DTL_dataBP = $partinfo[12];
   $DTL_dataContainer = $partinfo[13];
   $DTL_lobTS = $partinfo[14];
   $DTL_lobPage = $partinfo[15];
   $DTL_lobBP = $partinfo[16];
   $DTL_lobContainer = $partinfo[17];
   $DTL_indexTS = $partinfo[18];
   $DTL_indexPage = $partinfo[19];
   $DTL_indexBP = $partinfo[20];
   $DTL_indexContainer = $partinfo[21];
   $DTL_firstPartName = $partinfo[22];
   $DTL_firstPartDataTSName = $partinfo[23];
   $DTL_firstPartIndexTSName = $partinfo[24];
   $DTL_firstPartLobTSName = $partinfo[25];
   $DTL_detachedPartDataTSName = $partinfo[26];
   $DTL_detachedPartIndexTSName = $partinfo[27];
   $DTL_detachedPartLobTSName = $partinfo[28];
   $DTL_dataPages = $partinfo[29];
   $DTL_indexPages = $partinfo[30];
   $DTL_lobPages = $partinfo[31];

   if ( $debugLevel > 1 ) {
     print "DTL_numParts=$DTL_numParts\n";
     print "DTL_partName=$DTL_partName\n";
     print "DTL_maxLPART_High=$DTL_maxLPART_High\n";
     print "DTL_minLPART_Low=$DTL_minLPART_Low\n";
     print "DTL_newPART_Low=$DTL_newPART_Low\n";
     print "DTL_newPART_High=$DTL_newPART_High\n";
     print "DTL_dataTSID=$DTL_dataTSID\n";
     print "DTL_lobTSID=$DTL_lobTSID\n";
     print "DTL_indexTSID=$DTL_indexTSID\n";
     print "DTL_dataTS=$DTL_dataTS \n";
     print "DTL_dataPage=$DTL_dataPage\n";
     print "DTL_dataBP=$DTL_dataBP\n";
     print "DTL_dataContainer=$DTL_dataContainer\n";
     print "DTL_lobTS=$DTL_lobTS\n";
     print "DTL_lobPage=$DTL_lobPage\n";
     print "DTL_lobBP=$DTL_lobBP\n";
     print "DTL_lobContainer=$DTL_lobContainer\n";
     print "DTL_indexTS=$DTL_indexTS\n";
     print "DTL_indexPage=$DTL_indexPage\n";
     print "DTL_indexBP=$DTL_indexBP\n";
     print "DTL_indexContainer=$DTL_indexContainer\n";
     print "DTL_firstPartName=$DTL_firstPartName\n";
     print "DTL_firstPartDataTSName=$DTL_firstPartDataTSName\n";
     print "DTL_firstPartIndexTSName=$DTL_firstPartIndexTSName\n";
     print "DTL_firstPartLobTSName=$DTL_firstPartLobTSName\n";
     print "DTL_detachedPartDataTSName=$DTL_detachedPartDataTSName\n";
     print "DTL_detachedPartIndexTSName=$DTL_detachedPartIndexTSName\n";
     print "DTL_detachedPartLobTSName=$DTL_detachedPartLobTSName\n";
     print "DTL_dataPages=$DTL_dataPages\n";
     print "DTL_indexPages=$DTL_indexPages\n";
     print "DTL_lobPages=$DTL_lobPages\n";
   }

   $suffLength = 8;

   if ( $numPartitions eq "" ) { # if the number of partitions isn't set then default it to the number that exists
     $numPartitions = $DTL_numParts;
   }

   # set up the partitioning literal

   if ( uc($partKeyLit) eq "TODAY" ) {
     $partKey = $DS;
   }
   elsif ( $partKeyLit eq "" ) {
     $partKey = $DS;
   }
   elsif ( uc($partKeyLit) eq "PARTKEY" ) {
     $partKey = substr($DTL_newPART_Low,0,4) . substr($DTL_newPART_Low,5,2). substr($DTL_newPART_Low,8,2);
   }
   else { 
     $partKey = $partKeyLit;
   }

   if ( $debugLevel > 0 ) { print "Partition literal will be $partKey\n"; }

   # Data partition always needs to be created

   $dataPartName = $basePart;
   if ( $dataPartName eq "" ) {
     $dataPartName = substr($DTL_partName,0,length($DTL_partName)-9);
     if ( $debugLevel > 0 ) { print "dataPartName has been set to $dataPartName\n"; }
   }

   $dataFileSystem = $fileSystem;
   # check for overrides
   if ( defined($tbspaceOrideData{$partKey}) || defined($tbspaceOrideData{'*'}) ) { 
     if ( defined($tbspaceOrideData{$partKey}) && ($tbspaceOrideData{$partKey} ne "" ) ) {
       $dataFileSystem = $tbspaceOrideData{$partKey};
       if ( $debugLevel > 0 ) { print "dataFilesystem overridden. Set to $dataFileSystem\n"; }
     }
     elsif ( defined($tbspaceOrideData{'*'})  && ($tbspaceOrideData{'*'} ne "" ) ) {
       $dataFileSystem = $tbspaceOrideData{'*'};
       if ( $debugLevel > 0 ) { print "dataFilesystem overridden. Set to $dataFileSystem\n"; }
     }
   }

   if ( $dataFileSystem eq "" ) { # generate a default value
     if ( index($DTL_dataContainer,'/') > -1 ) { # a / exists in the string
       $dataFileSystem = substr($DTL_dataContainer,0,rindex($DTL_dataContainer,'/')); 
     }
     if ( $debugLevel > 0 ) { print "data fileSystem has been set to $dataFileSystem\n"; }
   }

   $baseDataTablespace = $baseTablespace;
   if ( $baseDataTablespace eq "" ) { # generate a default value (Tablespace name is of the form AAAAAAAAAZYYYYMMDD)
     if ( length($DTL_dataTS) > $suffLength ) { # tablespace is longer than $suffLength chars so can be truncated
       $baseDataTablespace = substr($DTL_dataTS,0,length($DTL_dataTS)-$suffLength); 
     }
     else {
       $baseDataTablespace = $DTL_dataTS; 
     }
     if ( $debugLevel > 0 ) { print "data baseTablespace has been set to $baseDataTablespace\n"; }
   }

   $dataPagesize = $pagesize;
   if ( $dataPagesize eq "" ) { # generate a default value
     $dataPagesize = $DTL_dataPage;
     if ( $debugLevel > 0 ) { print "data pagesize has been set to $dataPagesize\n"; }
   }

   $dataBufferpool = $bufferpool;
   if ( $dataBufferpool eq "" ) { # generate a default value
     $dataBufferpool = $DTL_dataBP;
     if ( $debugLevel > 0 ) { print "data bufferpool has been set to $dataBufferpool\n"; }
   }

   $dataFile = "${dataFileSystem}/${baseDataTablespace}_${partKey}_000.dbf";
   $dataTSName = "${baseDataTablespace}${partKey}";

   $dataDef = `scripts/runSQL.pl -sp %%TSNAME%%=$dataTSName,%%PAGESIZE%%=$dataPagesize,%%FILE%%=$dataFile,%%BUFFERPOOL%%=$dataBufferpool,%%PAGES%%=$DTL_dataPages -f scripts/SKL_PART_TS_CREATE.skl`;

   if ( $debugLevel > 0 ) { print "Connection def :\n\nconnect to $database;\n"; }
   if ( $display eq "STDOUT" ) { print "connect to $database;\n"; }
   elsif( $display eq "FILE" ) { $a = `echo "connect to $database;" >sql/PRT_${table}_Create_Tablespace.sql` }
   else { $a = `echo "connect to $database;\n" >sql/$display.sql` }

   if ( $debugLevel > 0 ) { print "Tablespace def :\n\n$dataDef\n"; }
   if ( $display eq "STDOUT" ) { print "$dataDef\n"; }
   elsif( $display eq "FILE" ) { $a = `echo "$dataDef" >>sql/PRT_${table}_Create_Tablespace.sql` }
   else { $a = `echo "$dataDef\n" >>sql/$display.sql` }

   # Generate all of the index variables even if we dont need the tablespace as they are required for the ADD PARTITION

   $indexFileSystem = $fileSystem;
   # check for overrides
   if ( defined($tbspaceOrideIndex{$partKey}) || defined($tbspaceOrideIndex{'*'}) ) {
     if ( defined($tbspaceOrideIndex{$partKey}) && ($tbspaceOrideIndex{$partKey} ne "" ) ) {
       $IndexFileSystem = $tbspaceOrideIndex{$partKey};
       if ( $debugLevel > 0 ) { print "indexFilesystem overridden. Set to $indexFileSystem\n"; }
     }
     elsif ( defined($tbspaceOrideIndex{'*'}) && ($tbspaceOrideIndex{'*'} ne "" ) ) {
       $IndexFileSystem = $tbspaceOrideIndex{'*'};
       if ( $debugLevel > 0 ) { print "indexFilesystem overridden. Set to $indexFileSystem\n"; }
     }
   }

   if ( $indexFileSystem eq "" ) { # generate a default value
     if ( index($DTL_indexContainer,'/') > -1 ) { # a / exists in the string
       $indexFileSystem = substr($DTL_indexContainer,0,rindex($DTL_indexContainer,'/'));
     }
     if ( $debugLevel > 0 ) { print "index fileSystem has been set to $indexFileSystem\n"; }
   }

   $baseIndexTablespace = $baseTablespace;
   if ( $baseIndexTablespace eq "" ) { # generate a default value (Tablespace name is of the form AAAAAAAAAZYYYYMMDD)
     if ( length($DTL_indexTS) > $suffLength ) { # tablespace is longer than $suffLength chars so can be truncated
       $baseIndexTablespace = substr($DTL_indexTS,0,length($DTL_indexTS)-$suffLength);
     }
     else {
       $baseIndexTablespace = $DTL_indexTS;
     }
     if ( $debugLevel > 0 ) { print "baseIndexTablespace has been set to $baseIndexTablespace\n"; }
   }

   $indexPagesize = $pagesize;
   if ( $indexPagesize eq "" ) { # generate a default value
     $indexPagesize = $DTL_indexPage;
     if ( $debugLevel > 0 ) { print "index pagesize has been set to $indexPagesize\n"; }
   }

   $indexBufferpool = $bufferpool;
   if ( $indexBufferpool eq "" ) { # generate a default value
     $indexBufferpool = $DTL_indexBP;
     if ( $debugLevel > 0 ) { print "index bufferpool has been set to $indexBufferpool\n"; }
   }

   $indexFile = "${indexFileSystem}/${baseIndexTablespace}_${partKey}_000.dbf";
   $indexTSName = "${baseIndexTablespace}${partKey}";

   # Check to see if we need a INDEX tablespace ......

   if ( $DTL_dataTSID ne $DTL_indexTSID ) { # index tablespace different to the data tablespace

     $indexDef = `scripts/runSQL.pl -sp %%TSNAME%%=$indexTSName,%%PAGESIZE%%=$indexPagesize,%%FILE%%=$indexFile,%%BUFFERPOOL%%=$indexBufferpool,%%PAGES%%=$DTL_indexPages -f scripts/SKL_PART_TS_CREATE.skl`;

     if ( $debugLevel > 0 ) { print "Tablespace Index def :\n\n$indexDef\n"; }
     if ( $display eq "STDOUT" ) { print "$indexDef\n"; }
     elsif( $display eq "FILE" ) { $a = `echo "$indexDef" >>sql/PRT_${table}_Create_Tablespace.sql` }
     else { $a = `echo "$indexDef\n" >>sql/$display.sql` }
   }
   else { # index tablespace is the same as the data tablespace so no need to generate new index one
     if ( $debugLevel > 0 ) { print "\nIndex tablespace not generated - same as data tablespace\n\n"; }
   }

   # Generate all of the lob variables even if we dont need the tablespace as they are required for the ADD PARTITION

   $lobFileSystem = $fileSystem;
   # check for overrides
   if ( defined($tbspaceOrideLob{$partKey}) || defined($tbspaceOrideLob{'*'}) ) {
     if ( defined($tbspaceOrideLob{$partKey}) && ($tbspaceOrideLob{$partKey} ne "" ) ) {
       $lobFileSystem = $tbspaceOrideLob{$partKey};
       if ( $debugLevel > 0 ) { print "lobFilesystem overridden. Set to $lobFileSystem\n"; }
     }
     elsif ( defined($tbspaceOrideLob{'*'}) && ($tbspaceOrideLob{'*'} ne "" ) ) {
       $lobFileSystem = $tbspaceOrideLob{'*'};
       if ( $debugLevel > 0 ) { print "lobFilesystem overridden. Set to $lobFileSystem\n"; }
     }
   }

   if ( $lobFileSystem eq "" ) { # generate a default value
     if ( index($DTL_lobContainer,'/') > -1 ) { # a / exists in the string
       $lobFileSystem = substr($DTL_lobContainer,0,rindex($DTL_lobContainer,'/'));
     }
     if ( $debugLevel > 0 ) { print "lob fileSystem has been set to $lobFileSystem\n"; }
   }

   $baseLobTablespace = $baseTablespace;
   if ( $baseLobTablespace eq "" ) { # generate a default value (Tablespace name is of the form AAAAAAAAAZYYYYMMDD)
     if ( length($DTL_lobTS) > $suffLength ) { # tablespace is longer than $suffLength chars so can be truncated
       $baseLobTablespace = substr($DTL_lobTS,0,length($DTL_lobTS)-$suffLength);
     }
     else {
       $baseLobTablespace = $DTL_lobTS;
     }
     if ( $debugLevel > 0 ) { print "baseLobTablespace has been set to $baseLobTablespace\n"; }
   }

   $lobPagesize = $pagesize;
   if ( $lobPagesize eq "" ) { # generate a default value
     $lobPagesize = $DTL_lobPage;
     if ( $debugLevel > 0 ) { print "lob pagesize has been set to $lobPagesize\n"; }
   }

   $lobBufferpool = $bufferpool;
   if ( $lobBufferpool eq "" ) { # generate a default value
     $lobBufferpool = $DTL_lobBP;
     if ( $debugLevel > 0 ) { print "lob bufferpool has been set to $lobBufferpool\n"; }
   }

   $lobFile = "${lobFileSystem}/${baseLobTablespace}_${partKey}_000.dbf";
   $lobTSName = "${baseLobTablespace}${partKey}";

   # Check to see if we need a LONG tablespace ......

   if ( ($DTL_dataTSID ne $DTL_lobTSID) && ($DTL_indexTSID ne $DTL_lobTSID) ) { # long tablespace should be produced

     $lobDef = `scripts/runSQL.pl -sp %%TSNAME%%=$lobTSName,%%PAGESIZE%%=$lobPagesize,%%FILE%%=$lobFile,%%BUFFERPOOL%%=$lobBufferpool,%%PAGES%%=$DTL_lobPages -f scripts/SKL_PART_TS_CREATE.skl`;

     if ( $debugLevel > 0 ) { print "Tablespace Lob def :\n\n$lobDef\n"; }
     if ( $display eq "STDOUT" ) { print "$lobDef\n"; }
     elsif( $display eq "FILE" ) { $a = `echo "$lobDef" >>sql/PRT_${table}_Create_Tablespace.sql` }
     else { $a = `echo "$lobDef\n" >>sql/$display.sql` }
   }
   else { # lob tablespace is a duplicate so no need to generate
     if ( $debugLevel > 0 ) { print "\nLob tablespace not generated - same as data or index tablespace\n\n"; }
   }

   # Now to see about the alter table create partition statement .....

   $newPart = "${dataPartName}_$partKey";
   $partCreate = `scripts/runSQL.pl -sp %%SCHEMA%%=$schema,%%TABLE%%=$table,%%PARTNAME%%=$newPart,%%STARTKEY%%=$DTL_newPART_Low,%%ENDKEY%%=$DTL_newPART_High,%%DATATS%%=$dataTSName,%%INDEXTS%%=$indexTSName,%%LOBTS%%=$lobTSName -f scripts/SKL_PART_ALTER_TABLE.skl`;
   if ( $debugLevel > 0 ) { print "Add partition command :\n\n$partCreate\n"; }
   if ( $display eq "STDOUT" ) { print "$partCreate\n"; }
   elsif( $display eq "FILE" ) { $a = `echo "$partCreate" >sql/PRT_${table}_Add_Partition.sql` }
   else { $a = `echo "$partCreate" >>sql/$display.sql` }

   # now look to generate commands to drop the first objects ....

   if ( $DTL_numParts >= $numPartitions ) { # only drop partitions if the number of partitions in the table equals or is greater then the value supplied as -p option

     # generate the detach partition statements and the drop command 
     $partDetach = `scripts/runSQL.pl -sp %%SCHEMA%%=$schema,%%TABLE%%=$table,%%PARTNAME%%=$DTL_firstPartName -f scripts/SKL_PART_DETACH.skl`;
     if ( $debugLevel > 0 ) { print "Detach partition command :\n\n$partDetach\n"; }
     if ( $display eq "STDOUT" ) { print "$partDetach\n"; }
     elsif( $display eq "FILE" ) { $a = `echo "$partDetach" >sql/PRT_${table}_Detach_Partition.sql` }
     else { $a = `echo "$partDetach" >>sql/$display.sql` }

     if ( $DTL_detachedPartDataTSName eq '-' ) { # table _DETACHED_PART hasn't been created yet so dont drop the tablespaces

       if ( $display eq "STDOUT" ) { print "-- ${table}_DETACHED_PART hasn't been created yet so no drop tablespaces will be generated\n"; }
       elsif( $display eq "FILE" ) { $a = `echo "-- ${table}_DETACHED_PART hasn't been created yet so no drop tablespaces will be generated" >sql/PRT_${table}_Drop_Tablespace.sql` }
       else { $a = `echo "-- ${table}_DETACHED_PART hasn't been created yet so no drop tablespaces will be generated" >>sql/$display.sql` }

     }
     else { # tablespaces there to be dropped
   
       # generate the drop tablespace commands for the detached table
       $dropTablespace = `scripts/runSQL.pl -sp %%TABLESPACE%%=$DTL_detachedPartDataTSName -f scripts/SKL_PART_TS_DROP.skl`;
       if ( $debugLevel > 0 ) { print "Drop data tablespace command :\n\n$dropTablespace\n"; }
       if ( $display eq "STDOUT" ) { print "$dropTablespace\n"; }
       elsif( $display eq "FILE" ) { $a = `echo "$dropTablespace" >sql/PRT_${table}_Drop_Tablespace.sql` }
       else { $a = `echo "$dropTablespace" >>sql/$display.sql` }
       
       if ( $DTL_detachedPartDataTSName ne $DTL_detachedPartIndexTSName ) {
         if ( $DTL_detachedPartIndexTSName ne 'NONE' ) {
           $dropTablespace = `scripts/runSQL.pl -sp %%TABLESPACE%%=$DTL_detachedPartIndexTSName -f scripts/SKL_PART_TS_DROP.skl`;
           if ( $debugLevel > 0 ) { print "Drop index tablespace command :\n\n$dropTablespace\n"; }
           if ( $display eq "STDOUT" ) { print "$dropTablespace\n"; }
           elsif( $display eq "FILE" ) { $a = `echo "$dropTablespace" >>sql/PRT_${table}_Drop_Tablespace.sql` }
           else { $a = `echo "$dropTablespace" >>sql/$display.sql` }
         }
       }

       if ( ($DTL_detachedPartDataTSName ne $DTL_detachedPartLobTSName) && ($DTL_detachedPartLobTSName ne $DTL_detachedPartIndexTSName) ) {
         if ( $DTL_detachedPartLobTSName ne 'NONE' ) {
           $dropTablespace = `scripts/runSQL.pl -sp %%TABLESPACE%%=$DTL_detachedPartLobTSName -f scripts/SKL_PART_TS_DROP.skl`;
           if ( $debugLevel > 0 ) { print "Drop lob tablespace command :\n\n$dropTablespace\n"; }
           if ( $display eq "STDOUT" ) { print "$dropTablespace\n"; }
           elsif( $display eq "FILE" ) { $a = `echo "$dropTablespace" >>sql/PRT_${table}_Drop_Tablespace.sql` }
           else { $a= `echo "$dropTablespace" >>sql/$display.sql` }
         }
       }

     }
     
   }

}


#  foreach $key (sort by_key keys %catalogDefs ) {
#    print "$catalogDefs{$key}";
#  }

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}

