
/* Show all databases that have never been backed up on an instance*/
SELECT db.name "DATABASE", 
case when b.backup_finish_date is NULL then ' No Backup' else convert(varchar(100), 
	b.backup_finish_date) end AS "Last Backup",
	db.recovery_model_desc
	
FROM sys.databases db
LEFT OUTER JOIN msdb.dbo.backupset b ON db.name = b.database_name 
	WHERE db.database_id NOT IN (2) 
	AND b.backup_finish_date is NULL

