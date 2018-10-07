#!/bin/bash
# --------------------------------------------------------------------
# onlineDiskBackup.ksh
#
# $Id: onlineDiskBackup.ksh,v 1.7 2018/09/06 00:54:43 db2admin Exp db2admin $
#
# Description:
# Online Disk Backup script (policy schedule set in db2.conf)
#
# Usage:
#   onlineDiskBackup.ksh
#
# $Name:  $
#
# ChangeLog:
# $Log: onlineDiskBackup.ksh,v $
# Revision 1.7  2018/09/06 00:54:43  db2admin
# convert data item separator from , to #
#
# Revision 1.6  2018/09/05 21:40:19  db2admin
# add in realtime messages to 192.168.1.1
# add in incremental and delta backup types
#
# Revision 1.5  2018/06/01 00:17:07  db2admin
# Allow comments in EMAIL file
#
# Revision 1.4  2017/12/29 01:07:30  db2admin
# rewrite of this script to bring it into line with onlineNetbackupBackup.ksh
# 1. Added in parameters to include/exclude logs
# 2. Added in parameter (-n) to not compress the backup
# 3. Corrected the way that parameters were passed in to make it more consistent
#
# Revision 1.3  2016/07/11 21:37:52  db2admin
# add in start and stop messages
#
# Revision 1.2  2015/08/17 01:43:03  db2admin
# modify the way the script writes out to the log file to try and capture all messages
#
# Revision 1.1  2015/06/19 02:01:54  db2admin
# Initial revision
#
#
# --------------------------------------------------------------------

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
if [ -f ~/.profile ]; then
    . ~/.profile
fi

scriptName=$(basename "$0")

# Usage command
usage () {

    rc=0

#   If a parameter has been passed then echo it [${0##*/} is the script name]
    [[ $# -gt 0 ]] && { echo "${0##*/}: $*" 1>&2; rc=1; }

    cat <<-EOF 1>&2
  usage: onlineDiskBackup.ksh [-h] [-i] [-E] [-n] [-I] [-D] -d <database> [-t <target directory>] [-e <email address>] [-p <parms>] 

  Takes an online backup of the specified database to disk

  if using positional parameters then the command should be:

          onlineDiskBackup.ksh <database> <target directory> [<email address>]]

  i.e. if you want to specify an email address in a positional parameter execution then all parameters must be entered 

  options are:
      -h this output
      -d database to backup
      -e email address to send failure warnings to (defaults to contents of scripts/EMAIL_ONLYDBA)
      -t target directory for the backup (defaults to backups)
      -p backup parameters (parameters that can be set here are: DEDUP_DEVICE, WITH x BUFFERS, BUFFER size and PARALLELISM x)
      -n dont compress the backup
      -i force an include logs on the backup line (the db2 default implies an include logs)
      -E force an exclude logs on the backup line 
      -I incremental backup (cummulative)
      -D incremental backup (delta)

      Note: the last -i or -E found on the command line will be used

EOF

    exit $rc
}

#-----------------------------------------------------------------------
# Set defaults and parse command line

# Default settings
database=""
targetDir="backups"
email=""
parms=""
includeLogs=""
compress="compress"
backupType=""

# Check command line options
while getopts ":hiEd:t:e:p:nID" opt; do
    case $opt in
        # Specify a file to drive the processing
        d)  echo Database $OPTARG will be backed up
            database="$OPTARG" ;;

        # Dont compress the backup
        n)  echo Backup will NOT be compressed
            compress="" ;;

        # Specify the directory to put the backup in
        t)  echo Directory $OPTARG will be used to hold the backup
            targetDir="$OPTARG" ;;

        # explicitly set the include logs on the backup command
        i)  echo Include Logs will be explicitly set
            includeLogs="include logs" ;;

        # explicitly set the exclude logs on the backup command
        E)  echo Exclude Logs will be explicitly set
            includeLogs="exclude logs" ;;

        #  Set the email recipient - both NORMAL and ERROR
        e)  echo Report will be sent to $OPTARG
            email="$OPTARG" ;;

        #  Set the backup parameters
        p)  echo Backup parameters will be \"$OPTARG\"
            parms="$OPTARG" ;;

        #  Set the backup type to cummulative incremental
        I)  echo 'Incremental backup (cummulative)'
            backupType="incremental" ;;

        #  Set the backup type to delta incremental
        D)  echo 'Incremental backup (delta)'
            backupType="incremental delta" ;;

        # Print out the usage information
        h)  usage ''
            return 1 ;;

        *)  usage 'invalid option(s)'
            return 1 ;;
    esac
done
shift $(($OPTIND - 1))      # get rid of any parameters processed by getopts

# assign parameters if not explicitly assigned

for i in "$@"
do
   if [ "$database" = "" ]
     then
       echo Database $i will be backed up
       database=$i
       shift
   else
       echo "Unknown parameter $i"
   fi
done

# check the supplied parameters
[[ $# -gt 0 ]] && usage 'Invalid option specified' && return 1
[[ -z $database ]] && usage 'Database option must be specified' && return 1

# set defaults if not set
[[ -z $email ]] && email=`cat scripts/EMAIL_ONLYDBA | grep -v "^#" `

# end of parameter section
#-----------------------------------------------------------------------

export machine=`uname -n`
tgtdate=`date '+%Y-%m-%d'`

# ---------------------------------------------------------------------------
# Backup the database
# ---------------------------------------------------------------------------

exec >logs/backup_$database.log 2>&1

echo `date` "Parameters being used:"
echo `date` "  Database: $database"
echo `date` "  Directory to hold the backup: $targetDir"
echo `date` "  Email to use when backup fails: $email"

# set when backup has faled - email is sent
SEND_EMAIL=0; 
# set when backup has not faled - backup details are sent to 192.168.1.1
SEND_FILE=0;    
BACKUPCMD=''
MSG=''
STATUS='Started'

echo `date` Starting $0
OUTPUT_LOG="logs/$machine-$DB2INSTANCE-$database.log";

STARTED=`date '+%Y-%m-%d %H:%M:%S'`
echo DB2#$STARTED#`date '+%Y-%m-%d %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#ONLINE#$STATUS#$scriptName##" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
if [[ $machine == "192.168.1.1" ]]; then
  SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
else
  SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
fi

echo `date` "**** Online Backup of $database to $targetDir ****" 
# -------------------------------------------------------------------------- #
# Connect to Database                                                        #
# -------------------------------------------------------------------------- #
echo `date` "*---" Connect to $database "---*" 
MSG0=`db2 connect to $database`
RC0=$(echo $MSG0 | cut -c1-8)
if [[ $RC0 != "Database" ]]; then
  echo `date` " DB2 Connect failed "  
  echo `date` " Message: $MSG0 " 
  STATUS='Failed at connect'
  MSG=$MSG0
  SEND_EMAIL=1;
else
  echo `date` " DB2 Connect successful " 

  # -------------------------------------------------------------------------- #
  # Reset the connection                                                       #
  # -------------------------------------------------------------------------- #
  echo `date` "*--- Reset the connection ----*" 
  MSG2=`db2 connect reset`
  RC2=$(echo $MSG2 | cut -c1-8)
  if [[ $RC2 != "DB20000I" ]]; then
      echo `date` " DB2 Connect reset failed with RC = $RC2 " 
      echo `date` " Message: $MSG2 " 
      STATUS='Failed at reset'
      MSG=$MSG2
      SEND_EMAIL=1;
  else
      echo `date` " DB2 Connect reset successful " 
      # -------------------------------------------------------------------------- #
      # Perform the backup                                                         #
      # -------------------------------------------------------------------------- #
      echo `date` "*-- Backup the database --*" 
      echo `date` "Executing: db2 backup database $database online $backupType to $targetDir $parms $compress $includeLogs without prompting"
      BACKUPCMD="db2 backup database $database online $backupType to $targetDir $parms $compress $includeLogs without prompting"
      echo DB2#$STARTED#`date '+%Y-%m-%d %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#ONLINE#$STATUS#$scriptName#$BACKUPCMD#$MSG" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
      if [[ $machine == "192.168.1.1" ]]; then
        SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
        echo `date` 'Backup Status File Copied' $SCP_RESULT
      else
        SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
        echo `date` 'Backup Status File Copied' $SCP_RESULT
      fi
      MSG3=`db2 backup database $database online $backupType to $targetDir $parms $compress $includeLogs without prompting`
      RC3=$(echo $MSG3 | cut -c1-8)
      if [[ $RC3 != "Backup s" ]]; then
          echo `date` " Backup of $database failed with RC= $RC3" 
          echo `date` " Message: $MSG3 " 
          STATUS='Failed'
          MSG=$MSG3
          SEND_EMAIL=1;
      else
          echo `date` " Backup of $database successful " 
          echo `date` $machine $DB2INSTANCE $database $MSG3 >$OUTPUT_LOG
          STATUS='Successful'
          MSG=''
          SEND_FILE=1;
      fi
  fi
fi

RC=0
if [[ $SEND_FILE != 0 ]]; then
  if [[ $machine == "192.168.1.1" ]]; then
    SCP_RESULT=`cp $OUTPUT_LOG LatestBackups`
    echo `date` $SCP_RESULT 
  else
    SCP_RESULT=`scp $OUTPUT_LOG db2admin@192.168.1.1:LatestBackups`
    echo `date` $SCP_RESULT 
  fi
fi

# always send a status file

echo DB2#$STARTED#`date '+%Y-%m-%d %H:%M:%S'`#$machine#$DB2INSTANCE#$database#ONLINE#$STATUS#$scriptName#$BACKUPCMD#$MSG >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
if [[ $machine == "192.168.1.1" ]]; then
  SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
else
  SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
fi

echo `date` Finished $0
if [[ $SEND_EMAIL != 0 ]]; then
  cat logs/backup_$database.log | unix2dos | mailx -s"$tgtdate: *** FAIL *** Online backup of $database on $machine" $email
  RC=8
fi

exit $RC
