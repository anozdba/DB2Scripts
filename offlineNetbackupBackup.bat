@echo off
REM
REM --------------------------------------------------------------------
REM offlineNetbackupBackup.bat
REM
REM $Id: offlineNetbackupBackup.bat,v 1.5 2010/03/01 01:27:46 db2admin Exp db2admin $
REM
REM Description:
REM Offline Netbackup Backup script for Windows (policy / schedule set in db2.conf)
REM
REM Usage:
REM   offlineNetbackupBackup.bat
REM
REM $Name:  $
REM
REM ChangeLog:
REM $Log: offlineNetbackupBackup.bat,v $
REM Revision 1.5  2010/03/01 01:27:46  db2admin
REM Add in email failure notification
REM
REM Revision 1.4  2009/08/19 02:30:02  db2admin
REM Change target machine name to 192.168.1.1
REM
REM Revision 1.3  2009/02/24 22:02:39  db2admin
REM Put timestamp in timestamp file
REM
REM Revision 1.1  2008/09/25 22:36:42  db2admin
REM Initial revision
REM
REM --------------------------------------------------------------------

REM ##############################################################################
REM #  This script back ups the database (OFFLINE)                               #
REM #  It creates an execution log in logs/backup_%DB%.log                        #
REM ##############################################################################
if (%3) == () ( 
  set LOAD="'C:\Program Files\VERITAS\NetBackup\bin\nbdb2.dll'"
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
set OUTPUT_FILE="C:\Documents and Settings\db2admin\logs\offlineBackup_%DB%.log"
set OUTPUT_LOG="C:\Docume~1\db2admin\logs\%machine%_%DB2INSTANCE%_%DB%.log"
echo "Subject: Offline Backup for %DB%" >%OUTPUT_FILE%
echo  "**** Start: Offline Backup of %DB% ****" >>%OUTPUT_FILE%
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
  REM # QUIESCE Database for exclusive use                                       #
  REM ############################################################################
  @time /T  >>%OUTPUT_FILE%
  echo "*--- Quiesce Database ---*" >>%OUTPUT_FILE%
  db2 quiesce db immediate force connections >>%OUTPUT_FILE%
  set RC1=%errorlevel%
  if %RC1% == 0 goto rc1_00
    echo " DB2 Quiesce failed with RC = %RC1% " >>%OUTPUT_FILE%
    set SEND_EMAIL=1
    goto cleanup
:rc1_00
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
      db2 backup database %DB% LOAD %LOAD% >>%OUTPUT_LOG%
      set RC3=%errorlevel%
      if %RC3% == 0 goto rc3_00
        echo " Backup of %DB% failed with RC= %RC3%" >>%OUTPUT_FILE%
        set SEND_EMAIL=1
        goto cleanup
:rc3_00
        echo " Backup of %DB% successful " >>%OUTPUT_FILE%
        set SEND_FILE=1
        REM ############################################################################
        REM # Connect to Database                                                      #
        REM ############################################################################
        @time /T  >>%OUTPUT_FILE%
        echo "*--- Connect to DB ---*" >>%OUTPUT_FILE%
        db2 connect to %DB%
        set RC4=%errorlevel%
        if %RC4% == 0 goto rc4_00
          echo " DB2 Connect failed " >>%OUTPUT_FILE%
          set SEND_EMAIL=1
          goto cleanup
:rc4_00
          echo " DB2 Connect successful " >>%OUTPUT_FILE%
          REM ############################################################################
          REM # UNQUIESCE database to restore user access.                               #
          REM ############################################################################
          @time /T  >>%OUTPUT_FILE%
          echo  "*--- Unquiesce database ---*" >>%OUTPUT_FILE%
          db2 unquiesce db
          set RC5=%errorlevel%
          if %RC5% == 0 goto rc5_00
            echo " DB2 Unquiesce failed with RC = %RC5%" >>%OUTPUT_FILE%
            set SEND_EMAIL=1
            goto cleanup
:rc5_00
            echo " DB2 Unquiesce successful " >>%OUTPUT_FILE%
            set DO_UNQSCE_FLAG=0
            REM ############################################################################
            REM # Reset the Connection                                                     #
            REM ############################################################################
            @time /T  >>%OUTPUT_FILE%
            echo  "*--- Reset the connection ----*" >>%OUTPUT_FILE%
            db2 connect reset
            set RC6=%errorlevel%
            if %RC6% == 0 goto rc6_00
              echo " DB2 Connect reset failed with RC = %RC6% " >>%OUTPUT_FILE%
              set SEND_EMAIL=1
              goto cleanup
:rc6_00
            echo " DB2 Connect reset successful " >>%OUTPUT_FILE%

:cleanup
REM ############################################################################
REM # This loop gets executed if an error is encountered before UNQUIESCEing   #
REM # the database during the execution of the above code.                     #
REM ############################################################################
REM # Connect to Database                                                      #
REM ############################################################################
@time /T  >>%OUTPUT_FILE%
if %DO_UNQSCE_FLAG% == 0 goto emailchk
  echo  "*--- Connect to DB for UNQUIESCE due to failure---*" >>%OUTPUT_FILE%
  db2 connect to %DB%
  set RC7=%errorlevel%
  if %RC7% == 0 goto rc7_00
    echo " DB2 Connect for unquiesce failed " >>%OUTPUT_FILE%
    set SEND_EMAIL=1
    REM goto emailchk  not required because may as well try to do unquiesce
:rc7_00
    echo " DB2 Connect successful " >>%OUTPUT_FILE%
    REM ############################################################################
    REM # UNQUIESCE database to restore user access .                              #
    REM ############################################################################
    @time /T  >>%OUTPUT_FILE%
    echo  "*--- Unquiesce database ---*" >>%OUTPUT_FILE%
    db2 unquiesce db
    set RC8=%errorlevel%
    if %RC8% == 0 goto rc8_00
      echo " DB2 Unquiesce failed with RC = %RC8%" >>%OUTPUT_FILE%
      set SEND_EMAIL=1
      goto emailchk  
:rc8_00
      echo " DB2 Unquiesce successful " >>%OUTPUT_FILE%
      REM ############################################################################
      REM # Reset the Connection                                                     #
      REM ############################################################################
      @time /T  >>%OUTPUT_FILE%
      echo  "*--- Reset the connection ----*" >>%OUTPUT_FILE%
      db2 connect reset
      set RC9=%errorlevel%
      if %RC9% == 0 goto rc9_00
        echo " DB2 Connect reset failed with RC = %RC9% " >>%OUTPUT_FILE%
        set SEND_EMAIL=1
        goto emailchk  
:rc9_00
      echo " DB2 Connect reset successful " >>%OUTPUT_FILE%

:emailchk
if NOT %SEND_EMAIL% == 0 (
  if "%DB%" EQU "" (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Offline Backup of UNKNOWN failed" mpl_it_dba_udb@KAGJCM.com.au NONE "results from the offline backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  ) ELSE (
    cscript.exe c:\udbdba\scripts\sendEmail.vbs "%machine% - Offline Backup of %DB% failed" mpl_it_dba_udb@KAGJCM.com.au NONE "results from the offline backup of %machine% / %DB2INSTANCE% / %DB% :" %OUTPUT_FILE%  %OUTPUT_LOG%
  )
)

if NOT %SEND_FILE% == 0 (
  echo "Copying Backup details file to 192.168.1.1" >>%OUTPUT_FILE%
  if exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
  if not exist "C:\Documents and Settings\db2admin\Application Data\Putty\Keys\WindowsSCPPrivateKey.ppk" c:\udbdba\scripts\pscp  -i "C:\UDBDBA\Putty\Keys\WindowsSCPPrivateKey.ppk" "%OUTPUT_LOG%" db2admin@192.168.1.1:LatestBackups
)
