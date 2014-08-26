/* Create Trace and Login history table in DBA database. Create Proc to periodically pull from trace to summarized login table. Then Create the job that runs
the proc.
Created by Dave Bennett
Last Modified: 9/28/2012
Relies on: Database: DBA
!!!!NOTE: The folder: D:\Logging needs to be created before running this script.!!!!
*/

/*Create Login History Trace*/
 --Use the master database 
USE master
go 

declare @tracestarttime datetime 
declare @traceident int 
declare @options int 
declare @filename nvarchar(245) 
declare @filesize bigint 
declare @tracestoptime datetime 
declare @createcode int 
declare @on bit 
declare @startcode INT
DECLARE @path NVARCHAR(245)  

set @tracestarttime = current_timestamp 

/* Set the name of the trace file. */ 

set @filename = 'LoginTrace' 
SET @path = 'D:\Logging'
set @options = 2 
set @filename = @path + N'\' + @filename 
set @filesize = 20 
set @on = 1 

--set up the trace 

exec @createcode = sp_trace_create  @traceid = @traceident output,  @options = @options,  
 @tracefile = @filename,   @maxfilesize = @filesize 
if @createcode = 0 
--trace created 
 begin 
 --set events and columns 

 --Trace Login event 
exec sp_trace_setevent @traceident, 14, 1, @on 
exec sp_trace_setevent @traceident, 14, 6, @on 
exec sp_trace_setevent @traceident, 14, 7, @on 
exec sp_trace_setevent @traceident, 14, 8, @on 
exec sp_trace_setevent @traceident, 14, 9, @on 
exec sp_trace_setevent @traceident, 14, 10, @on 
exec sp_trace_setevent @traceident, 14, 11, @on 
exec sp_trace_setevent @traceident, 14, 12, @on 
exec sp_trace_setevent @traceident, 14, 14, @on 
exec sp_trace_setevent @traceident, 14, 18, @on 
exec sp_trace_setevent @traceident, 14, 34, @on 
exec sp_trace_setevent @traceident, 14, 35, @on

 --filter Profiler 
 exec sp_trace_setfilter   @traceid = @traceident,   @columid = 10,    @logical_operator = 0,   @comparison_operator = 7, @value = N'SQL Profiler' 

 --start the trace 
 exec @startcode = sp_trace_setstatus  @traceid = @traceident,  @status = 1 

 if @startcode = 0 
 begin 
  select 'Trace started at ' +   cast(@tracestarttime as varchar) +  ' trace id is ' +     cast(@traceident as nvarchar) +     '.'   
  end
 else
  begin
  goto Error
  end
 end
else
 begin
 goto Error
 end

return

Error:
 select 'Error starting trace.'
 return
GO

/* Create Login history table*/
CREATE TABLE dba.dbo.LoginHist (
LoginHistId BIGINT IDENTITY PRIMARY KEY,
	NTDomainName VARCHAR(50)
     ,NTUserName VARCHAR(50)
     ,HostName VARCHAR(50)
     ,ApplicationName VARCHAR(255)
     ,LoginName VARCHAR(50)
    
     ,ServerName VARCHAR(50)
     ,DatabaseName VARCHAR(50)
     , LatestLogin datetime
     , EarliestLogin datetime
     , NumLogins int
)
GO
USE DBA
go
/* Create History Table Load proc */
CREATE PROCEDURE dbo.LoadLatestLoginInfo
	

AS
/**************************************************************************************
* Description: Load data from the login trace into a summarized login history table
* Author: Dave Bennett
* Created: 9/28/2012
* Last Updated: 9/28/2012 
* Relies on: Login Trace (trace id = 2), DBA.LoginHist
* Modifies: DBA.LoginHist
* Parameters: n/a
* Example: Exec LoadLatestLoginInfo
***************************************************************************************/
BEGIN
  SET NOCOUNT ON
  SELECT t.TextData
     ,t.NTDomainName
     ,t.NTUserName
     ,t.DBUserName
     ,t.HostName
     ,t.ApplicationName
     ,t.LoginName
     ,t.StartTime
     ,t.ServerName
     ,t.DatabaseName
     ,t.SessionLoginName
     ,te.trace_event_id
     ,te.name
   INTO #LogData
   FROM sys.fn_trace_gettable(CONVERT(VARCHAR(150), ( SELECT TOP 1 f.[value]
                                                         FROM sys.fn_trace_getinfo(NULL) f
                                                         WHERE f.property = 2
                                                            AND f.traceid = 2
                                                    )), DEFAULT) T 
      JOIN sys.trace_events TE
      ON T.EventClass = TE.trace_event_id
   WHERE te.category_id = 8
      AND te.trace_event_id = 14
        
INSERT INTO dba.dbo.LoginHist
SELECT 
     NTDomainName
     ,NTUserName
     ,HostName
     ,ApplicationName
     ,LoginName
     ,ServerName
     ,DatabaseName
     ,MAX(StartTime) LatestLogin
     ,MIN(StartTime) EarliestLogin
     ,COUNT(*) NumLogins    
FROM #LogData AS LD
WHERE (StartTime > (SELECT MAX(LatestLogin) FROM dba.dbo.LoginHist)) OR ((SELECT MAX(LatestLogin) FROM dba.dbo.LoginHist) is null)
GROUP BY NTDomainName, NTUserName, DatabaseName, HostName, ApplicationName, LoginName, ServerName

DROP TABLE #LogData
END
GO
/* Create Job to run Proc hourly */
USE [msdb]
GO

/****** Object:  Job [DBA_LoadLoginHist_Hourly]    Script Date: 09/28/2012 12:04:00 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 09/28/2012 12:04:00 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA_LoadLoginHist_Hourly', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Load History]    Script Date: 09/28/2012 12:04:00 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load History', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec LoadLatestLoginInfo', 
		@database_name=N'DBA', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20120928, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

/* Reporting Section*/
SELECT  
     NTDomainName
     ,NTUserName
     ,HostName
     ,ApplicationName
     ,LoginName
     ,ServerName
     ,DatabaseName
     ,MAX(LatestLogin) LatestLogin
     ,MIN(EarliestLogin) EarliestLogin
     ,SUM(NumLogins) NumLogins 
     FROM dba.dbo.loginhist
     GROUP BY NTDomainName, NTUserName, DatabaseName, HostName, ApplicationName, LoginName, ServerName
     ORDER BY LoginName, DatabaseName
/* End Reporting Section*/