-- --------------------------------------------------------------------
-- activeApplications.sql
--
-- $Id: activeApplications.sql,v 1.4 2017/04/04 02:29:38 db2admin Exp db2admin $
--
-- Description:
-- List Aapplications and their status
--
-- Usage:
--   activeApplications.sql
--
-- $Name:  $
--
-- ChangeLog:
-- $Log: activeApplications.sql,v $
-- Revision 1.4  2017/04/04 02:29:38  db2admin
-- change SNAP_GET_APPL_INFO to SNAPSHOT_APPL_INFO
--
-- Revision 1.2  2017/03/28 22:16:54  db2admin
-- add in statement start time
--
-- Revision 1.1  2017/03/28 22:14:01  db2admin
-- Initial revision
--
--
-- --------------------------------------------------------------------

select cast(substr(tpmon_client_wkstn,1,20)as varchar(20)) as wkstn , 
       substr(x.agent_id,1,8) as Agent,
       appl_con_time "Application Connect",
       stmt_start "Statement Start",
       substr((( (UOW_ELAPSED_TIME_S * 1000000 + UOW_ELAPSED_TIME_MS) / 1000000) / 1000.00 ),1,6) as Elapsed, 
       cast(substr(y.stmt_text,1,100) as varchar(100)) as "SQL",
       case i.APPL_STATUS
         when 1 then 'Connect Pending'
         when 2 then 'Connect Completed'
         when 3 then 'Unit of Work Executing'
         when 4 then 'Unit of Work waiting'
         when 5 then 'Lock Wait'
         when 6 then 'Commit Active'
         when 7 then 'Rollback Active'
         when 8 then 'Recompiling'
         when 9 then 'Compiling'
         when 10 then 'Request Interrupted'
         when 11 then 'Disconnect Pending'
         when 12 then 'Transaction Prepared'
         when 13 then 'Heuristically Committed'
         when 14 then 'Heuristically Rolled Back'
         when 15 then 'Transaction Ended'
         when 16 then 'Creating Database'
         when 17 then 'Restarting Database'
         when 18 then 'Restoring Database'
         when 19 then 'Backing Up Database'
         when 20 then 'Data Fast Load'
         when 21 then 'Data Fast Unload – EXPORT'
         when 22 then 'Wait to Disable Table space '
         when 23 then 'Quiescing a Table space'
         when 24 then 'Wait for Remote Partition'
         when 25 then 'Remote Request Pending'
       else
         'Rollback to savepoint'
       end as APPLICATION_STATUS 
  from table(SNAPSHOT_APPL_INFO('',-1)) as i, 
       sysibmadm.snapappl x join 
       sysibmadm.snapstmt y 
         on x.agent_id = y.agent_id 
  where x.uow_stop_time is null 
    and APPL_IDLE_TIME < 1 
    and i.agent_id = x.agent_id
    and y.stmt_text is not null
;
