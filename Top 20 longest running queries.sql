/* My own query for top 20 longest running queries */
SELECT TOP 20 d.object_id, DB_NAME(d.database_id) DatabaseName, OBJECT_NAME(object_id, database_id) 'proc name', 
    d.cached_time, d.last_execution_time, d.total_elapsed_time/1000000.0 TotalElapsedSec,
    (d.total_elapsed_time/d.execution_count)/1000000.0 AS [avg_elapsed_time],
    d.last_elapsed_time/1000000.0 AS last_elapsed_time, d.execution_count
FROM sys.dm_exec_procedure_stats AS d
ORDER BY avg_elapsed_time DESC;