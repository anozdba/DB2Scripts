#!/bin/bash
# --------------------------------------------------------------------
# exportTable.ksh
#
# $Id: exportTable.ksh,v 1.7 2013/07/16 05:24:16 db2admin Exp db2admin $
#
# Description:
# Script to export and compress a table in one step
#
# Usage:
#  exportTable.ksh -d database -t tablename [-D <directory to put exported file>] [-f <fields to export>]
#
# $Name:  $
#
# ChangeLog:
# $Log: exportTable.ksh,v $
# Revision 1.7  2013/07/16 05:24:16  db2admin
# put in better parameter handling and logging
#
#
# --------------------------------------------------------------------"


if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
if [ -f ~/.profile ]; then
    . ~/.profile
fi

# Usage command
usage () {

    rc=0

#   If a parameter has been passed then echo it
    [[ $# -gt 0 ]] && { echo "${0##*/}: $*" 1>&2; rc=1; }

    cat <<-EOF 1>&2
  usage: exportTable.ksh -d <directory> -l <log literal> [-n <number of days to keep>] [-t]

  Export data from table on a selected database

  options are:
      -d database where the tables exist
      -t table to export
      -D Directory to put the export file in
      -f fields to export (defaults to *)
      -w where clause to apply (default to no where clause)
      -h this help information

EOF

    exit $rc
}

#-----------------------------------------------------------------------
# Set defaults and parse command line

# Default settings
directory=""
database=""
table=""
fields="*"
where=""

# Check command line options
while getopts ":hd:t:D:f:w:" opt; do
    case $opt in
        # Specify a file to drive the processing
        d)  echo Directory $OPTARG will be inspected
            database="$OPTARG" ;;

        t)  echo table $OPTARG will be exported
            table=$OPTARG ;;

        w)  echo Where clause to be used will be $OPTARG
            where="where $OPTARG" ;;

        D)  echo $OPTARG will be used as the directory to place the file in
            directory=$OPTARG ;;

        f)  echo The following foelds will be exported: $OPTARG
            fields=$OPTARG ;;

        # Print out the usage information
        h)  usage ''
            return 1 ;;

        *)  usage 'invalid option(s)'
            return 1 ;;
    esac
done
shift $(($OPTIND - 1))

[[ $# -gt 0 ]] && usage 'Invalid option specified' && return 1

# database MUST be specified
if [[ -z "$database" ]] ;
then
  usage 'Database must be specified';
  return 1 ;
fi

# table MUST be specified
if [[ -z "$table" ]] ;
then
  usage 'Table must be specified';
  return 1 ;
fi

exec >logs/exportTable_${database}_${table}.log 2>&1

echo `date` Exporting table $table residing in database $database to Exported_$table.gz

if [[ -z "$directory" ]];
then
  echo `date` Exported file will be placed in `pwd`
  EDIR=`pwd`  
else
  if [[ -d "$directory/$database" ]];
  then
    echo `date` Exported file will be placed in $directory/$database
    EDIR="$directory/$database"
  else
    if [[ -d "$directory" ]];
    then
      echo `date` Exported file will be placed in $directory
      EDIR=$directory
    else
      echo `date` Directory $directory does not exist
      exit
    fi
  fi
fi
EDIR="$EDIR/"
echo `date` "Export directory is $EDIR"

echo `date` Exporting table $table residing in database $database to ${EDIR}Exported_$table.gz 

# create the pipe to pass the data through ....

rm -f /tmp/exportTable_${table}_fifo.dat
mkfifo /tmp/exportTable_${table}_fifo.dat

# Start the export process ....

db2 connect to $database ; db2 "export to /tmp/exportTable_${table}_fifo.dat of ixf select $fields from $table $where with ur" & 

# start up the compress process ...

gzip  </tmp/exportTable_${table}_fifo.dat  >${EDIR}Exported_${table}.gz 

rm -f /tmp/exportTable_${table}_fifo.dat

echo `date` Export of $table completed.
