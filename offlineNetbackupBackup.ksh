#!/bin/ksh
# --------------------------------------------------------------------
# offlineNetbackupBackup.ksh
#
# $Id: offlineNetbackupBackup.ksh,v 1.8 2018/09/17 05:45:31 db2admin Exp db2admin $
#
# Description:
# Offline Netbackup Backup script for Unix (policy / schedule set in db2.conf)
#
# Usage:
#   offlineNetbackupBackup.ksh
#
# $Name:  $
#
# ChangeLog:
# $Log: offlineNetbackupBackup.ksh,v $
# Revision 1.8  2018/09/17 05:45:31  db2admin
# modfiy the column separator from , to #
#
# Revision 1.7  2018/08/21 05:50:29  db2admin
# add script name into the status record
#
# Revision 1.6  2018/08/20 00:04:49  db2admin
# add in code to send back status information to 192.168.1.1 during the execution of the backup
#
# Revision 1.5  2009/08/19 02:28:03  db2admin
# Change target machine name to 192.168.1.1
#
# Revision 1.4  2009/04/29 00:54:52  db2admin
# Add in generation of Return code
#
# Revision 1.3  2009/03/03 21:16:44  db2admin
# initialise the send file flag
#
# Revision 1.2  2009/02/12 22:24:17  db2admin
# Add in  code to create a last backup file
# and to scp that file back to 192.168.1.1 for consolidation
#
# Revision 1.1  2008/09/25 22:36:42  db2admin
# Initial revision
#
# --------------------------------------------------------------------

##############################################################################
#  This script back ups the database (OFFLINE)                               #
#  It creates an execution log in logs/backup_$DB.log                        #
##############################################################################
if [[ "$2" = "" ]]; then
  LOAD="/usr/openv/netbackup/bin/nbdb2.so64"
else
  LOAD="$2"
fi

scriptName=$(basename "$0")

DO_UNQSCE_FLAG=0;
BACKUPCMD=''
STATUS='Started'
SEND_FILE=0;
SEND_EMAIL=0;
DBS="$1";
for DB in $DBS;
do
  database=$DB
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
  if [ -f ~/.profile ]; then
    . ~/.profile
  fi
  machine=`hostname`;
  OUTPUT_LOG="logs/$machine-$DB2INSTANCE-$DB.log";
  OUTPUT_FILE="logs/offlineBackup_$DB.log";

  echo "Subject: Offline Backup for $DB" >$OUTPUT_FILE
  echo `date` "**** Start: Offline Backup of $DB ****" >>$OUTPUT_FILE

  STARTED=`date '+%d/%m/%Y %H:%M:%S'`
  echo DB2#$STARTED#`date '+%d/%m/%Y %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#OFFLINE#$STATUS#$scriptName##" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
  if [[ $machine == "192.168.1.1" ]]; then
    SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
    echo `date` 'Backup Status File Copied' $SCP_RESULT
  else
    SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
    echo `date` 'Backup Status File Copied' $SCP_RESULT
  fi

##############################################################################
# Connect to Database                                                        #
##############################################################################
  echo `date` "*--- Connect to DB ---*" >>$OUTPUT_FILE
  MSG0=`db2 connect to $DB`
  RC0=$(echo $MSG0 | cut -c1-8)
  if [[ $RC0 != "Database" ]]
   then
    echo " DB2 Connect failed " >>$OUTPUT_FILE
    echo " Message: $MSG0 " >>$OUTPUT_FILE
    let SEND_EMAIL=1
    STATUS='Failed at connect'
    MSG=$MSG0
  else
    echo " DB2 Connect successful " >>$OUTPUT_FILE
############################################################################
# QUIESCE Database for exclusive use                                       #
############################################################################
    echo `date` "*--- Quiesce Database ---*" >>$OUTPUT_FILE
    MSG1=`db2 quiesce db immediate force connections`
    RC1=$(echo $MSG1 | cut -c1-8)
    if [[ $RC1 != "DB20000I" ]]
    then
     echo " DB2 Quiesce failed with RC = $RC1 " >>$OUTPUT_FILE
     echo " Message: $MSG1 " >>$OUTPUT_FILE
     let SEND_EMAIL=1
     STATUS='Failed at quiesce'
     MSG=$MSG1
    else
     echo " DB2 Quiesce successful " >>$OUTPUT_FILE
     let DO_UNQSCE_FLAG=1
############################################################################
# Reset the Connection                                                     #
############################################################################
     echo `date` "*--- Reset the connection ----*" >>$OUTPUT_FILE
     MSG2=`db2 connect reset`
     RC2=$(echo $MSG2 | cut -c1-8)
     if [[ $RC2 != "DB20000I" ]]
     then
      echo " DB2 Connect reset failed with RC = $RC2 " >>$OUTPUT_FILE
      echo " Message: $MSG2 " >>$OUTPUT_FILE
      let SEND_EMAIL=1
      STATUS='Failed at reset'
      MSG=$MSG2
     else
      echo " DB2 Connect reset successful " >>$OUTPUT_FILE
############################################################################
# Perform backup.                                                          #
############################################################################
      echo `date` "*-- Backup the database --*" >>$OUTPUT_FILE
      BACKUPCMD="db2 backup database $DB load $LOAD"
      echo DB2#$STARTED#`date '+%d/%m/%Y %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#OFFLINE#$STATUS#$scriptName#$BACKUPCMD#" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
      if [[ $machine == "192.168.1.1" ]]; then
        SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
        echo `date` 'Backup Status File Copied' $SCP_RESULT
      else
        SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
        echo `date` 'Backup Status File Copied' $SCP_RESULT
      fi

      MSG3=`db2 backup database $DB load $LOAD`
      RC3=$(echo $MSG3 | cut -c1-8)
      if [[ $RC3 != "Backup s" ]]
      then
       echo " Backup of $DB failed with RC= $RC3" >>$OUTPUT_FILE
       echo " Message: $MSG3 " >>$OUTPUT_FILE
       let SEND_EMAIL=1
       STATUS='Failed'
       MSG=$MSG3
      else
       echo " Backup of $DB successful " >>$OUTPUT_FILE
       echo `date` $machine $DB2INSTANCE $DB $MSG3 >$OUTPUT_LOG
       SEND_FILE=1;
       STATUS='Success'
       MSG=''
############################################################################
# Connect to Database                                                      #
############################################################################
       echo `date` "*--- Connect to DB ---*" >>$OUTPUT_FILE
       MSG4=`db2 connect to $DB`
       RC4=$(echo $MSG4 | cut -c1-8)
       if [[ $RC4 != "Database" ]]
       then
        echo " DB2 Connect failed " >>$OUTPUT_FILE
        echo " Message: $MSG4 " >>$OUTPUT_FILE
        let SEND_EMAIL=1
        STATUS='Successful but DB quiesced'
        MSG=$MSG4
       else
        echo " DB2 Connect successful " >>$OUTPUT_FILE
############################################################################
# UNQUIESCE database to restore user access.                               #
############################################################################
        echo `date` "*--- Unquiesce database ---*" >>$OUTPUT_FILE
        MSG5=`db2 unquiesce db `
        RC5=$(echo $MSG5 | cut -c1-8)
        if [[ $RC5 != "DB20000I" ]]
        then
         echo " DB2 Unquiesce failed with RC = $RC5" >>$OUTPUT_FILE
         echo " Message: $MSG5 " >>$OUTPUT_FILE
         let SEND_EMAIL=1
         STATUS='Successful but DB quiesced'
         MSG=$MSG5
        else
         echo " DB2 Unquiesce successful " >>$OUTPUT_FILE
         let DO_UNQSCE_FLAG=0
############################################################################
# Reset the Connection                                                     #
############################################################################
         echo `date` "*--- Reset the connection ----*" >>$OUTPUT_FILE
         MSG6=`db2 connect reset`
         RC6=$(echo $MSG6 | cut -c1-8)
         if [[ $RC6 != "DB20000I" ]]
         then
          echo " DB2 Connect reset failed with RC = $RC6 " >>$OUTPUT_FILE
          echo " Message: $MSG6 " >>$OUTPUT_FILE
          let SEND_EMAIL=1
          STATUS='Successful but warnings'
          MSG=$MSG5
         else
          echo " DB2 Connect reset successful " >>$OUTPUT_FILE
         fi
        fi
       fi
      fi
     fi
    fi
  fi
done
############################################################################
# This loop gets executed if an error is encountered before UNQUIESCEing   #
# the database during the execution of the above code.                     #
############################################################################
# Connect to Database                                                      #
############################################################################
if [[ $DO_UNQSCE_FLAG != 0 ]]
  then
  echo `date` "*--- Connect to DB for UNQUIESCE due to failure---*" >>$OUTPUT_FILE
  MSG7=`db2 connect to $DB`
  RC7=$(echo $MSG7 | cut -c1-8)
  if [[ $RC7 != "Database" ]]
  then
    echo " DB2 Connect failed " >>$OUTPUT_FILE
    echo " Message: $MSG7 " >>$OUTPUT_FILE
    let SEND_EMAIL=1
    STATUS='Successful but DB Quiesced'
    MSG=$MSG5
  else
    echo " DB2 Connect successful " >>$OUTPUT_FILE
############################################################################
# UNQUIESCE database to restore user access .                              #
############################################################################
    echo `date` "*--- Unquiesce database ---*" >>$OUTPUT_FILE
    MSG8=`db2 unquiesce db `
    RC8=$(echo $MSG8 | cut -c1-8)
    if [[ $RC8 != "DB20000I" ]]
    then
      echo " DB2 Unquiesce failed with RC = $RC8" >>$OUTPUT_FILE
      echo " Message: $MSG8 " >>$OUTPUT_FILE
      let SEND_EMAIL=1
      STATUS='Successful but DB Quiesced'
      MSG=$MSG5
    else
      echo " DB2 Unquiesce successful " >>$OUTPUT_FILE
############################################################################
# Reset the Connection                                                     #
############################################################################
      echo `date` "*--- Reset the connection ----*" >>$OUTPUT_FILE
      MSG9=`db2 connect reset`
      RC9=$(echo $MSG9 | cut -c1-8)
      if [[ $RC9 != "DB20000I" ]]
      then
        echo " DB2 Connect reset failed with RC = $RC9 " >>$OUTPUT_FILE
        echo " Message: $MSG9 " >>$OUTPUT_FILE
        let SEND_EMAIL=1
        STATUS='Successful but warnings'
        MSG=$MSG5
      else
        echo " DB2 Connect reset successful " >>$OUTPUT_FILE
      fi
    fi
  fi
fi
RC=0
if [[ $SEND_EMAIL != 0 ]]; then
  cat $OUTPUT_FILE  | mailx -s"Offline backup of $DB" DEFAULT_EMAIL@KAGJCM.com.au 
  RC=8
fi

if [[ $SEND_FILE != 0 ]]; then
  SCP_RESULT=`scp $OUTPUT_LOG db2admin@192.168.1.1:LatestBackups`
  echo $SCP_RESULT >>$OUTPUT_FILE
fi

echo DB2#$STARTED#`date '+%d/%m/%Y %H:%M:%S'`"#$machine#$DB2INSTANCE#$database#OFFLINE#$STATUS#$scriptName#$BACKUPCMD#$MSG" >/tmp/backup_status_${machine}_${DB2INSTANCE}_$database
if [[ $machine == "192.168.1.1" ]]; then
  SCP_RESULT=`cp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
else
  SCP_RESULT=`scp /tmp/backup_status_${machine}_${DB2INSTANCE}_$database db2admin@192.168.1.1:realtimeBackupStatus`
  echo `date` 'Backup Status File Copied' $SCP_RESULT
fi

exit $RC
