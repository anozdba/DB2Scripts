# --------------------------------------------------------------------
# offlineNetbackupBackup.ps1
#
# $Id: offlineNetbackupBackup.ps1,v 1.1 2017/08/01 06:07:14 db2admin Exp db2admin $
#
# Description:
# Script to do an offline backup of an indicated database
#
# Usage:
#   offlineNetbackupBackup.ps1 -instance=esbin1p -database=test2 -options="session=4"
#
# $Name:  $
#
# ChangeLog:
# $Log: offlineNetbackupBackup.ps1,v $
# Revision 1.1  2017/08/01 06:07:14  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

# parameters

param(
  [string]$uniqueFile = "offlineNetbackupBackup" ,
  [string]$instance = "db2" ,
  [string]$load = "C:\Progra~1\VERITAS\NetBackup\bin\nbdb2.dll" ,
  [string]$database = "" ,
  [string]$options = "" ,
  [switch]$help = $false 
)

if ( $database -eq "" ) {
  write-output "-database parameter must be supplied"
  return
}

# logging 

$hostname = $env:computername

If (Test-Path logs\offlineNetbackupBackup_${hostname}_${instance}_$database.log){
	Remove-Item logs\offlineNetbackupBackup_${hostname}_${instance}_$database.log
}

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path logs\offlineNetbackupBackup_${hostname}_${instance}_$database.log -append

# put in fix for early version of powershell

If ($PSVersionTable.PSVersion.Major -le 2) {
  # put in fix for STDOUT redirection
  $bindingFlags = [Reflection.BindingFlags] “Instance,NonPublic,GetField”
  $objectRef = $host.GetType().GetField(“externalHostRef”, $bindingFlags).GetValue($host)

  $bindingFlags = [Reflection.BindingFlags] “Instance,NonPublic,GetProperty”
  $consoleHost = $objectRef.GetType().GetProperty(“Value”, $bindingFlags).GetValue($objectRef, @())

  [void] $consoleHost.GetType().GetProperty(“IsStandardOutputRedirected”, $bindingFlags).GetValue($consoleHost, @())
  $bindingFlags = [Reflection.BindingFlags] “Instance,NonPublic,GetField”
  $field = $consoleHost.GetType().GetField(“standardOutputWriter”, $bindingFlags)
  $field.SetValue($consoleHost, [Console]::Out)
  $field2 = $consoleHost.GetType().GetField(“standardErrorWriter”, $bindingFlags)
  $field2.SetValue($consoleHost, [Console]::Out)
  write-output "STDOUT work around implemented for Powershell V2"
}

# Generate variables for the report

$ts = Get-Date -format yyyy-MM-dd-hh:mm
$scriptName = $myInvocation.MyCommand.Name
$env:DB2INSTANCE=$instance

# establish the db2 environment

set-item -path env:DB2CLP -value "**$$**"

# validate input

if ( $help ) {
  write-output "This script will backup the selected database to Netbackup"
  write-output ""
  write-output "Parameters that have been set are:"
  write-output ""
  write-output "  Instance        : $instance"
  write-output "  Database        : $database"
  write-output "  Options         : $options"
  write-output "  Netbackup Module: $load"
  write-output ""
  write-output "Command invocation format is:"
  write-output ""
  write-output "  gatherDBSummary.ps1 [-instance <age limit>] -database <database> [-options <options>] [-load <netbackup load module>] [-help]"
  write-output ""
  write-output "      instance           - Instance to use (Default: db2)"
  write-output "      database           - comma delimited list of databases to retrieve data from"
  write-output "      options            - database backup options to be passed netbackup"
  write-output "      load               - Netbackup load module (default: C:\Progra~1\VERITAS\NetBackup\bin\nbdb2.dll)"
  write-output "      help               - This message"
  write-output ""
  return
}

write-output "$ts Starting $scriptName"

$send_email = $false
$unquiesce_db = $false

write-output "Backing up $database to Netbackup using the following options: $options"

# start the process

write-output ">>>>>> Processing database $database"

$ts = Get-Date -format yyyy-MM-dd-hh:mm

write-output "$ts Connect being issued"
$proc = Start-Process db2 "connect to $database" -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

if ( $proc.ExitCode -ne 0 ) { 
  write-output "Connect to database returned $($proc.ExitCode)"
  $send_email = $true
}
else {
  $ts = Get-Date -format yyyy-MM-dd-hh:mm
  write-output "$ts Connect successful"
  write-output "$ts Database Quiesce being issued"
  $proc = Start-Process db2 "quiesce db immediate force connections " -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
  get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

  $ts = Get-Date -format yyyy-MM-dd-hh:mm
  if ( $proc.ExitCode -ne 0 ) { # non-zero return from backup
    write-output "$ts Database Quiesce was not successful. Return code was $($proc.ExitCode)"
    $send_email = $true
  }
  else { # quiesce was successful .... continue with backup (flag that unquiesce needs to be done
    $unquiesce_db = $true

    write-output "$ts Database Quiesce was successful"
    write-output "$ts Connection Terminate being issued"
    $proc = Start-Process db2 "terminate " -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
    get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

    if ( $proc.ExitCode -ne 0 ) { # non-zero return from backup
      write-output "Connection Terminate was not successful. Return code was $($proc.ExitCode)"
      $send_email = $true
    }
    else { # all ready to go for the backup .... continue with backup (flag that unquiesce needs to be done
      $ts = Get-Date -format yyyy-MM-dd-hh:mm
      write-output "$ts Database Quiesce successful"
      write-output "$ts Offline Database Backup being started"
      $proc = Start-Process db2 "backup database $database load $load $options " -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
      get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

      $ts = Get-Date -format yyyy-MM-dd-hh:mm
      if ( $proc.ExitCode -ne 0 ) { # non-zero return from backup
        write-output "$ts Offline Database Backup was not successful. Return code was $($proc.ExitCode)"
        $send_email = $true
      }
      else { # backup was successful

        # write out a record of the successful backup and send it off to the consolidation server
        write-output "$ts $hostname $instance $database" | Out-File "logs\${hostname}_${instance}_$database.log" 
        get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp  | Out-File "logs\${hostname}_${instance}_$database.log" -append
        start-process pscp.exe "-i Putty\Keys\WindowsSCPPrivateKey.ppk logs\${hostname}_${instance}_$database.log db2admin@192.168.1.1:LatestBackups " -wait -nonewwindow -RedirectStandardOutput c:\temp\$uniqueFile_$hostname.PSCP
        get-content c:\temp\$uniqueFile_$hostname.PSCP | write-output

        write-output "$ts Offline Database Backup was successful"
      }
    }
  }
}

if ( $unquiesce_db ) { # database was quiesced successfully so unquiesce db
  write-output "$ts Connect being issued"
  $proc = Start-Process db2 "connect to $database" -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
  get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

  if ( $proc.ExitCode -ne 0 ) { 
    write-output "Connect to database returned $($proc.ExitCode)`n"
    write-output "Database is STILL quiesced`n" 
    $send_email = $true
  }
  else { # connected to database ok
    $ts = Get-Date -format yyyy-MM-dd-hh:mm
    write-output "$ts Connect successful"
    write-output "$ts Database Unquiesce being issued"
    $proc = Start-Process db2 "unquiesce db " -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
    get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

    $ts = Get-Date -format yyyy-MM-dd-hh:mm
    if ( $proc.ExitCode -ne 0 ) { # non-zero return from backup
      write-output "$ts Unquiesce was not successful. Return code was $($proc.ExitCode)"
      $send_email = $true
    }
    else {
      write-output "$ts Unquiesce was successful"
    }

  }

}

$ts = Get-Date -format yyyy-MM-dd-hh:mm

write-output "$ts Finished $scriptName"

Stop-Transcript

if ( $send_email ) { # something bad happened
  # construct the body of the message
  write-output "results from the offline backup of $hostname / $instance / $database`n" | Out-File c:\temp\$uniqueFile_$hostname.mailBody
  write-output "The last successful backup details are:`n" | Out-File c:\temp\$uniqueFile_$hostname.mailBody -append
  get-content logs\${hostname}_${instance}_$database.log | Out-File c:\temp\$uniqueFile_$hostname.mailBody -append

  $body = get-content "c:\temp\$uniqueFile_$hostname.mailBody" | Out-String

  Send-MailMessage -To "webmaster@KAGJCM.com.au" -From "do_not_reply@KAGJCM.com.au" -Subject "$hostname - Offline Backup of $database failed" -SmtpServer smtp.KAGJCM.local -Body $body -Attachments "logs\offlineNetbackupBackup_${hostname}_${instance}_$database.log" 
}