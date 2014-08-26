/****** Manual Reindex and update statistics for all tables in a database *********/
USE <DATABASE>
go	
EXEC sp_MSforeachtable @command1="print '?' DBCC DBREINDEX ('?', ' ', 80)"
GO
EXEC sp_updatestats
GO 