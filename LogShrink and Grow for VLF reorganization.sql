/******Log file shrink and grow routine to fix VLF structure on your log file
 Change DB name and file to appropriate db. If In Full or Bulk_Logged mode, do a log backup. This is currently configured for Simple
******/

USE ReportServerTempDB
GO
DBCC CHECKDB
CHECKPOINT

DBCC SHRINKFILE('ReportServerTempDB_log', TRUNCATEONLY) 
SELECT size / 128 SizeInMeg,* FROM sys.database_files AS DF
DBCC loginfo
ALTER DATABASE ReportServerTempDB
MODIFY FILE
( NAME = 'ReportServerTempDB_log'
  , SIZE = 480
)