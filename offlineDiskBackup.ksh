#!/bin/ksh
# --------------------------------------------------------------------
# offlineDiskBackup.ksh
#
# $Id: offlineDiskBackup.ksh,v 1.3 2009/04/29 00:54:20 db2admin Exp db2admin $
#
# Description:
# Offline Disk Backup script for Unix
#
# Usage:
#   offlineDiskBackup.ksh
#
# $Name:  $
#
# ChangeLog:
# $Log: offlineDiskBackup.ksh,v $
# Revision 1.3  2009/04/29 00:54:20  db2admin
# Add in generation of Return code
#
# Revision 1.2  2009/04/16 08:34:37  db2admin
# Correct a spelling mistake in the backup command
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
  LCN="/db2/backup/$1"
else
  LCN="$2/$1"
fi

DO_UNQSCE_FLAG=0;
SEND_EMAIL=0;
DBS="$1";
for DB in $DBS;
do
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
  if [ -f ~/.profile ]; then
    . ~/.profile
  fi
  OUTPUT_FILE="logs/offlineDiskBackup_$DB.log";
  echo "Subject: Offline Backup for $DB" >$OUTPUT_FILE
  echo `date` "**** Start: Offline Backup of $DB ****" >>$OUTPUT_FILE
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
     else
      echo " DB2 Connect reset successful " >>$OUTPUT_FILE
############################################################################
# Perform backup.                                                          #
############################################################################
      echo `date` "*-- Backup the database to $LCN --*" >>$OUTPUT_FILE
      MSG3=`db2 backup database $DB to $LCN COMPRESS`
      RC3=$(echo $MSG3 | cut -c1-8)
      if [[ $RC3 != "Backup s" ]]
      then
       echo " Backup of $DB failed with RC= $RC3" >>$OUTPUT_FILE
       echo " Message: $MSG3 " >>$OUTPUT_FILE
       let SEND_EMAIL=1
      else
       echo " Backup of $DB successful " >>$OUTPUT_FILE
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
      else
        echo " DB2 Connect reset successful " >>$OUTPUT_FILE
      fi
    fi
  fi
fi
RC=0
if [[ $SEND_EMAIL != 0 ]]; then
  cat $OUTPUT_FILE  | mailx -s"Offline backup of $DB" mpl_it_dba_udb@KAGJCM.com.au 
  RC=8
fi

echo $RC
