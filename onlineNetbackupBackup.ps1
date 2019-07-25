# --------------------------------------------------------------------
# onlineNetbackupBackup.ps1
#
# $Id: onlineNetbackupBackup.ps1,v 1.6 2018/10/21 20:38:42 db2admin Exp db2admin $
#
# Description:
# Script to do an online backup of an indicated database
#
# Usage:
#   onlineNetbackupBackup.ps1 -instance=esbin1p -database=test2 -options="session=4"
#
# $Name:  $
#
# ChangeLog:
# $Log: onlineNetbackupBackup.ps1,v $
# Revision 1.6  2018/10/21 20:38:42  db2admin
# correct bug with the way the timesatmps were generated
#
# Revision 1.5  2018/09/06 05:59:32  db2admin
# change the status delimiter
#
# Revision 1.4  2018/08/21 05:27:22  db2admin
# add in script name to the status record
#
# Revision 1.3  2018/08/20 00:03:58  db2admin
# add in code to send back status information to 192.168.1.1 during the execution of the backup
#
# Revision 1.2  2017/12/29 00:26:44  db2admin
# add in options to:
# 1. include logs explicitly
# 2. exclude logs
# 3. input a target email address for failure messages
#
# Revision 1.1  2017/08/01 00:13:59  db2admin
# Initial revision
#
# --------------------------------------------------------------------

# parameters

param(
  [string]$uniqueFile = "onlineNetbackupBackup" ,
  [string]$instance = "db2" ,
  [string]$load = "C:\Progra~1\VERITAS\NetBackup\bin\nbdb2.dll" ,
  [string]$email = 'DEFAULT_EMAIL@KAGJCM.com.au' , 
  [string]$database = "" ,
  [string]$options = "" ,
  [switch]$IncludeLogs = $false ,
  [switch]$ExcludeLogs = $false ,
  [switch]$help = $false 
)

if ( $database -eq "" ) {
  write-output "-database parameter must be supplied"
  return
}

# logging 

$hostname = $env:computername
$statusfile = "$env:TEMP\backup_status_${hostname}_${instance}_${database}" 
$STATUS = "Started"
$MSG = ""
$BACKUPCMD = ""

If (Test-Path logs\onlineNetbackupBackup_${hostname}_${instance}_$database.log){
	Remove-Item logs\onlineNetbackupBackup_${hostname}_${instance}_$database.log
}

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path logs\onlineNetbackupBackup_${hostname}_${instance}_$database.log -append

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

if ( $IncludeLogs ) {
  $inclParm = "include logs"
}

if ( $ExcludeLogs ) {
  $inclParm = "exclude logs"
}

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
  write-output "  Email           : $email"
  write-output "  Include Logs    : $IncludeLogs"
  write-output "  Exclude Logs    : $ExcludeLogs"
  write-output ""
  write-output "Command invocation format is:"
  write-output ""
  write-output "  gatherDBSummary.ps1 [-IncludeLogs] [-ExcludeLogs] [-instance <age limit>] -database <database> [-options <options>] [-load <netbackup load module>] [-email <email address>] [-help] "
  write-output ""
  write-output "      instance           - Instance to use (Default: db2)"
  write-output "      database           - comma delimited list of databases to retrieve data from"
  write-output "      options            - database backup options to be passed netbackup"
  write-output "      load               - Netbackup load module (default: C:\Progra~1\VERITAS\NetBackup\bin\nbdb2.dll)"
  write-output "      IncludeLogs        - explicitly include logs in backup"
  write-output "      ExcludeLogs        - exclude logs from backup"
  write-output "      Email to send MSG  - $email"
  write-output "      help               - This message"
  write-output ""
  write-output "      Note: Exclude logs will take precendence over the include logs parameter if both are specified"
  write-output ""
  return
}

write-output "$ts Starting $scriptName"

$send_email = $false

write-output "Backing up $database to Netbackup using the following options: $options"

# start the process

write-output ">>>>>> Processing database $database"

# write the status record
$STARTED = Get-Date -format 'yyyy-MM-dd hh:mm:ss'
write-output "DB2#$STARTED#$STARTED#$hostname#$instance#$database#ONLINE#$STATUS#onlineNetbackupBackup.ps1#$BACKUPCMD#" | Out-File $statusfile -encoding ascii
start-process pscp.exe "-i Putty\Keys\WindowsSCPPrivateKey.ppk $statusfile db2admin@192.168.1.1:realtimeBackupStatus " -wait -nonewwindow -RedirectStandardOutput c:\temp\$uniqueFile_$hostname.PSCP
get-content c:\temp\$uniqueFile_$hostname.PSCP | write-output

$ts = Get-Date -format yyyy-MM-dd-hh:mm:ss

write-output "$ts Connect being issued"
$proc = Start-Process db2 "connect to $database" -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

if ( $proc.ExitCode -ne 0 ) { 
  $STATUS = "Failed at connect"
  $MSG = $proc.ExitCode
  write-output "Connect to database returned $($proc.ExitCode)"
  $send_email = $true
}
else {
  $BACKUPCMD = "backup database $database online load $load $options $inclParm"
  # write the status record
  $CTIME = Get-Date -format 'yyyy-MM-dd hh:mm:ss'
  write-output "DB2#$STARTED#$CTIME#$hostname#$instance#$database#ONLINE#$STATUS#onlineNetbackupBackup.ps1#$BACKUPCMD#$MSG" | Out-File  $statusfile -encoding ascii
  start-process pscp.exe "-i Putty\Keys\WindowsSCPPrivateKey.ppk $statusfile db2admin@192.168.1.1:realtimeBackupStatus " -wait -nonewwindow -RedirectStandardOutput c:\temp\$uniqueFile_$hostname.PSCP
  get-content c:\temp\$uniqueFile_$hostname.PSCP | write-output

  $ts = Get-Date -format yyyy-MM-dd-hh:mm
  write-output "$ts Connect successful"
  write-output "$ts Backup being issued"
  write-output "$ts Backup command used: backup database $database online load $load $options $inclParm"
  $proc = Start-Process db2 "backup database $database online load $load $options $inclParm " -wait -nonewwindow -Passthru -RedirectStandardOutput c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp
  get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp | write-output

  if ( $proc.ExitCode -ne 0 ) { # non-zero return from backup
    write-output "Backup was not successful. Return code was $($proc.ExitCode)"
    $send_email = $true
    $STATUS = "Failed"
    $MSG = $proc.ExitCode
  }
  else { # backup was successful
    $STATUS = "Successful"
    $MSG = ""

    $ts = Get-Date -format yyyy-MM-dd-hh:mm

    # write out a record of the successful backup and send it off to the consolidation server
    write-output "$ts $hostname $instance $database" | Out-File "logs\${hostname}_${instance}_$database.log" -Encoding utf8
    get-content c:\temp\${uniqueFile}_${hostname}_${instance}_$database.temp  | Out-File "logs\${hostname}_${instance}_$database.log" -append
    start-process pscp.exe "-i Putty\Keys\WindowsSCPPrivateKey.ppk logs\${hostname}_${instance}_$database.log db2admin@192.168.1.1:LatestBackups " -wait -nonewwindow -RedirectStandardOutput c:\temp\$uniqueFile_$hostname.PSCP
    get-content c:\temp\$uniqueFile_$hostname.PSCP | write-output

    write-output "$ts Backup was successful"
  }
}

$ts = Get-Date -format yyyy-MM-dd-hh:mm

write-output "$ts Finished $scriptName"

# write the status record
$CTIME = Get-Date -format 'yyyy-MM-dd hh:mm:ss'
write-output "DB2#$STARTED#$CTIME#$hostname#$instance#$database#ONLINE#$STATUS#onlineNetbackupBackup.ps1#$BACKUPCMD#$MSG" | Out-File $statusfile -encoding ascii
start-process pscp.exe "-i Putty\Keys\WindowsSCPPrivateKey.ppk $statusfile db2admin@192.168.1.1:realtimeBackupStatus " -wait -nonewwindow -RedirectStandardOutput c:\temp\$uniqueFile_$hostname.PSCP
get-content c:\temp\$uniqueFile_$hostname.PSCP | write-output


if ( $send_email ) { # something bad happened
  # construct the body of the message
  $ts = Get-Date -format yyyy-MM-dd-hh:mm
  write-output "$ts Sending Email to $email reporting failure"
  Stop-Transcript  # stop the transcript here so that the log can be attached to the email
  write-output "results from the online backup of $hostname / $instance / $database`n" | Out-File c:\temp\$uniqueFile_$hostname.mailBody
  write-output "The last successful backup details are:`n" | Out-File c:\temp\$uniqueFile_$hostname.mailBody -append
  get-content logs\${hostname}_${instance}_$database.log | Out-File c:\temp\$uniqueFile_$hostname.mailBody -append

  $body = get-content "c:\temp\$uniqueFile_$hostname.mailBody" | Out-String

  Send-MailMessage -To "$email" -From "do_not_reply@KAGJCM.com.au" -Subject "$hostname - Online Backup of $database failed" -SmtpServer smtp.KAGJCM.local -Body $body -Attachments "logs\onlineNetbackupBackup_${hostname}_${instance}_$database.log" 
}
else  {
  Stop-Transcript
}

