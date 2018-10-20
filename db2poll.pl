#!/usr/bin/perl
# --------------------------------------------------------------------
# db2poll.pl
#
# $Id: db2poll.pl,v 1.47 2018/10/18 22:58:48 db2admin Exp db2admin $
#
# Description:
# Loops through a selection of databases determined through parameters and connect to each.
#
# $Name:  $
#
# ChangeLog:
# $Log: db2poll.pl,v $
# Revision 1.47  2018/10/18 22:58:48  db2admin
# correct issue with script when not run from home directory
#
# Revision 1.46  2018/10/16 22:01:09  db2admin
# convert from commonFunction.pl to commonFunctions.pm
#
# Revision 1.45  2017/04/05 04:27:47  db2admin
# correct issue where warning message not being reinitialised
#
# Revision 1.44  2017/02/13 00:22:48  db2admin
# treat an EXCEPT status as an ok status
#
# Revision 1.43  2016/10/04 04:02:44  db2admin
# move prtg snmp server to mplmon02prd
#
# Revision 1.42  2016/05/13 01:12:17  db2admin
# Add in the PRTG SNMP server temporarily
# as a dupliacte target
#
# Revision 1.41  2015/03/18 22:37:43  db2admin
# added in message ORA-12170 9TNS timeout) as an error
#
# Revision 1.40  2014/04/22 04:41:15  db2admin
# also add in blank passwords for remote unix boxes
#
# Revision 1.39  2014/04/22 04:30:48  db2admin
# add in blank password for unix boxes (R1 mainly)
#
# Revision 1.38  2014/02/25 01:56:47  db2admin
# adjust poller sothat it raises the appropriate snmp messages at the appropriate times
#
# Revision 1.37  2014/02/24 04:36:53  db2admin
# correct problem where connection failures aren't logged correctly
#
# Revision 1.36  2014/02/24 03:35:01  db2admin
# add in code to track the time of state changes
#
# Revision 1.35  2014/02/24 02:29:15  db2admin
# remove duplicate error checking
#
# Revision 1.34  2014/02/18 00:42:54  db2admin
# Add in redirection for SQLServer snmp traps
#
# Revision 1.33  2014/02/17 21:05:58  db2admin
# test
#
# Revision 1.32  2014/02/17 20:57:42  db2admin
# add in SQLServer checking
#
# Revision 1.31  2014/02/05 03:04:19  db2admin
# Add the domain to DEFAULT_LOGIN account
#
# Revision 1.30  2014/02/03 23:39:59  db2admin
# Ensure that option -L works for remote connections
#
# Revision 1.29  2014/02/03 22:40:05  db2admin
# Add in option to connect using id DEFAULT_LOGIN
#
# Revision 1.28  2014/02/03 01:48:19  db2admin
# Try and isolate real error message
#
# Revision 1.27  2014/02/03 01:24:49  db2admin
# Only save the last line of error messages
#
# Revision 1.26  2014/02/03 00:15:32  db2admin
# add history of received msssages
#
# Revision 1.25  2013/11/21 03:44:29  db2admin
# and again
#
# Revision 1.24  2013/11/21 03:42:01  db2admin
# corrected it again
#
# Revision 1.23  2013/11/21 03:40:11  db2admin
# Correct snmp parameters
#
# Revision 1.22  2013/11/21 00:13:40  db2admin
# Add in snmp functionality via the -W parameter
#
# Revision 1.21  2012/12/23 20:50:34  db2admin
# Add in SQL1336N
#
# Revision 1.20  2012/09/12 06:27:17  db2admin
# Add in ORA-12514
#
# Revision 1.19  2012/09/12 05:54:48  db2admin
# make sure help prints out correctly
#
# Revision 1.18  2012/09/12 05:53:16  db2admin
# get rid of a display of the Oracle directory
#
# Revision 1.17  2012/09/12 05:50:54  db2admin
# Add in code to poll Oracle databases
#
# Revision 1.16  2011/11/21 02:41:14  db2admin
# Correct log file declaration for Windows
#
# Revision 1.15  2011/08/29 05:14:37  db2admin
# Add in initialisation of logDir
#
# Revision 1.14  2011/08/29 03:18:01  db2admin
# add in connection Summary file output using -l option
#
# Revision 1.13  2010/04/28 04:39:23  db2admin
# fully implement SQL1022C error
#
# Revision 1.12  2010/04/28 04:16:26  db2admin
# Add in message SQL1022C - not enough memory to process the command
#
# Revision 1.11  2010/03/02 01:03:21  db2admin
# Add in new SQL1221N error message
#
# Revision 1.10  2009/12/04 03:22:58  db2admin
# Add in -c -i parms to db2cmd
#
# Revision 1.9  2009/12/04 02:45:20  db2admin
# SQL30061N added as a failure
#
# Revision 1.8  2009/10/08 21:27:55  db2admin
# Add in SQL30081N - A communications error has occurred
#
# Revision 1.7  2009/05/11 05:26:38  db2admin
# Modify db2poll to work with an optional configuration file for providing installation directory
#
# Revision 1.6  2009/03/31 02:13:56  db2admin
# Remove debug line showing excepted databases
#
# Revision 1.5  2009/03/31 02:10:31  db2admin
# Improved error detection
# Added in facility to ignore selected databases
#
# Revision 1.4  2009/02/18 05:04:52  db2admin
# Correct problem with Windows version
#
# Revision 1.3  2009/02/18 04:03:12  db2admin
# correct homedir collection for windows
#
# Revision 1.2  2009/02/17 23:53:31  db2admin
# Add in db2profile calls to unix machines
#
# Revision 1.1  2009/02/17 04:23:05  db2admin
# Initial revision
#
# --------------------------------------------------------------------

my $ID = '$Id: db2poll.pl,v 1.47 2018/10/18 22:58:48 db2admin Exp db2admin $';
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

sub isError {
  # Check to see if the error means that there is a database problem

  # print ">>>> $_[0] <<<<\n";

  if (( trim("$_[0]") =~ /SQL1032N/ ) || # No start database manager command was issued
      ( trim("$_[0]") =~ /SQL1013N/ ) || # The database alias name or database name "XXXX" could not be found
      ( trim("$_[0]") =~ /SQL30081N/ ) || # A communication error has occurred
      ( trim("$_[0]") =~ /SQL30061N/ ) || # SQL30061N  The database alias or database name X was not found at the remote node.
      ( trim("$_[0]") =~ /SQL1022C/ ) || # There is not enough memory available to process the command
      ( trim("$_[0]") =~ /SQL1221N/ ) || # The Application Support Layer heap cannot be allocated
      ( trim("$_[0]") =~ /SQL1336N/ ) || # The remote host "XXXXXXXXXX" was not found
      ( trim("$_[0]") =~ /ORA-12170/ ) || # TNS timeout occured
      ( trim("$_[0]") =~ /ORA-12560/ ) || # TNS:protocol adapter error
      ( trim("$_[0]") =~ /ORA-12154/ ) || # TNS:could not resolve the connect identifier specified
      ( trim("$_[0]") =~ /ORA-12514/ ) || # TNS:listener does not currently know of service requested in connect
      ( trim("$_[0]") =~ /SQL1031N/ ) || # The database directory cannot be found on the indicated file system
      ( trim("$_[0]") =~ /HResult 0x35/ ) || # SQLServer - Unable to connect to server
      ( trim("$_[0]") =~ /HResult 0x274D/ ) || # SQLServer - No connection could be made because the target machine actively refused it
      ( trim("$_[0]") =~ /Msg 18456/ ) || # SQLServer - Login failed for user
      ( trim("$_[0]") =~ /Msg 18452/ ) || # SQLServer - The user is not associated with a trusted SQL Server connection
      ( trim("$_[0]") =~ /HResult 0x52E/ ) # SQLServer - Cannot open database
     ) {
     # print "FAIL 0: $_[0]\n";
    return 1;
  }
  else {
    return 0;
  }
}

sub snmpTrap {

  $snmpTarget = $_[0];
  $snmpMSG1Code = $_[1];
  $snmpMSG1 = $_[2];
  $snmpMSG2Code = $_[3];
  $snmpMSG2 = $_[4];

  # Note: the snmp traps have been defined as:
  #
  #    snmpType      Comment
  #       2          UDB Database is up again after having been down
  #       3          UDB database is down - send an email
  #       4          UDB database is down - send an SMS
  #       5          SQLServer Database is up again after having been down
  #       6          SQLServer database is down - send an email
  #       7          SQLServer database is down - send an SMS

  if ( $snmpMSG2 eq "OK" ) {
    $snmpType = "2";
  }
  elsif ( $lastDBStateCount{$key} == 0 ) {
    $snmpType = "3";
  }
  else {
    $snmpType = "4";
  }

  if ( $DBMSType eq "SQLServer" ) { # send traps to SQLServer support
    $snmpType = $snmpType + 3;
  }

  if ( $OS eq "Windows" ) {
    if ( $debugLevel > 0 ) { print "c:\\udbdba\\trapgen28\\trapgen.exe -c dba -d $snmpTarget -o 1.3.6.1.4.1.999999 -g 6 -s $snmpType -v $snmpMSG1Code s \"$snmpMSG1\" -v $snmpMSG2Code s \"$snmpMSG2\"\n"; }
    $ret = `C:\\udbdba\\trapgen28\\trapgen.exe -c dba -d $snmpTarget -o 1.3.6.1.4.1.999999 -g 6 -s $snmpType -v $snmpMSG1Code s "$snmpMSG1" -v $snmpMSG2Code s "$snmpMSG2" `;
    if ( $debugLevel > 0 ) { print "Returned: $ret\n"; }
  }
  else {
    $ret = `/usr/sfw/bin/snmptrap -v1 -c public $snmpTarget 1.3.6.1.4.1.999999 $machine 6 $snmpType '' 1.3.6.1.4.1.999999.0.1 s "$machine $inst $dbalias" 1.3.6.1.4.1.999999.0.2 s "$snmpMSG2"`
  }
}

sub ErrorTest {
  if ( $#_ > -1 ) { # Something has been passed
    ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    $year = 1900 + $yearOffset;
    $month = $month + 1;
    $hour = substr("0" . $hour, length($hour)-1,2);
    $minute = substr("0" . $minute, length($minute)-1,2);
    $second = substr("0" . $second, length($second)-1,2);
    $month = substr("0" . $month, length($month)-1,2);
    $day = substr("0" . $dayOfMonth, length($dayOfMonth)-1,2);
    $Now = "$year.$month.$day $hour:$minute:$second";

    $xmachine = $machine;
    if ( $DBMSType eq "DB2" ) {
      if ( defined($dbNodeXREF{$dbalias}) ) { ## we have a server name for this alias .....
        $xmachine = $dbNodeXREF{$dbalias}; # change the machine name to the target server
      }
    }

    $key="${xmachine}|${inst}|${dbalias}"; # set the key value to be used to simplify usage

    if (($OpenView eq "Yes") || ($snmpServer ne "")) { # if openview or snmp trap server set 
      @line = split(/\n/,$_[0]);
      $sve = ""; 
      for ( $i = $#line; $i > -1 ; $i-- ) { # loop through the lines in reverse order .....
        if ( ($sve eq "") && (trim($line[$i]) ne "") ) { $sve = $line[$i]; } # just in case save the last non blank line
        if ( ($line[$i] =~ /^SQL/) || ($line[$i] =~ /^ORA/) || ($line[$i] =~ /affected\)/ ) || ($line[$i] =~ /HRESULT\)/ ) ) { # found a message (maybe)
          $sve = $line[$i];
          last;
        }
      }
      if ( ($sve =~ /Local database alias/) || ($sve =~ /affected\)/) ) { # if last line is 'Local database alias' then all ok
        $receivedDBErrors{"Connect OK"} = 1;
      }
      else { # log the line
        $receivedDBErrors{$sve} = 1;
      }

      if ( isError("$_[0]")) {
        if ( defined $dbexceptions{$dbalias} ) { # then ignore this failure
          if ( $snmpServer ne "" ) { $DBState{"$key"} = "Except"; }
          if ( $debugLevel > 0 ) { print "Database connection failed - but it is in exception file\n"; }
          if ( $OpenView eq "Yes" ) { 
            $resp = `opcmon $OpenView_Policy=0 -obj "$xmachine:$inst:$dbalias"` ;
          }
          if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Except\n"; }

          $key="${xmachine}|${inst}|${dbalias}";
          # if the last state was failed and now it is Except then notify things if necessary
          if ( defined($lastDBState{$key}) && ($lastDBState{$key} eq "Fail") ) {
            if ( $debugLevel > 0 ) { print "All OK now but last time it was in a failed state\n"; }
            if ( $snmpServer ne "" ) { # send off an all is OK snmp alert
              if ( $debugLevel > 0 ) { print "Sending an SNMP alert\n"; }
              snmpTrap ($snmpServer, '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "OK");
              snmpTrap ('mplmon02prd', '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "OK");
            }
          }
        }
        else { # it's an error that should be logged
          if ( $snmpServer ne "" ) { $DBState{"$key"} = "Fail"; }
          if ( $debugLevel > 0 ) { print "Database connection failed\n"; }
          if ( $OpenView eq "Yes" ) { 
            $resp = `opcmon $OpenView_Policy=1 -obj "$xmachine:$inst:$dbalias"` ;
          }
          if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Fail\n"; }
          if ( $snmpServer ne "" ) { # send an snmp trap to the designated server
            # only send the trap if it is the first or it has been more than 4 hours (320 mins)
            if ( defined($lastDBState{$key}) && ($lastDBState{$key} eq "OK") ) { # first fail message for this key .....
              snmpTrap ($snmpServer, '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "FAIL");
              snmpTrap ('mplmon02prd', '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "FAIL");
            }
            elsif ( $lastDBStateCount{$key} == 2 ) { #  after 3 consequetive failures send an sms
                $DBState{"$key"} = "SNMP"; 
                snmpTrap ($snmpServer, '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "FAIL");
                snmpTrap ('mplmon02prd', '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "FAIL");
            }
            else { # check if it's been more than 320 mins since the last call for this key
              ($curr_second, $curr_minute, $curr_hour, $curr_dayOfMonth, $curr_month, $curr_yearOffset, $curr_dayOfWeek, $curr_dayOfYear, $curr_daylightSavings) = localtime();
              $curr_hour = substr("0" . $curr_hour, length($curr_hour)-1,2);
              $curr_minute = substr("0" . $curr_minute, length($curr_minute)-1,2);
              ($fail_hour,$fail_minute) = split(':',$lastDBStateTime{$key});

              if ( $curr_hour < $fail_hour ) { # probably rolled over midnight
                $curr_hour = $curr_hour + 24;
              } 
              $min_difference = (($curr_hour * 60) + $curr_minute ) - (($fail_hour * 60) + $fail_minute );

              if ( $min_difference > 240 ) { # been a while better send it again ....
                $DBState{"$key"} = "SNMP"; 
                snmpTrap ($snmpServer, '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "FAIL");
                snmpTrap ('mplmon02prd', '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "FAIL");
              }
            }
          }
        }
      }
      else { # no errors found
        if ( $debugLevel > 0 ) { print "Database connection successful\n"; }
        if ( $snmpServer ne "" ) { $DBState{"$key"} = "OK"; }
        if ( $OpenView eq "Yes" ) {
          $resp = `opcmon $OpenView_Policy=0 -obj "$xmachine:$inst:$dbalias"` ;
        }
        if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,OK\n"; }

        $key="${xmachine}|${inst}|${dbalias}";
        # if the last state was failed and now it is ok then notify things if necessary
        if ( defined($lastDBState{$key}) && ($lastDBState{$key} eq "Fail") ) { 
          if ( $debugLevel > 0 ) { print "All OK now but last time it was in a failed state\n"; }
          if ( $snmpServer ne "" ) { # send off an all is OK snmp alert
            if ( $debugLevel > 0 ) { print "Sending an SNMP alert\n"; }
            snmpTrap ($snmpServer, '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "OK");
            snmpTrap ('mplmon02prd', '1.3.6.1.4.1.999999.0.1', "$xmachine $inst $dbalias", '1.3.6.1.4.1.999999.0.2', "OK");
          }
        }
      }
    }
    elsif ($summary eq "Yes") { 
      if ( isError("$_[0]")) { # then there is a problem with the instance ......
        $msgExten = "" ;
        if ( defined $dbexceptions{$dbalias} ) { # then ignore this failure
          if ( $debugLevel > 0 ) { print "Database connection failed\n"; }
          $msgExten = " - but database on the exclude list so all OK" ;
          if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Except\n"; }
          if ( $snmpServer ne "" ) { $DBState{"$key"} = "Except"; }
        }
        else {
          if ( $debugLevel > 0 ) { print "Database connection failed - but it is in exception file\n"; }
          if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Fail\n"; }
          if ( $snmpServer ne "" ) { $DBState{"$key"} = "Fail"; }
        }
        if ( $verbose eq "Yes" ) {
          print "$Now : Unable to connect to $dbalias ($xmachine/$inst)$msgExten\n$_[0]";
        }
        else {
          print "$Now : Unable to connect to $dbalias ($xmachine/$inst)$msgExten\n";
        }
      }
      else {
        if ( $debugLevel > 0 ) { print "Database connection successful\n"; }
        print "$Now : Connected OK to $dbalias ($xmachine/$inst)\n";
        if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,OK\n"; }
        if ( $snmpServer ne "" ) { $DBState{"$key"} = "OK"; }
      }
    }
    else { # print out the summary and the detail .....
      if ( defined $dbexceptions{$dbalias} ) { # then ignore this failure
        if ( $debugLevel > 0 ) { print "Database is in exception file so no checking done\n"; }
        $msgExten = " - but database on the exclude list so all OK" ;
      }

      if ( isError("$_[0]")) { # then there is a problem with the instance ......
        if ( defined $dbexceptions{$dbalias} ) { # then ignore this failure
          if ( $debugLevel > 0 ) { print "Database connection failed - but it is in exception file\n"; }
          if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Except\n"; }
          if ( $snmpServer ne "" ) { $DBState{"$key"} = "Except"; }
        }
        else {
          if ( $debugLevel > 0 ) { print "Database connection failed\n"; }
          if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Fail\n"; }
          if ( $snmpServer ne "" ) { $DBState{"$key"} = "Fail"; }
        }
        if ( $verbose eq "Yes" ) {
          print "$Now : Unable to connect to $dbalias ($xmachine/$inst)$msgExten\n$_[0]\n";
        }
        else {
          print "$Now : Unable to connect to $dbalias ($xmachine/$inst)$msgExten\n\n";
        }
      }
      elsif ( ( trim("$_[0]") =~ /SQL[0-9][0-9]/ ) && ( $DBMSType ne "SQLServer" ) ) { # there may be a message but it is from the instance so the instance is up
        if ( $debugLevel > 0 ) { print "Instace connection successful - but there looks like there was an error\n"; }
        print "$Now : Didn't Connect to $dbalias ($xmachine/$inst) but Instance alive$msgExten \n";
        print "$_[0]\n";
        if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Except\n"; }
        if ( $snmpServer ne "" ) { $DBState{"$key"} = "Except"; }
      }
      elsif ( ( trim("$_[0]") =~ /ORA-[0-9][0-9]/ ) ) { # there may be a message but it is from the instance so the instance is up 
        if ( $debugLevel > 0 ) { print "Instace connection successful - but there looks like there was an error\n"; }
        print "$Now : Didn't Connect to $dbalias ($xmachine/$inst) but Instance alive$msgExten \n";
        print "$_[0]\n";
        if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,Except\n"; }
        if ( $snmpServer ne "" ) { $DBState{"$key"} = "Except"; }
      }
      else {
        if ( $debugLevel > 0 ) { print "Database connection successful\n"; }
        print "$Now : Connected OK to $dbalias ($xmachine/$inst)\n";
        print "$_[0]\n";
        if ( $logConnections eq "Yes" ) { print LOGF "$Now,$xmachine,$inst,$dbalias,OK\n"; }
        if ( $snmpServer ne "" ) { $DBState{"$key"} = "OK"; }
      }
    } 
  }
}
    
sub usage {
  if ( $#_ > -1 ) {
    if ( trim("$_[0]") ne "" ) {
      print STDERR "\n$_[0]\n\n";
    }
  }

  print STDERR "Usage: $0 -?hs [-A or -I or -i <instance>] [-O openview policy name] [-S] [-v] [-L] [-l] [-R] [-X] [-D Install Directory] 
                               [-C configuration file] [-t oracle TNSNAMES.ORA directory to use] [DEBUG]
                               [-W <snmp server>] [-V[V]]

      Script to loop through a selection of databases determined through parameters and connect to each

      Version $Version Last Changed on $Changed (UTC)

       -h or -?        : This help message
       -s              : Silent mode 
       -L              : Use login supplied in DB_Connections.txt file or use DEFAULT_LOGIN by default if none supplied
       -l              : Output a log of connection details
       -X              : Do NOT Connect to local databases
       -D              : Directory that db2 was installed into 
       -O              : OpenView output - generate opcmon commands (policy as parameter)
       -S              : Just print a summary of the connection attempt
       -R              : Connect to remote databases (default is to connect to local databases only)
       -A              : Process all instances for the server (default)
       -v              : Produce failure message in Summary 
       -V              : debug level
       -I              : Only use the current Instance
       -C              : File containing configuration details 
       -t              : Directory containing the TNSNAMES.ORA file to use for a list of 
                         Oracle databases to check (defaults to C:\\app\\oracle\\product\\11.1.0\\client_1\\network\\admin)
       -i <instance>   : Use the indicated instance
       -W              : Indicates that a SNMP trap should be raised and sent to the specified server

     \n";
}

# Set default values for variables

$silent = "No";
$command = "";
$inFile = "";
$connect_to_remote = "No";
$connect_to_local = "XXX";
$instance = "XXX";
if ( $OS ne "Windows" ) {
  $db2ilist_dir=`which db2ilist`;
}
else {
  $db2ilist_dir='db2ilist';
}
$summary = "No";
$verbose = "No";
$OpenView = "No";
$OpenView_Policy = "MPL-DB2-Connect";
$configFile = "";
$installDir_set = "No";
$debug = "No";
$logConnections = "No";
if ( $OS eq "Windows" ) {
  $tnsnamesDirectory = 'C:\app\oracle\product\11.1.0\client_1\network\admin';
}
else {
  $tnsnamesDirectory = 'oracle/network/admin';
}
$snmpServer = "";
$debugLevel = 0;
$useLogin = "No";

# ----------------------------------------------------
# -- Start of Parameter Section
# ----------------------------------------------------

# Initialise vars for getOpt ....

$getOpt_prm = 0;
$getOpt_opt = ":?hsSvVO:ALlRXIi:D:C:t:W:|^DEBUG";

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
 elsif (($getOpt_optName eq "DEBUG") )  {
   if ( $silent ne "Yes") {
     print "Debug mode selected\n";
   }
   $debug = "Yes";
 }
 elsif (($getOpt_optName eq "V"))  {
   $debugLevel++;
   if ( $silent ne "Yes") {
     print "debug level set to $debugLevel\n";
   }
 }
 elsif (($getOpt_optName eq "S"))  {
   if ( $silent ne "Yes") {
     print "Summary only report will be provided\n";
   }
   $summary = "Yes";
 }
 elsif (($getOpt_optName eq "O"))  {
   if ( $silent ne "Yes") {
     print "Output will be in OpenView format - One line per Instance\n";
   }
   $OpenView = "Yes";
   $OpenView_Policy = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "t"))  {
   if ( $silent ne "Yes") {
     print "Directory $getOpt_optValue will be searhed for TNSNAMES.ORA\n";
   }
   $tnsnamesDirectory = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "v"))  {
   if ( $silent ne "Yes") {
     print "Failure messages will be printed\n";
   }
   $verbose = "Yes";
 }
 elsif (($getOpt_optName eq "W"))  {
   if ( $silent ne "Yes") {
     print "SNMP Server $getOpt_optValue will be used to process raised SNMP messages\n";
   }
   @DBState = (); # clear DB Status array (key will be machine/instance/database)
   $snmpServer = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "i"))  {
   if ( $silent ne "Yes") {
     print "Only Instance $getOpt_optValue will be processed\n";
   }
   $instance = $getOpt_optValue;
 }
 elsif (($getOpt_optName eq "D"))  {
   $installDir_set = "Yes";
   if ( $silent ne "Yes") {
     print "db2ilist will be executed from $getOpt_optValue\n";
   }
   if ( $OS eq "Windows" ) {
     $db2ilist_dir = "$getOpt_optValue\\db2ilist";
   }
   else {
     $db2ilist_dir = "$getOpt_optValue/db2ilist";
   }
 }
 elsif (($getOpt_optName eq "C"))  {
   if ( $silent ne "Yes") {
     print "Configuration file $getOpt_optValue will be used\n";
   }
   $configFile = "$getOpt_optValue";
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
 elsif (($getOpt_optName eq "X"))  {
   if ( $silent ne "Yes") {
     print STDERR "Local databases will NOT be connected to\n";
   }
   $connect_to_local = "No";
 }
 elsif (($getOpt_optName eq "l"))  {
   if ( $silent ne "Yes") {
     print STDERR "Connections will be logged\n";
   }
   $logConnections = "Yes";
 }
 elsif (($getOpt_optName eq "L"))  {
   if ( $silent ne "Yes") {
     print STDERR "Connections will be made using DEFAULT_LOGIN\n";
   }
   $useLogin = "Yes";
 }
 elsif (($getOpt_optName eq "R"))  {
   if ( $silent ne "Yes") {
     print STDERR "Remote databases will be connected to\n";
   }
   $connect_to_remote = "Yes";
 }
 elsif ( $getOpt_optName eq ":" ) {
   usage ("Parameter $getOpt_optValue requires a parameter");
   exit;
 }
 else { # handle other entered values ....
   usage ("Parameter $getOpt_optValue is invalid");
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

$DBMSType = "DB2";

if ( $instance eq "XXX" ) {
  if ( $silent ne "Yes") {
    print "All Instances will be processed\n";
  }
  $instance = "";
}

if ( $logConnections eq "Yes" ) {
  $logFile = "${machine}-connectionSummary-$YYYYMMDD.log";
}

if ( $connect_to_local eq "XXX" ) {
  if ( $silent ne "Yes") {
    print "Local databases will be connected to\n";
  }
  $connect_to_local = "Yes";
}

# if snmpServer set then keep track of last status

@lastDBState= (); # Clear the array
@lastDBStateTime= (); # Clear the array
@lastDBStateCount= (); # Clear the array
@receivedDBErrors = (); # Clear the array

if ( $snmpServer ne "" ) { # load up the last statuses
  if ( open (STATEFILE,"<DBConnections_State.txt") ) {
    while (<STATEFILE>) {
      chomp $_;
      @inLine = split /,/; # key and state are separated by a comma
      $lastDBState{$inLine[0]} = $inLine[1];
      $lastDBStateTime{$inLine[0]} = $inLine[2]; # time when the fail first happened
      $lastDBStateCount{$inLine[0]} = $inLine[3]; # number of polls since the fail occurred
      if ( $debugLevel > 0 ) { print "Database: $inLine[0] set with last state of $inLine[1]\n"; }
    }
    close STATEFILE;
  }
  if ( open (ERRORFILE,"<receivedDBErrors.txt") ) {
    while (<ERRORFILE>) {
      chomp $_;
      $receivedDBErrors{$_} = 1;
      if ( $debugLevel > 0 ) { print "Error $_ has been loaded\n"; }
    }
    close ERRORFILE;
  }
}

# if configuration file set then load up some details ....

if ( $configFile ne "" ) {
  if ( $installDir_set eq "No" ) {     # if the install directory has been set then skip the config entry
    if ( open (CONFFILE,"<$configFile") ) {
      while ( <CONFFILE> ) {
        if ( $debug eq "Yes" ) { print ">> $_\n"; }
        @conffile_line = split(/#/);
        chomp $conffile_line[1];
        if ( $machine eq $conffile_line[0] ) { # found the configuration line for this machine
          if ( $silent ne "Yes" ) {
            print "Directory $conffile_line[1] will be used to run db2ilist from\n";
          }
          if ( $OS eq "Windows" ) {
            $db2ilist_dir = "$conffile_line[1]\\db2ilist";
            $db2_dir = "$conffile_line[1]\\";
          }
          else {
            $db2ilist_dir = "$conffile_line[1]/db2ilist";
          }
        }
      }
    }
    else {
      die "Configuration file $configFile does not exist or is not accessible\n";
    }
  }
  else {
    print "Install Directory has been set so configuration file will NOT be used\n";
  }
}

# if necessary establish handle to log file

if ( $logConnections eq "Yes" ) {
  if (! open (LOGF,">>$logDir$logFile"))  {
    print "Cant open $logDir$logFile so turning off connection logging\n";
    $logConnections = "No";
  }
}

# load up the database/server xref file if it exists

@dbNodeXREF = (); # initialise array
if ( open (DBXREFPIPE, "<dbNodeXREF.txt" ) ) {
  while (<DBXREFPIPE>) {
    chomp $_;
    ($xdb,$xserver) = split(/,/);
    $dbNodeXREF{$xdb} = $xserver;
  }
  if ( $debugLevel > 0 ) { foreach $k (keys %dbNodeXREF ) { print "DB $k exists on $dbNodeXREF{$k}\n"; } }
}


# Check all of the DB2 Connections

# Load the login details for DB2 dataases .....

if ( ! open (DBPIPE, "<DB_Connections.txt" ) ) {
  print "No DB_Connections.txt file so assuming all DB2 connections will use defaults\n";
}
else { # the file exists so just loop through looking for databases to try and connect to
  while (<DBPIPE>) {
    chomp $_;
    @line = split(/,/);    # split parms delimited by ','. Should be machine,database,login,password

    $type = $line[0];
    $svr = $line[1];
    $DB = $line[2];
    $lgn = $line[3];
    $pwd = $line[4];

    $server = $svr;
    $inst = "DB2";
    $dbalias = $DB;

    if ( $type eq "DB2" ) {
      $DBKey = "$svr$DB";
      $DB2_login{$DBKey} = $lgn;
      $DB2_password{$DBKey} = $pwd;
      if ( $debugLevel > 0 ) { print "Login $lgn Password $pwd has been logged in \"$svr$DB\"\n"; }
    }
  }
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

    if ( $debugLevel > 0 ) { print ">$_\n"; }

    if ( $debug eq "Yes" ) { print ">$_\n"; }

    $inst = $_;
    chomp $inst;

    if ( $OS ne "Windows" ) {
      $homeDir=`grep $inst /etc/passwd | cut -d":" -f6`;
      chomp $homeDir;
      $excFile="$homeDir/DBPollexceptions.lst";
    }
    else {
      $homeDir="c:";
      $excFile="$homeDir\\DBPollexceptions.lst";
    }

    # Populate the exceptions table
    %dbexceptions = (); # initialise array
    if ( open (EXCPPIPE,"<$excFile"))  { 
      while ( <EXCPPIPE> ) {
        $db_exc = $_;
        chomp $db_exc;
        $dbexceptions{"$db_exc"} = "ignore"; 
        if ( $debugLevel > 1 ) { print "$db_exc has been excluded\n"; }
      }
      close EXCPPIPE;
    }

    if ( $instance ne "" && $instance ne $inst) { 
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
      $x = `$db2_dir\db2cmd -c -i -w tmpcmd1_db2poll.bat`;
      if (! open (DBPIPE,"<tmpcmd1_db2poll.out"))  { die "Can't open tmpcmd1_db2poll.out !\n $!\n"; }
    }
    else {
      if (! open (DBPIPE,". $homeDir/sqllib/db2profile; db2 list db directory | "))  { die "Can't run db2 list ! $!\n"; }
    }

    $DEFAULT_LOGIN_PWD = 'DEFAULT_PASSWORD';
    while (<DBPIPE>) {

      if ( $debugLevel > 1 ) { print "### $_\n"; }

      if ( $debug eq "Yes" ) { print "### $_\n"; }
    
      $linein = $_;
      chomp $linein;
      @cmdout_info = split(/=/,$linein);
      $ENV{'DB2INSTANCE'} = $inst;

      if ($linein =~ /Database alias/) {
        $dbalias = trim($cmdout_info[1]);
      }
      elsif ($linein =~ /Database name/) {
        $dbname = trim($cmdout_info[1]);
      }
      elsif ($linein =~ /Directory entry type/) {
        $dbKey = "$machine$dbalias";
        if ( $debugLevel > 0 ) { print "DBKey being looked for is '$dbKey'\n"; }
        if ($linein =~ /Indirect/) { # local database
          if ( $connect_to_local eq "Yes" ) {
            if ( $debugLevel > 0 ) { print "UDB $dbalias will be checked\n"; }
            if ( $OS eq "Windows" ) {
              if ( ! open (CMDFILE, ">tmpcmd2_db2poll.bat" ) ) {die "Unable to allocate tmpcmd2_db2poll.bat\n $!\n"; }
              print CMDFILE "set DB2INSTANCE=$inst\n";
              if ( $useLogin eq "Yes" ) {
                if ( defined($DB2_login{$dbKey}) ) { # found entry
                  if ( $debugLevel > 0 ) { print "Logging on to server using $DB2_login{$dbKey}\n"; }
                  print CMDFILE "db2 connect to $dbalias user $DB2_login{$dbKey} using '$DB2_password{$dbKey}' >tmpcmd2_db2poll.out\n";
                }
                else { # just use a default value .....
                  if ( $debugLevel > 0 ) { print "Logging on to server using default account\n"; }
                  if ( ' CRM81PRD ' =~ /$dbalias/ ) {
                    $DEFAULT_LOGIN_PWD = ''; # for unix boxes dont supply the password
                  }
                  print CMDFILE "db2 connect to $dbalias user KAGJCM\\DEFAULT_LOGIN using '$DEFAULT_LOGIN_PWD' >tmpcmd2_db2poll.out\n";
                }
              }
              else {
                print CMDFILE "db2 connect to $dbalias >tmpcmd2_db2poll.out\n";
              }
              print CMDFILE "exit\n";
              close CMDFILE;
              $y = `$db2_dir\db2cmd -c -i -w tmpcmd2_db2poll.bat`;
              $x = "";
              if (! open (CONNPIPE,"<tmpcmd2_db2poll.out"))  { die "Can't open tmpcmd2_db2poll.out !\n $!\n"; }
              while ( <CONNPIPE> ) {
                $x = "$x$_";
              } 
              # print ">>>>$x\n";
              ErrorTest( "Connecting to $inst \: $dbalias\n\n$x" );
            }
            else { # Unix box we're running on
              if ( $useLogin eq "Yes" ) {
                if ( defined($DB2_login{$dbKey}) ) { # found entry
                  if ( $debugLevel > 0 ) { print "Logging on to server using $DB2_login{$dbKey}\n"; }
                  $x = `echo Connecting to \$DB2INSTANCE \: $dbalias;. $homeDir/sqllib/db2profile; db2 connect to $dbalias user $DB2_login{$dbKey} using '$DB2_password{$dbKey}'`;
                }
                else {
                  if ( $debugLevel > 0 ) { print "Logging on to server using default account\n"; }
                  if ( ' CRM81PRD ' =~ /$dbalias/ ) {
                    $DEFAULT_LOGIN_PWD = ''; # for unix boxes dont supply the password
                  }
                  $x = `echo Connecting to \$DB2INSTANCE \: $dbalias;. $homeDir/sqllib/db2profile; db2 connect to $dbalias user KAGJCM\\DEFAULT_LOGIN using '$DEFAULT_LOGIN_PWD'`;
                }
              }
              else {
                $x = `echo Connecting to \$DB2INSTANCE \: $dbalias;. $homeDir/sqllib/db2profile; db2 connect to $dbalias`;
              }
              ErrorTest("$x");
            }
          }
        }
        else { # remote database
          if ( $connect_to_remote eq "Yes" ) {
            if ( $debugLevel > 0 ) { print "UDB $dbalias will be checked\n"; }
            if ( $OS eq "Windows" ) {
              if ( $useLogin eq "Yes" ) {
                if ( defined($DB2_login{$dbKey}) ) { # found entry
                  if ( $debugLevel > 0 ) { print "Logging on to server using $DB2_login{$dbKey}\n"; } 
                  $x = `db2 connect to $dbalias user $DB2_login{$dbKey} using '$DB2_password{$dbKey}'`
                }
                else {
                  if ( $debugLevel > 0 ) { print "Logging on to server using default account\n"; }
                  if ( ' CRM81PRD ' =~ /$dbalias/ ) {
                    $DEFAULT_LOGIN_PWD = ''; # for unix boxes dont supply the password
                  }
                  $x = `db2 connect to $dbalias user KAGJCM\\DEFAULT_LOGIN using '$DEFAULT_LOGIN_PWD'`
                }
              }
              else {
                $x = `db2 connect to $dbalias`;
              }
              ErrorTest( "Connecting to $inst \: $dbalias\n\n$x" ) ;
            }
            else {
              if ( $useLogin eq "Yes" ) {
                if ( defined($DB2_login{$dbKey}) ) { # found entry
                  if ( $debugLevel > 0 ) { print "Logging on to server using $DB2_login{$dbKey}\n"; }
                  $x = `echo Connecting to \$DB2INSTANCE \: $dbalias;. $homeDir/sqllib/db2profile; db2 connect to $dbalias user $DB2_login{$dbKey} using '$DB2_password{$dbKey}'`;
                }
                else {
                  if ( $debugLevel > 0 ) { print "Logging on to server using default account\n"; }
                  if ( ' CRM81PRD ' =~ /$dbalias/ ) {
                    $DEFAULT_LOGIN_PWD = ''; # for unix boxes dont supply the password
                  }
                  $x = `echo Connecting to \$DB2INSTANCE \: $dbalias;. $homeDir/sqllib/db2profile; db2 connect to $dbalias user KAGJCM\\DEFAULT_LOGIN using '$DEFAULT_LOGIN_PWD'`;
                } 
              }
              else {
                $x = `echo Connecting to \$DB2INSTANCE \: $dbalias;. $homeDir/sqllib/db2profile; db2 connect to $dbalias`;
              }
              ErrorTest( "$x" );
            }
          }
        }
      }
    }
    $lastInst = $inst;
}

# Check all of the Oracle connections

$DBMSType = "Oracle";
$inst = 'ORACLE';
$dbalias = "";

if ( ! open (DBPIPE, "<$tnsnamesDirectory${sep}TNSNAMES.ORA" ) ) {
  print "No tnsnames.ora file so assuming no Oracle checking to do\n"; 
}
else { # the file exists so just loop through looking for databases to try and connect to   
  while (<DBPIPE>) {
    @line = split;
    if ( substr($_,0,1) ne " " && $line[1] eq "=" ) { # Found a database to try connecting to 
      $dbalias = $line[0];
      if ( $debugLevel > 0 ) { print "Oracle $dbalias will be checked\n"; }
    }
    elsif ( $_ =~ /HOST =/ ) { # we can identify the machine it is from 
      # loop through the line and try and find the HOST name
      @bits = split(/\)\(/, $_);
      foreach $bt (@bits) {
        if (substr(trim($bt),0,4) eq "HOST" ) {
          # host entry
          @host = split("=", $bt);
          $machine = trim($host[1]);
        }
      } 
      # print "sqlplus -L monitor\@$dbalias\/m0nitor  \@c:\\udbdba\\sql\\ORA_exit.sql\n";
      $x = `sqlplus -s -L monitor\@$dbalias\/m0nitor  \@c:\\udbdba\\sql\\ORA_exit.sql`;
      if ( $debugLevel > 0 ) {print "$dbalias connection test RESULT: $x\n"; }
      ErrorTest( "$x" );
      $dbalias = "";
    }
  }
  if ( $dbalias ne "") { # Means that no HOST record was found 
    $machine = "UNKNOWN";
    $x = `sqlplus -s -L monitor\@$dbalias\/m0nitor  \@c:\\udbdba\\sql\\ORA_exit.sql`;
    if ( $debugLevel > 0 ) { print "RESULT: $x\n"; }
    ErrorTest( "$x" );
    $dbalias = "";
  }
}

close DBPIPE;

# Check all of the SQLServer connections

$DBMSType = "SQLServer";

if ( ! open (DBPIPE, "<DB_Connections.txt" ) ) {
  print "No DB_Connections.txt file so assuming no SQLServer checking to do\n";
}
else { # the file exists so just loop through looking for databases to try and connect to
  while (<DBPIPE>) {
    chomp $_;
    @line = split(/,/);    # split parms delimited by ','. Should be machine,database,login,password

    $type = $line[0];
    $svr = $line[1];
    $DB = $line[2];
    $lgn = $line[3];
    $pwd = $line[4];
    $port = $line[5];

    if ( $svr =~ /\\/ ) { # it is via database name and not port ....
      $port = "";
    }
    else { # fill in the port info 
      if ( $port eq "" ) { $port = ",1433"; }
      else { $port = ",$port"; }
    }

    $machine = $svr;
    $inst = "SQLServer";
    $dbalias = $DB;
      
    if ( uc($type) eq "SQLSERVER" ) {
      $DB_PRM = "";
      if ( $DB ne "" ) { $DB_PRM = "-d $DB"; }
      $lgn_PRM = "";
      if ( $lgn ne "" ) { $lgn_PRM = "-U $lgn -P $pwd"; }

      if ( $debugLevel > 0 ) { print "\"C:\\Program Files\\Microsoft SQL Server\\100\\Tools\\Binn\\sqlcmd\" -S $svr$port $DB_PRM $lgn_PRM -Q \"SELECT SERVERPROPERTY\(\'ServerName\'\)\" 2>\$null\n"; }

      if ( $OS eq "Windows" ) {
        $x = `\"C:\\Program Files\\Microsoft SQL Server\\100\\Tools\\Binn\\sqlcmd\" -S $svr$port $DB_PRM $lgn_PRM -Q "SELECT SERVERPROPERTY\(\'ServerName\'\)" 2>\$null`;
        $x1 = "";
        @stf = split ("\n","$x$null");
        foreach $bit (@stf) { $bit = trim($bit); if ( trim($bit) !~ /^-+$/ ) { $x1 .= "$bit\n"; } }
      }
      else {
        $x1 = `"I Dont know" -S $svr $DB_PRM $lgn_PRM -Q "SELECT SERVERPROPERTY\(\'ServerName\'\)"`;
      }
      if ( $debugLevel > 0 ) { print "$svr\/$DB connection test RESULT: $x\n"; }
      ErrorTest( "$x1" );
      $dbalias = "";
    }
  }
}

close DBPIPE;

# Save the state information if a snmpServer was specified

if ( $snmpServer ne "" ) {
  if ( open (STATEFILE,">DBConnections_State.txt") ) {  
    ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    $hour = substr("0" . $hour, length($hour)-1,2);
    $minute = substr("0" . $minute, length($minute)-1,2);

    foreach $key (sort by_key keys %DBState ) {
       $lastDBStateCount{$key}++; # increment the count
       if ( $DBState{$key} eq "Fail" ) { # Keep the old time
         print STATEFILE "$key,$DBState{$key},$lastDBStateTime{$key},$lastDBStateCount{$key}\n";
       }
       elsif ( $DBState{$key} eq "SNMP" ) { # it was a fail and an snmp has been sent
         # so reset the time for this poll and change the state to FAIL
         print STATEFILE "$key,Fail,$hour:$minute,$lastDBStateCount{$key}\n";
       }
       else { # Use the current time to flag the status and set the count to 0
         print STATEFILE "$key,$DBState{$key},$hour:$minute,0\n";
       }
    }

    close STATEFILE;
  } 
  if ( open (ERRORFILE,">receivedDBErrors.txt") ) {  
    foreach $key (sort by_key keys %receivedDBErrors ) {
       print ERRORFILE "$key\n";
    }
    close ERRORFILE;
  } 
}

# Print out the OpenView messages if requested ....

if ( $openView eq "Yes") {
  foreach $key (sort by_key keys %instDBS ) {
    print "$Now : Unable to connect to $instDBS{$key} on instance $key ($machine)\n";
  }
}

# Subroutines and functions ......

sub by_key {
  $a cmp $b ;
}



