/****** Show Report Server Sessions  ******/
SELECT  [session_id]
      ,[login_time]
      ,[nt_user_name]
      ,[status]
      ,[cpu_time]
      ,[memory_usage]
      ,[total_scheduled_time]
      ,[total_elapsed_time]
      ,[last_request_start_time]
      ,[last_request_end_time]
      ,[reads]
      ,[writes]
      ,[logical_reads]
      ,[transaction_isolation_level]
      ,[lock_timeout]
      ,[deadlock_priority]
      ,[row_count]
     
  FROM [ReportServerTempDB].[sys].[dm_exec_sessions]
  WHERE program_name = 'Report Server'
  ORDER BY login_time

