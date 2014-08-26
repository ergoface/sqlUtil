/***********************************************************************************************************************
* Description: Find all jobs that are not owned by 'SA' on and instance. Part II: Create script to change all jobs to 
*               'SA' ownership.
* Created by: Dave Bennett (based in part on an MSSQLTips.com tip in conjunction with comments and other sources).
* Last Modified: 5/13/2014
* Modifies: MSDB..sysjobs table
*
************************************************************************************************************************/
/* Part I discover all sql agent jobs not owned by SA */
SELECT suser_sname(owner_sid) Owner, [name] JobName
FROM MSDB.dbo.sysjobs j
WHERE suser_sname(owner_sid) NOT IN('sa','distributor_admin','##MS_SSISServerCleanupJobLogin##','CORP\A1CEN3AppDevSQL7')  OR suser_sname(owner_sid) IS NULL
ORDER BY j.[name];

/* Part II Create script to change all sql agent jobs not owned by SA to SA.*/
DECLARE @SQL VARCHAR(MAX);
SET @SQL = ' '
SET NOCOUNT ON 
SELECT @SQL = @SQL + CHAR(13) + '/* Current login for: ' + j.name + CHAR(13) + 'Login: ' + suser_sname(owner_sid) + CHAR(13) + ' */' + CHAR(13) +
'EXEC MSDB.dbo.sp_update_job ' + char(13) +
'@job_name = ' + char(39) + j.[Name] + char(39) + ',' + char(13) +
'@owner_login_name = ' + char(39) + 'sa' + char(39) + char(13) + char(13)
FROM MSDB.dbo.sysjobs j
WHERE suser_sname(owner_sid) NOT IN('sa','distributor_admin','##MS_SSISServerCleanupJobLogin##','CORP\A1CEN3AppDevSQL7')  OR suser_sname(owner_sid) IS NULL
ORDER BY j.[name];
 
SELECT @SQL;
/* Copy the output of this query into a fresh query session on the same instance, review, then run. */