@echo off
REM
REM --------------------------------------------------------------------
REM exportTable.bat
REM
REM $Id: exportTable.bat,v 1.2 2010/03/11 22:23:07 db2admin Exp db2admin $
REM
REM Description:
REM Windows script to expoert a table
REM
REM Usage:
REM   exportTable.bat <database> <table> <directory to export to>
REM   Default archive directory is d:\archivedDiagLogs
REM
REM $Name:  $
REM
REM ChangeLog:
REM $Log: exportTable.bat,v $
REM Revision 1.2  2010/03/11 22:23:07  db2admin
REM changed the directories being used - made similar to the lobs export
REM
REM Revision 1.1  2009/11/17 01:03:35  db2admin
REM Initial revision
REM
REM
REM --------------------------------------------------------------------"

echo Exporting table %2 residing in database %1 to %3\%1\Exported_%2.dat

echo >logs\export_%1_%2.log 

echo "Export directory is %3\%1\" >>logs\export_%1_%2.log 

echo "Exporting table %2 residing in database %1 to %3\%1\Exported_%2.DAT" >>logs\export_%1_%2.log 

REM Start the export process ....

db2 connect to %1 >>logs\export_%1_%2.log
db2 "export to %3\%1\exportTable_%2.dat of ixf select * from %2 with ur" >>logs\export_%1_%2.log

echo Export of %2 completed. >>logs\export_%1_%2.log 
