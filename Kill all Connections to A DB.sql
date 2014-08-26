/* Create Proc that will kill all connections to a given database.
Written by Richard Lu on SQL Server Central 
http://www.sqlservercentral.com/scripts/Administration/72287/
*/
Create Proc [dbo].[usp_killConnections] 
@db_name Nvarchar(200)
AS
 set nocount on
 -- Verify database name
 if db_id(@db_name) is null 
 return
 
 declare @spid int
 declare spid cursor for
 
/* For SQL 2000 and SQL 2005/2008 Backward compatible mode*/
 select spid from master.dbo.sysprocesses(nolock) where dbid = db_id(@db_name) and spid > 50
 union
 select distinct req_spid from sys.syslockinfo(nolock) where rsc_dbid = db_id(@db_name) and req_spid > 50

/* For SQL 2005/2008 */
/*
 select spid from master.dbo.sysprocesses(nolock) where dbid = db_id(@db_name) and spid > 50
 union
 select distinct request_session_id from sys.dm_tran_locks (nolock) where resource_database_id = db_id(@db_name) and request_session_id > 50
*/
 open spid
 fetch next from spid
 into @spid
 
 while @@fetch_status = 0
 begin
 exec ('kill ' + @spid)
 fetch next from spid into @spid
 end
 
 close spid
 deallocate spid



