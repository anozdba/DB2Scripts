@echo off
REM
REM --------------------------------------------------------------------
REM exportTable_lobs.bat
REM
REM $Id: exportTable_lobs.bat,v 1.1 2010/03/11 22:24:16 db2admin Exp db2admin $
REM
REM Description:
REM Windows script to export a table a table with lobs
REM
REM Usage:
REM   exportTable_lobs.bat <database> <table> <directory to export to>
REM   Default archive directory is d:\archivedDiagLogs
REM
REM   the directory that this is run from MUST have a log directory, a <3rdparm> 
REM   sub directory and a<3rdparm>\lobs directory
REM
REM $Name:  $
REM
REM ChangeLog:
REM $Log: exportTable_lobs.bat,v $
REM Revision 1.1  2010/03/11 22:24:16  db2admin
REM Initial revision
REM
REM
REM --------------------------------------------------------------------"

echo Exporting table %2 residing in database %1 to %3\%1\Exported_%2.dat

echo >logs\export_%1_%2.log 

echo "Export directory is %3" >>logs\export_%1_%2.log 

echo "Exporting table %2 residing in database %1 to %3\%1\Exported_%2.DAT" >>logs\export_%1_%2.log 

REM Start the export process ....

db2 connect to %1 >>logs\export_%1_%2.log
db2 "export to %3\%1\exportTable_%2.dat of ixf lobs to %3\%1\lobs lobfile Lob_%2 modified by lobsinfile select * from %2 with ur" >>logs\export_%1_%2.log

echo Export of %2 completed. >>logs\export_%1_%2.log 
