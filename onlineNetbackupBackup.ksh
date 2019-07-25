#!/bin/bash
# --------------------------------------------------------------------
# onlineNetbackupBackup.ksh
#
# $Id: onlineNetbackupBackup.ksh,v 1.13 2019/05/06 01:44:52 db2admin Exp db2admin $
#
# Description:
# Online Netbackup Backup script (policy schedule set in db2.conf)
#
# Usage:
#   onlineNetbackupBackup.ksh
#
# $Name:  $
#
# ChangeLog:
# $Log: onlineNetbackupBackup.ksh,v $
# Revision 1.13  2019/05/06 01:44:52  db2admin
# timestamp the backup log file
#
# Revision 1.12  2018/09/06 00:56:52  db2admin
# change data item seperator from , to #
#
# Revision 1.11  2018/09/03 23:56:42  db2admin
# correct literal string
# .
#
# Revision 1.10  2018/09/03 23:52:55  db2admin
# add in incremental parameters
#
# Revision 1.9  2018/08/21 05:48:20  db2admin
# add in script name to the status record
#
# Revision 1.8  2018/08/20 00:12:41  db2admin
# correct the data formatting
#
# Revision 1.7  2018/08/20 00:04:31  db2admin
# add in code to send back status information to 192.168.1.1 during the execution of the backup
#
# Revision 1.6  2018/06/01 00:19:08  db2admin
# Allow comments in EMAIL file
#
# Revision 1.5  2017/12/28 23:17:48  db2admin
# make the hard coded 'include logs' parameter optional via the -i parameter
# include new -E parameter to exclude logs
#
# Revision 1.4  2017/04/04 12:38:44  db2admin
# correct parameter display
#
# Revision 1.3  2017/04/04 02:23:51  db2admin
# add in parameter to allow setting of backup parameters
#
# Revision 1.2  2016/11/20 22:13:18  db2admin
# correct script name and add in description of -h option
#
# Revision 1.1  2016/11/14 23:59:59  db2admin
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
  usage: onlineNetbackupBackup.ksh [-h] [-i] [-E] [-I] [-D] -d <database> [-l <load library>] [-e <email address>] [-p <backup options>] 

  Takes an online backup of the specified database 

  if using positional parameters then the command should be:

          onlineNetbackupBackup.ksh <database> [<load library> [<email address>]]

  i.e. if you want to specify an email address in a positional parameter execution then all parameters must be entered 

  options are:
      -h this output
      -d database to backup
      -e email address to send failure warnings to (defaults to contents of scripts/EMAIL_ONLYDBA)
      -l netbackup load library (defaults to /usr/openv/netbackup/bin/nbdb2.so64)
      -i force an include logs on the backup line (the db2 default implies an include logs)
      -p options to be applied to the backup
      -I incremental backup (cummulative)
      -D incremental backup (delta)
      -E force an exclude logs on the backup line 

      Note: the last -i or -E found on the command line will be used

EOF

    exit $rc
}

#-----------------------------------------------------------------------
# Set defaults and parse command line

# Default settings
database=""
load=""
email=""
parms=""
backupType=""
includeLogs=""

# Check command line options
while getopts ":hiEd:l:e:p:ID" opt; do
    case $opt in
        # Specify a file to drive the processing
        d)  echo Database $OPTARG will be backed up
            database="$OPTARG" ;;

        # Use the default inptu file to drive the process
        l)  echo Load library $OPTARG will be used
            load="$OPTARG" ;;

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
        I)  echo 'Incremental backup (delta)'
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
   elif [ "$load" = "" ]
     then
       echo Load library $i will be used
       load=$i
       shift
   elif [ "$email" = "" ]
     then
       echo Report will be sent to $i
       email=$i
       shift
   else
       echo "Unknown parameter $i"
   fi
done

# check the supplied parameters
[[ $# -gt 0 ]] && usage 'Invalid option specified' && return 1
[[ -z $database ]] && usage 'Database option must be specified' && return 1

# set defaults if not set
[[ -z $load ]] && load="/usr/openv/netbackup/bin/nbdb2.so64"
[[ -z $email ]] && email=`cat scripts/EMAIL_ONLYDBA | grep -v "^#" `

# end of parameter section
#-----------------------------------------------------------------------

export machine=`uname -n`
tgtdate=`date '+%Y-%m-%d'`
TS=`date '+%Y-%m-%d-%H.%M.%S'`

# ---------------------------------------------------------------------------
# Backup the database
# ---------------------------------------------------------------------------

exec >logs/backup_${database}_$TS.log 2>&1

echo `date` "Parameters being used:"
echo `date` "  Database: $database"
echo `date` "  Netbackup Load Library: $load"
echo `date` "  Email to use when backup fails: $email"

# set when backup has faled - email is sent
SEND_EMAIL=0; 
# set when backup has not faled - backup details are sent to 192.168.1.1
SEND_FILE=0;    

echo `date` Starting $0
OUTPUT_LOG="logs/$machine-$DB2INSTANCE-$database.log";
BACKUPCMD=''
MSG=''
STATUS='Started'

echo `date` "**** Online Backup of $database ****" 
STARTED=`date '+%Y-%m-%d %H:%M:%S'`
echo DB2#$STARTED#`date '+%Y-%m-%d %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#ONLINE#$STATUS#$scriptName##" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
if [[ $machine == "192.168.1.1" ]]; then
  SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
else
  SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
fi

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
      echo `date` "Executing: db2 backup database $database online $backupType load $load $parms $includeLogs"
      BACKUPCMD="db2 backup database $database online $backupType load $load $parms $includeLogs"
      echo DB2#$STARTED#`date '+%Y-%m-%d %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#ONLINE#$STATUS#$scriptName#$BACKUPCMD#$MSG" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
      if [[ $machine == "192.168.1.1" ]]; then
        SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
        echo `date` 'Backup Status File Copied' $SCP_RESULT
      else
        SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
        echo `date` 'Backup Status File Copied' $SCP_RESULT
      fi
      MSG3=`db2 backup database $database online $backupType load $load $parms $includeLogs`
      RC3=$(echo $MSG3 | cut -c1-8)
      if [[ $RC3 != "Backup s" ]]; then
          echo `date` " Backup of $database failed with RC= $RC3" 
          echo `date` " Message: $MSG3 " 
          SEND_EMAIL=1;
          STATUS='Failed'
          MSG=$MSG3
      else
          echo `date` " Backup of $database successful " 
          echo `date` $machine $DB2INSTANCE $database $MSG3 >$OUTPUT_LOG
          SEND_FILE=1;
          STATUS='Successful'
          MSG=''
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

echo `date` Finished $0
if [[ $SEND_EMAIL != 0 ]]; then
  cat logs/backup_$database.log | unix2dos | mailx -s"$tgtdate: *** FAIL *** Online backup of $database on $machine" $email
  RC=8
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

exit $RC
