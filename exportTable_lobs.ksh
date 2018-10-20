#!/bin/bash
# --------------------------------------------------------------------
# exportTable.ksh
#
# $Id: exportTable_lobs.ksh,v 1.2 2010/03/09 04:41:15 db2admin Exp db2admin $
#
# Description:
# Script to export and compress a table in one step
#
# Usage:
#  exportTable.ksh database tablename [directory to put exported file]
#
# $Name:  $
#
# ChangeLog:
# $Log: exportTable_lobs.ksh,v $
# Revision 1.2  2010/03/09 04:41:15  db2admin
# 1. Generalise lob export directory
# 2. Correct selection of export directory
#
# Revision 1.1  2009/11/19 03:35:56  db2admin
# Initial revision
#
# Revision 1.6  2009/05/25 02:28:31  db2admin
# Clean up pipe after export
#
# Revision 1.5  2009/05/06 02:23:14  db2admin
# use a directory with the database name if it exists under the export directory
#
# Revision 1.4  2009/01/04 23:25:33  db2admin
# Ensure STDERR is also redirected to the log file
#
# Revision 1.3  2008/12/14 22:51:16  db2admin
# make the pipe table specific
#
# Revision 1.1  2008/09/25 22:36:41  db2admin
# Initial revision
#
# --------------------------------------------------------------------"

echo Exporting table $2 residing in database $1 to Exported_$2.gz

exec >logs/export_$1_$2.log 2>&1

if [[ -z "$3" ]];
then
  echo Exported file will be placed in `pwd`
  EDIR=`pwd`  
else
  if [[ -d "$3/$1" ]];
  then
    echo Exported file will be placed in $3/$1
    EDIR="$3/$1"
  else
    if [[ -d "$3" ]];
    then
      echo Exported file will be placed in $3
      EDIR=$3
    else
      echo Directory $3 does not exist
      exit
    fi
  fi
fi
EDIR="$EDIR/"
echo "Export directory is $EDIR"

echo Exporting table $2 residing in database $1 to ${EDIR}Exported_$2.gz `date`

# create the pipe to pass the data through ....

rm -f /tmp/exportTable_$2_fifo.dat
mkfifo /tmp/exportTable_$2_fifo.dat

# Start the export process ....

db2 connect to $1 ; db2 "export to /tmp/exportTable_$2_fifo.dat of ixf lobs to ${EDIR} lobfile Lob_$2 modified by lobsinfile select * from $2 with ur" & 

# start up the compress process ...

gzip  </tmp/exportTable_$2_fifo.dat  >${EDIR}Exported_$2.gz 

rm -f /tmp/exportTable_$2_fifo.dat

echo Export of $2 completed.  `date`
