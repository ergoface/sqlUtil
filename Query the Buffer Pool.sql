/*Query the Buffer Pool to show what indexes are loaded
From: http://www.sqlservercentral.com/blogs/simple-sql-server/2016/01/04/query-the-buffer-pool/ */

IF OBJECT_ID('TempDB..#BufferSummary') IS NOT NULL BEGIN
	DROP TABLE #BufferSummary
END

IF OBJECT_ID('TempDB..#BufferPool') IS NOT NULL BEGIN
	DROP TABLE #BufferPool
END

CREATE TABLE #BufferPool
(
	Cached_MB Int
	, Database_Name SysName
	, Schema_Name SysName NULL
	, Object_Name SysName NULL
	, Index_ID Int NULL
	, Index_Name SysName NULL
	, Used_MB Int NULL
	, Used_InRow_MB Int NULL
	, Row_Count BigInt NULL
)

SELECT Pages = COUNT(1)
	, allocation_unit_id
	, database_id
INTO #BufferSummary
FROM sys.dm_os_buffer_descriptors 
GROUP BY allocation_unit_id, database_id 
	
DECLARE @DateAdded SmallDateTime  
SELECT @DateAdded = GETDATE()  
  
DECLARE @SQL NVarChar(4000)  
SELECT @SQL = ' USE [?]  
INSERT INTO #BufferPool (
	Cached_MB 
	, Database_Name 
	, Schema_Name 
	, Object_Name 
	, Index_ID 
	, Index_Name 
	, Used_MB 
	, Used_InRow_MB 
	, Row_Count 
	)  
SELECT sum(bd.Pages)/128 
	, DB_Name(bd.database_id)
	, Schema_Name(o.schema_id)
	, o.name
	, p.index_id 
	, ix.Name
	, i.Used_MB
	, i.Used_InRow_MB
	, i.Row_Count     
FROM #BufferSummary AS bd 
	LEFT JOIN sys.allocation_units au ON bd.allocation_unit_id = au.allocation_unit_id
	LEFT JOIN sys.partitions p ON (au.container_id = p.hobt_id AND au.type in (1,3)) OR (au.container_id = p.partition_id and au.type = 2)
	LEFT JOIN (
		SELECT PS.object_id
			, PS.index_id 
			, Used_MB = SUM(PS.used_page_count) / 128 
			, Used_InRow_MB = SUM(PS.in_row_used_page_count) / 128
			, Used_LOB_MB = SUM(PS.lob_used_page_count) / 128
			, Reserved_MB = SUM(PS.reserved_page_count) / 128
			, row_count = SUM(row_count)
		FROM sys.dm_db_partition_stats PS
		GROUP BY PS.object_id
			, PS.index_id
	) i ON p.object_id = i.object_id AND p.index_id = i.index_id
	LEFT JOIN sys.indexes ix ON i.object_id = ix.object_id AND i.index_id = ix.index_id
	LEFT JOIN sys.objects o ON p.object_id = o.object_id
WHERE database_id = db_id()  
GROUP BY bd.database_id   
	, o.schema_id
	, o.name
	, p.index_id
	, ix.Name
	, i.Used_MB
	, i.Used_InRow_MB
	, i.Row_Count     
HAVING SUM(bd.pages) > 128  
ORDER BY 1 DESC;'  

EXEC sp_MSforeachdb @SQL

SELECT Cached_MB 
	, Pct_of_Cache = CAST(Cached_MB * 100.0 / SUM(Cached_MB) OVER () as Dec(20,3))
	, Pct_Index_in_Cache = CAST(Cached_MB * 100.0 / CASE Used_MB WHEN 0 THEN 0.001 ELSE Used_MB END as DEC(20,3))
	, Database_Name 
	, Schema_Name 
	, Object_Name 
	, Index_ID 
	, Index_Name 
	, Used_MB 
	, Used_InRow_MB 
	, Row_Count 
FROM #BufferPool 
ORDER BY Cached_MB DESC