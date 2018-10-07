@echo off
REM
REM --------------------------------------------------------------------
REM onllineDiskBackup.bat
REM
REM $Id: onllineDiskBackup.bat,v 1.1 2008/09/25 22:36:42 db2admin Exp db2admin $
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
REM $Log: onllineDiskBackup.bat,v $
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

set DO_UNQSCE_FLAG=0
set SEND_EMAIL=0
set DB2INSTANCE=%1
set DB=%2
set OUTPUT_FILE="C:\Documents and Settings\db2admin\logs\onlineBackup_%DB%.log"
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
    db2 backup database %DB% ONLINE to %LCN% COMPRESS
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
  echo "Should be sending an email now!"
  REM ???? cat %OUTPUT_FILE%  | mailx -s"Online backup of %DB%" mpl_it_dba_udb@KAGJCM.com.au
)
