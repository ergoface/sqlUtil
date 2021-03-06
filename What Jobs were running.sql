USE msdb
GO
DECLARE @Check_Time DATETIME = '20150307 15:02:00'
/*** Find out what jobs were running at a given date and time on the server  ***/

SELECT [JobName] = JOB.name
     ,[Step] = HIST.step_id
     ,[StepName] = HIST.step_name
     ,[Message] = HIST.message
     ,[Status] = CASE WHEN HIST.run_status = 0 THEN 'Failed'
                      WHEN HIST.run_status = 1 THEN 'Succeeded'
                      WHEN HIST.run_status = 2 THEN 'Retry'
                      WHEN HIST.run_status = 3 THEN 'Canceled'
					  WHEN hist.run_status = 4 THEN 'Running'
				 ELSE CAST(HIST.run_status AS VARCHAR(5))
                 END
     
     ,(run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 ) DurationSeconds
     ,msdb.dbo.agent_datetime(HIST.run_date, hist.run_time) StartDateTime
     ,DATEADD(S,(run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 ),msdb.dbo.agent_datetime(HIST.run_date, hist.run_time)) EndDateTime
   FROM sysjobs JOB
      INNER JOIN sysjobhistory HIST
         ON HIST.job_id = JOB.job_id

/* WHERE    JOB.name = 'Job1' */
WHERE @Check_Time BETWEEN 
       msdb.dbo.agent_datetime(HIST.run_date, hist.run_time) 
       AND
       DATEADD(S,(run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 ),msdb.dbo.agent_datetime(HIST.run_date, hist.run_time))
	   AND (HIST.run_status IS NOT NULL AND	 HIST.run_status <> 4) /* Eliminate jobs that run continually */
   ORDER BY Job.name, HIST.run_date
     ,HIST.run_time , step_id