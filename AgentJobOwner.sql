/*
  Created by Solihin Ho - http://solihinho.wordpress.com


*/

DECLARE @sql VARCHAR(8000)

SET @sql = '
SELECT
  j.Name AS JobName
, c.Name AS Category
, CASE j.enabled WHEN 1 THEN ''Yes'' else ''No'' END as Enabled
, CASE s.enabled WHEN 1 THEN ''Yes'' else ''No'' END as Scheduled
, j.Description
, CASE s.freq_type
     WHEN  1 THEN ''Once''
     WHEN  4 THEN ''Daily''
     WHEN  8 THEN ''Weekly''
     WHEN 16 THEN ''Monthly''
     WHEN 32 THEN ''Monthly relative''
     WHEN 64 THEN ''When SQL Server Agent starts''
     WHEN 128 THEN ''Start whenever the CPU(s) become idle'' END as Occurs
, CASE s.freq_type
     WHEN  1 THEN ''O''
     WHEN  4 THEN ''Every ''
        + convert(varchar,s.freq_interval)
        + '' day(s)''
     WHEN  8 THEN ''Every ''
        + convert(varchar,s.freq_recurrence_factor)
        + '' weeks(s) on ''
        + master.dbo.fn_freq_interval_desc(s.freq_interval)
     WHEN 16 THEN ''Day '' + convert(varchar,s.freq_interval)
        + '' of every ''
        + convert(varchar,s.freq_recurrence_factor)
        + '' month(s)''
     WHEN 32 THEN ''The ''
        + CASE s.freq_relative_interval
            WHEN  1 THEN ''First''
            WHEN  2 THEN ''Second''
            WHEN  4 THEN ''Third''
            WHEN  8 THEN ''Fourth''
            WHEN 16 THEN ''Last'' END
        + CASE s.freq_interval
            WHEN  1 THEN '' Sunday''
            WHEN  2 THEN '' Monday''
            WHEN  3 THEN '' Tuesday''
            WHEN  4 THEN '' Wednesday''
            WHEN  5 THEN '' Thursday''
            WHEN  6 THEN '' Friday''
            WHEN  7 THEN '' Saturday''
            WHEN  8 THEN '' Day''
            WHEN  9 THEN '' Weekday''
            WHEN 10 THEN '' Weekend Day'' END
        + '' of every ''
        + convert(varchar,s.freq_recurrence_factor)
        + '' month(s)'' END AS Occurs_detail
, CASE s.freq_subday_type
     WHEN 1 THEN ''Occurs once at ''
        + master.dbo.fn_Time2Str(s.active_start_time)
     WHEN 2 THEN ''Occurs every ''
        + convert(varchar,s.freq_subday_interval)
        + '' Seconds(s) Starting at ''
        + master.dbo.fn_Time2Str(s.active_start_time)
        + '' ending at ''
        + master.dbo.fn_Time2Str(s.active_end_time)
     WHEN 4 THEN ''Occurs every ''
        + convert(varchar,s.freq_subday_interval)
        + '' Minute(s) Starting at ''
        + master.dbo.fn_Time2Str(s.active_start_time)
        + '' ending at ''
        + master.dbo.fn_Time2Str(s.active_end_time)
     WHEN 8 THEN ''Occurs every ''
        + convert(varchar,s.freq_subday_interval)
        + '' Hour(s) Starting at ''
        + master.dbo.fn_Time2Str(s.active_start_time)
        + '' ending at ''
        + master.dbo.fn_Time2Str(s.active_end_time) END AS Frequency
, CASE WHEN s.freq_type =  1 THEN ''On date: ''
          + master.dbo.fn_Date2Str(s.active_start_date)
          + '' At time: ''
          + master.dbo.fn_Time2Str(s.active_start_time)
       WHEN s.freq_type < 64 THEN ''Start date: ''
          + master.dbo.fn_Date2Str(s.active_start_date)
          + '' end date: ''
          + master.dbo.fn_Date2Str(s.active_end_date) END as Duration

FROM  msdb.dbo.sysjobs j (NOLOCK)
INNER JOIN msdb.dbo.sysjobschedules js (NOLOCK) ON j.job_id = js.job_id
INNER JOIN msdb.dbo.sysschedules s (NOLOCK) ON js.schedule_id = s.schedule_id
INNER JOIN msdb.dbo.syscategories c (NOLOCK) ON j.category_id = c.category_id
ORDER BY j.name'



EXEC(@sql)