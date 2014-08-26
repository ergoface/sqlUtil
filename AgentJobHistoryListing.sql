/******************************************************************************
* Routine to display sql Agent job history of non-reporting services scheduled jobs.
* Works for ver 2000-2008R2
* Author: Dave Bennett
* Last Modified: 8/3/2011
*
*******************************************************************************/
SELECT job_name
     ,run_datetime
     ,run_duration
     ,CASE WHEN run_status = 1 THEN 'Succeeded'
           ELSE 'Failed'
      END RunStatus
   FROM ( SELECT job_name
              ,Description
              ,run_status
              ,DATEADD(hh, -7, run_datetime) AS run_datetime
              ,SUBSTRING(run_duration, 1, 2) + ':' + SUBSTRING(run_duration, 3,
                                                              2) + ':'
               + SUBSTRING(run_duration, 5, 2) AS run_duration
            FROM ( SELECT j.name AS job_name
                       ,j.DESCRIPTION
                       ,run_datetime = CONVERT(DATETIME, RTRIM(run_date))
                        + ( run_time * 9 + run_time % 10000 * 6 + run_time
                            % 100 * 10 ) / 216e4
                       ,run_duration = RIGHT('000000'
                                             + CONVERT(VARCHAR(6), run_duration),
                                             6)
                       ,run_status
                     FROM msdb..sysjobhistory h 
                        INNER JOIN msdb..sysjobs j
                        ON h.job_id = j.job_id
                     WHERE run_date > '20110130'
                 ) t
        ) t
   WHERE run_datetime > '01/30/2011 00:00'
      AND Description NOT LIKE 'This job is owned by a report server process.%'
   ORDER BY run_datetime