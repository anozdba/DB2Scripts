-- --------------------------------------------------------------------
-- activeApplications.sql
--
-- $Id: activeApplications_V10.sql,v 1.1 2017/04/04 02:25:29 db2admin Exp db2admin $
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
-- $Log: activeApplications_V10.sql,v $
-- Revision 1.1  2017/04/04 02:25:29  db2admin
-- Initial revision
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
       i.APPL_STATUS as APPLICATION_STATUS 
  from sysibmadm.SNAPAPPL_INFO as i, 
       sysibmadm.snapappl x join 
       sysibmadm.snapstmt y 
         on x.agent_id = y.agent_id 
  where x.uow_stop_time is null 
    and APPL_IDLE_TIME < 1
    and i.agent_id = x.agent_id
    and y.stmt_text is not null
;
