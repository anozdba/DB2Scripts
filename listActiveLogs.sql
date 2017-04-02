-- --------------------------------------------------------------------
-- listActiveLogs.sql
--
-- $Id: listActiveLogs.sql,v 1.2 2017/03/30 23:16:29 db2admin Exp db2admin $
--
-- Description:
-- List Active Logs
--
-- Usage:
--   listActiveLogs.sql
--
-- $Name:  $
--
-- ChangeLog:
-- $Log: listActiveLogs.sql,v $
-- Revision 1.2  2017/03/30 23:16:29  db2admin
-- change the literal tag to be unique in the data stream
--
-- Revision 1.1  2017/03/28 22:13:01  db2admin
-- Initial revision
--
--
-- --------------------------------------------------------------------

connect to %%DATABASE%% 
;

Select 'DataHere', MEMBER, CUR_COMMIT_DISK_LOG_READS, CURRENT_ACTIVE_LOG, APPLID_HOLDING_OLDEST_XACT 
  from table(mon_get_transaction_log(-1)) as t 
  order by member asc
;
