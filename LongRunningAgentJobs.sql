/*This function is used to convert the sysjobs.jobid field into the processid that will show up in
sysprocesses.program_name field for an executing job.
*/

IF OBJECT_ID('dbo.udf_SysJobs_GetProcessid') IS NULL
 EXEC('
 
	CREATE FUNCTION dbo.udf_SysJobs_GetProcessid(@job_id uniqueidentifier)
	RETURNS VARCHAR(8)
	AS
	BEGIN
	RETURN (substring(left(@job_id,8),7,2) +
			substring(left(@job_id,8),5,2) +
			substring(left(@job_id,8),3,2) +
			substring(left(@job_id,8),1,2))
	END	
 ')
/* TSQL Code to Find Jobs Running Over x Minutes

The following code will return a row for each job that is currently running and has been running for
over the number of minutes set in the @MaxMinutes variable. To adjust the time frame it looks for,
just change this variable value.
*/
 
DECLARE @MaxMinutes int
SET @MaxMinutes = 1
 
SELECT	p.spid, 
	j.name, 
	p.program_name, 
	isnull(DATEDIFF(mi, p.last_batch, getdate()), 0) [MinutesRunning], 
	last_batch
FROM master..sysprocesses p
JOIN msdb..sysjobs j ON dbo.udf_sysjobs_getprocessid(j.job_id) = substring(p.program_name,32,8)
WHERE program_name like 'SQLAgent - TSQL JobStep (Job %'
  AND isnull(DATEDIFF(mi, p.last_batch, getdate()), 0) > @MaxMinutes
 


/*
For additional information please see:

Refer to sp_help_job in Books Online
http://msdn2.microsoft.com/en-us/library/ms186722.aspx
*/