
/* Show the latest full backup of all databases on an instance*/

SELECT db.name "DATABASE", 
case when MAX(b.backup_finish_date) is NULL then ' No Backup' else convert(varchar(100), 
	MAX(b.backup_finish_date)) end AS "Last Full Backup",
	db.recovery_model_desc
FROM sys.databases db
LEFT OUTER JOIN msdb.dbo.backupset b ON db.name = b.database_name AND b.type = 'D'
	WHERE db.database_id NOT IN (2) 
GROUP BY db.name, db.recovery_model_desc
ORDER BY 2, 1