/****** Show statistics and latest update for all tables in current database  ******/
SELECT [TABLE_CATALOG] "Database"
      ,[TABLE_SCHEMA]
      ,[TABLE_NAME]
      ,[TABLE_TYPE]
      ,name AS stats_name
      ,STATS_DATE(object_id, stats_id) AS statistics_update_date
  FROM [INFORMATION_SCHEMA].[TABLES] T	
   INNER JOIN sys.stats  s 
    ON s.object_id = object_id(t.TABLE_NAME)
  ORDER BY t.TABLE_NAME, STATS_DATE(object_id, stats_id)   