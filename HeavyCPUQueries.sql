select  
    highest_cpu_queries.plan_handle,  
    highest_cpu_queries.total_worker_time, 
    d.name, 
    q.objectid, 
    q.number, 
    q.encrypted,
    highest_cpu_queries.execution_count,
    highest_cpu_queries.total_rows,
    highest_cpu_queries.total_logical_reads,
    highest_cpu_queries.total_elapsed_time,
    highest_cpu_queries.creation_time, 
    q.[text]
     
from  
    (select top 50  
        qs.plan_handle,  
        qs.total_worker_time,
        qs.total_logical_reads,
        qs.total_elapsed_time,
        qs.[total_rows],
        qs.execution_count,
        qs.creation_time
        
    from  
        sys.dm_exec_query_stats qs 
    order by qs.total_worker_time desc) as highest_cpu_queries 
    cross apply sys.dm_exec_sql_text(plan_handle) as q
    INNER JOIN sys.databases d
		ON d.database_id = q.dbid 
order by highest_cpu_queries.total_worker_time DESC

