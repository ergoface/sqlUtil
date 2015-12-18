/* List all currently executing processes on an instance. Only actively running items are shown 
Author: Abhinav Dhiman http://tsqltips.blogspot.com/2012/06/monitor-current-sql-server-processes.html */

SELECT s.session_id    AS 'SessionId',
       s.login_name    AS 'Login',
       COALESCE(s.host_name, c.client_net_address) AS 'Host',
       s.program_name  AS 'Application',
       t.task_state    AS 'TaskState',
       r.start_time    AS 'TaskStartTime',
       r.[status] AS 'TaskStatus',
       r.wait_type     AS 'TaskWaitType',
       TSQL.[text] AS 'TSQL',
       (
           tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count
       ) +(
           tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count
       )               AS 'TotalPagesAllocated'
FROM   sys.dm_exec_sessions s
       LEFT  JOIN sys.dm_exec_connections c
            ON  s.session_id = c.session_id
       LEFT JOIN sys.dm_db_task_space_usage tsu
            ON  tsu.session_id = s.session_id
       LEFT JOIN sys.dm_os_tasks t
            ON  t.session_id = tsu.session_id
            AND t.request_id = tsu.request_id
       LEFT JOIN sys.dm_exec_requests r
            ON  r.session_id = tsu.session_id
            AND r.request_id = tsu.request_id
       OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) TSQL
WHERE  (
           tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count
       ) +(
           tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count
       ) > 0;