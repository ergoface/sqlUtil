
/* Show the latest  backup and type of backup of all databases on an instance*/
WITH BackupInfo AS (
SELECT db.name "DATABASE", 
case when MAX(b.backup_finish_date) is NULL then ' No Backup' else convert(varchar(100), 
	MAX(b.backup_finish_date)) end AS "Last Backup",
	MAX(b.backup_set_id) bsid,
	
	db.recovery_model_desc
FROM sys.databases db
LEFT OUTER JOIN msdb.dbo.backupset b ON db.name = b.database_name 
	WHERE db.database_id NOT IN (2) 
GROUP BY db.name, 
	     db.recovery_model_desc
)
SELECT BI.[DATABASE],bi."Last Backup"
, CASE WHEN b.type = 'L' THEN 'Log'
  WHEN b.type = 'D' THEN 'Full'
  ELSE '-' END BackupType

, bi.recovery_model_desc
FROM  BackupInfo BI
LEFT OUTER JOIN msdb.dbo.backupset AS B
ON b.backup_set_id = bi.bsid
ORDER BY b.backup_finish_date, 1