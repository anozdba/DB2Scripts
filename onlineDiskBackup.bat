@echo off
REM
REM --------------------------------------------------------------------
REM onllineDiskBackup.bat
REM
REM $Id: onlineDiskBackup.bat,v 1.2 2010/03/01 01:31:13 db2admin Exp db2admin $
REM
REM Description:
REM Online Disk Backup script for Windows
REM
REM Usage:
REM   onllineDiskBackup.bat
REM
REM $Name:  $
REM
REM ChangeLog:
REM $Log: onlineDiskBackup.bat,v $
REM Revision 1.2  2010/03/01 01:31:13  db2admin
REM Add in email failure notification
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
  set LCN="d:\backup"
) else (
  set LCN=%3
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
  echo " DB2 Quiesce successful " >>%OUTPUT_FILE%
  set DO_UNQSCE_FLAG=1
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
    db2 backup database %DB% ONLINE to %LCN% COMPRESS INCLUDE LOGS >>%OUTPUT_LOG%
    set RC3=%errorlevel%
    if %RC3% == 0 goto rc3_00
      echo " Backup of %DB% failed with RC= %RC3%" >>%OUTPUT_FILE%
      set SEND_EMAIL=1
      goto cleanup
:rc3_00
      echo " Backup of %DB% successful " >>%OUTPUT_FILE%

:cleanup

:emailchk
if NOT %SEND_EMAIL% == 0 (
  if "%DB%" EQU "" (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of UNKNOWN failed" DEFAULT_EMAIL@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  ) ELSE (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Online Backup of %DB% failed" DEFAULT_EMAIL@KAGJCM.com.au NONE "results from the online backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  )
)
