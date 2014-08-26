/* Create All structures and procedures for the DBInfo */
USE [master]
GO
/* First create the DBA database if it doesn't exist*/
IF DB_ID('DBA') IS NULL
CREATE DATABASE [DBA] ;
GO
USE [DBA]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
/* Create the DBinfo table if is doesn't exist*/
IF OBJECT_ID('DBinfo','U') IS NULL
  BEGIN
CREATE TABLE [dbo].[DBinfo](
	[DBinfoId] [int] IDENTITY(1,1) NOT NULL,
	[Instance] [varchar](100) NOT NULL,
	[Database] [varchar](100) NOT NULL,
	[SnapshotDate] [date] NOT NULL,
	[RecoveryMode] [varchar](20) NULL,
	[DBFileSizeInMB] [bigint] NULL,
	[LogFileSizeInMB] [bigint] NULL,
	[LastFullBackup] [datetime] NULL,
	[DBSpaceAvailInMB] [int] NULL,
	[LogSpaceAvailInMB] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[DBinfoId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[DBinfo] ADD  DEFAULT (getdate()) FOR [SnapshotDate]
END
GO
/* Create the GenInstanceInfo Proc to gather all the database information */
IF object_id('GenInstanceDBInfo','U') IS NOT NULL
    DROP PROC GenInstanceDBInfo;
GO    
CREATE PROCEDURE [dbo].[GenInstanceDBInfo]
	
AS
/**************************************************************************************
* Description: Generate Information used to compile DB growth database
* Author: Dave Bennett
* Created: 8/22/2012
* Last Updated: 8/30/2012 - fixed calculation error
* Relies on: sp_MSforeachdb
* Modifies: Nothing
* Parameters: None
* Example: Exec GenInstanceDBInfo
***************************************************************************************/
BEGIN
  SET NOCOUNT ON
EXEC sp_MSforeachdb '
		USE [?];

		SELECT	  cast(SERVERPROPERTY(''machineName'') as varchar(100)) + ''\'' + isnull(cast(SERVERPROPERTY(''InstanceName'') as Varchar(100)),''Default'') as Instance
		  ,	Cast(DB_NAME() as varchar(100)) As DBNAME
		  , MAX(cast((d.recovery_model_desc) as varchar(100))) Recovery_Model
		  , SUM(Case when type_desc = ''ROWS'' THEN size / 128 END) AS ''Total Size in MB''
		  , SUM(Case when type_desc = ''ROWS'' THEN size / 128 - CAST(FILEPROPERTY(f.name , ''SpaceUsed'') AS int) / 128 END) AS ''Available Space In MB''
		  , SUM(Case when type_desc = ''LOG'' THEN size / 128 END) AS ''Log Size in MB''
		  , SUM(Case when type_desc = ''LOG'' THEN size / 128 - CAST(FILEPROPERTY(f.name , ''SpaceUsed'') AS int) / 128 END) AS ''Available Log Space In MB'' 
		 , MAX(b.LastFullBackup) LastFullBackup 
		 --, LEFT(physical_name, 1) AS DriveLetter
		FROM
			[?].sys.database_files f
			inner join sys.databases d
			  on (d.database_id = db_ID())
			CROSS join (
					SELECT  Max(backup_finish_date) LastFullBackup from msdb.dbo.backupset
					WHERE type = ''D'' AND database_name = db_NAME()) b
		'
END
GO
/* Create the LoadDBInfo Proc to be used in the Agent Job */
IF object_id('LoadDBInfo','U') IS NOT NULL
    DROP PROC LoadDBInfo;
GO

CREATE PROCEDURE dbo.LoadDBInfo
AS
/**************************************************************************************
* Description: Load Current day's DBInfo into the DBInfo table
* Author: Dave Bennett
* Created: 8/24/2012
* Last Updated: 8/24/2012 
* Relies on: GenInstanceDBInfo
* Modifies: Table: DBInfo
* Parameters: None
* Example: EXEC dbo.LoadDBInfo
***************************************************************************************/
BEGIN
  SET NOCOUNT ON
	IF EXISTS(SELECT  SnapshotDate FROM dbo.DBinfo AS DB WHERE SnapshotDate =  CAST(GETDATE() AS DATE))
		DELETE FROM dbo.DBinfo WHERE SnapshotDate = CAST(GETDATE() AS DATE)
		
	INSERT INTO dbo.DBinfo
      ( Instance
      ,[Database]
      ,RecoveryMode
      ,DBFileSizeInMB
      ,DBSpaceAvailInMB
      ,LogFileSizeInMB
      ,LogSpaceAvailInMB
      ,LastFullBackup   
      )
    Exec dba.dbo.GenInstanceDBInfo
END
GO
/* Create the Agent Job to Load the information daily */
USE [msdb]
GO
DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'DailyDBInfoLoad', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'Daily Load of DBInfo data', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
select @jobId
GO
EXEC msdb.dbo.sp_add_jobserver @job_name=N'DailyDBInfoLoad', @server_name = N'(local)'
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'DailyDBInfoLoad', @step_name=N'LoadData', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec dbo.LoadDBInfo', 
		@database_name=N'DBA', 
		@flags=0
GO
EXEC msdb.dbo.sp_update_job @job_name=N'DailyDBInfoLoad', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'Daily Load of DBInfo data', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO
DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'DailyDBInfoLoad', @name=N'Daily 7:05AM', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20120824, 
		@active_end_date=99991231, 
		@active_start_time=70500, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
select @schedule_id
GO






