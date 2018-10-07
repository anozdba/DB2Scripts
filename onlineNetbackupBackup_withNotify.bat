@echo off
REM
REM --------------------------------------------------------------------
REM onllineNetbackupBackup.bat
REM
REM $Id: onlineNetbackupBackup_withNotify.bat,v 1.1 2013/07/16 05:30:24 db2admin Exp db2admin $
REM
REM Description:
REM Online Netbackup Backup script for Windows (policy / schedule set in db2.conf)
REM
REM Usage:
REM   onllineNetbackupBackup.bat
REM
REM $Name:  $
REM
REM ChangeLog:
REM $Log: onlineNetbackupBackup_withNotify.bat,v $
REM Revision 1.1  2013/07/16 05:30:24  db2admin
REM Initial revision
REM
REM Revision 1.9  2010/10/28 04:36:06  db2admin
REM script to take a backup of a Db2 database uusing netbackup
REM
REM Revision 1.8  2010/03/01 00:24:38  db2admin
REM send email if failure
REM
REM Revision 1.7  2009/08/19 02:30:34  db2admin
REM Change target machine name to 192.168.1.1
REM
REM Revision 1.6  2009/03/17 01:12:25  db2admin
REM correct error in script that prevented backup
REM
REM Revision 1.4  2009/02/13 05:23:00  db2admin
REM Add in copy of backup details to 192.168.1.1 (not currently workin)
REM
REM Revision 1.3  2008/12/21 22:21:15  m08802
REM Add in the include logs parameter
REM
REM Revision 1.2  2008/12/09 22:34:17  db2admin
REM Correct problem with LOAD name
REM
REM Revision 1.1  2008/09/25 22:36:42  db2admin
REM Initial revision
REM
REM --------------------------------------------------------------------

REM ##############################################################################
REM #  This script back ups the database (ONLINE)                                #
REM #  It creates an execution log in logs/backup_%DB%.log                       #
REM ##############################################################################
if (%3) == () ( 
  set LOAD="C:\Progra~1\VERITAS\NetBackup\bin\nbdb2.dll"
) else (
  set LOAD=%3
)

FOR /f "tokens=2-5 delims=/ " %%i in ('date /t') do (
  set DATE_TS=%%k_%%j_%%i
)

FOR /f "tokens=1-2 delims=/: " %%i in ('time /t') do (
  set TIME_TS=%%i_%%j
)

set TS=%DATE_TS%_%TIME_TS%

FOR /f "tokens=1-2 delims=/: " %%i in ('hostname') do (
  set machine=%%i
)
set DO_UNQSCE_FLAG=0
set SEND_EMAIL=0
set SEND_FILE=0
set DB2INSTANCE=%1
set DB=%2
set OUTPUT_FILE="C:\Documents and Settings\db2admin\logs\onlineBackup_%DB%.log"
set OUTPUT_LOG="C:\Docume~1\db2admin\logs\%machine%_%DB2INSTANCE%_%DB%.log"
echo "Subject: Online Backup for %DB%" >%OUTPUT_FILE%
echo  "**** Start: Online Backup of %DB% ****" >>%OUTPUT_FILE%
REM ##############################################################################
REM # Connect to Database                                                        #
REM ##############################################################################
@date /T  >>%OUTPUT_FILE%
@time /T  >>%OUTPUT_FILE%
echo "*--- Connect to DB ---*" >>%OUTPUT_FILE%
db2 connect to %DB% >>%OUTPUT_FILE%
set RC0=%errorlevel%
if %RC0% == 0 goto rc0_00 
  echo " DB2 Connect failed with RC = %RC0% " >>%OUTPUT_FILE%
  set SEND_EMAIL=1
  goto cleanup
:rc0_00
  echo " DB2 Connect successful " >>%OUTPUT_FILE%
  REM ############################################################################
  REM # Reset the Connection                                                     #
  REM ############################################################################
  @time /T  >>%OUTPUT_FILE%
  echo "*--- Reset the connection ----*" >>%OUTPUT_FILE%
  db2 connect reset
  set RC2=%errorlevel%
  if %RC2% == 0 goto rc2_00
    echo " DB2 Connect reset failed with RC = %RC2% " >>%OUTPUT_FILE%
    set SEND_EMAIL=1
    goto cleanup
:rc2_00
    echo " DB2 Connect reset successful " >>%OUTPUT_FILE%
    REM ############################################################################
    REM # Perform backup.                                                          #
    REM ############################################################################
    @time /T  >>%OUTPUT_FILE%
    echo  "*-- Backup the database --*" >>%OUTPUT_FILE%
    echo "%TS% %machine% %DB2INSTANCE% %DB%" >%OUTPUT_LOG%
    db2 backup database %DB% ONLINE LOAD %LOAD% include logs >>%OUTPUT_LOG%
    set RC3=%errorlevel%
    if %RC3% == 0 goto rc3_00
      set SEND_EMAIL=1
      echo " DB2 Backup failed with RC = %RC3% " >>%OUTPUT_FILE%
      goto cleanup
:rc3_00
      echo " Backup of %DB% successful " >>%OUTPUT_FILE%
      set SEND_FILE=1
      echo 

:cleanup

:emailchk
if NOT %SEND_EMAIL% == 0 (
  
  REM Send an email
  if "%DB%" EQU "" (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of UNKNOWN failed" mpl_it_dba_udb@KAGJCM.com.au,allan_porto@KAGJCM.com.au,doug_miller@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  ) ELSE (
    REM echo cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of %DB% failed" mpl_it_dba_udb@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of %DB% failed" mpl_it_dba_udb@KAGJCM.com.au,allan_porto@KAGJCM.com.au,doug_miller@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  )
) ELSE (
  if "%DB%" EQU "" (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of UNKNOWN succeeded" mpl_it_dba_udb@KAGJCM.com.au,allan_porto@KAGJCM.com.au,doug_miller@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  ) ELSE (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of %DB% succeeded" mpl_it_dba_udb@KAGJCM.com.au,allan_porto@KAGJCM.com.au,doug_miller@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  )
)


if NOT %SEND_FILE% == 0 (
  echo "Copying Backup details file to 192.168.1.1" >>%OUTPUT_FILE%
  if exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
  if exist "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\users\db2admin\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
  if exist "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
)

