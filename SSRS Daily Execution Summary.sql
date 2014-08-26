WITH  BASE
        AS ( SELECT [RequestType]
                 ,[Format]
                 ,[ItemAction]
                 ,[TimeStart]
                 ,[Start_Year]
                 ,[Start_Month]
                 ,[SOURCE]
                 ,[Status]
                 ,[ByteCount]
                 ,[RowCount]
                 ,[Type_Description]
               FROM [ReportServer].[dbo].[ExecutionLog3_Modified] EL
           )
   SELECT [Start_Year]
        ,[Start_Month]
        ,DATEPART(week, TimeStart) Week
        ,DAY(TimeStart) DayNum
        ,COUNT(*) Executions
        ,SUM(CASE WHEN status = 'rsSuccess' THEN 1
                  ELSE 0
             END) Successes
        ,SUM(CASE WHEN status IN ( 'rsReportServerDatabaseError',
                                   'rsDataSetExecutionError',
                                   'rrRenderingError' ) THEN 1
                  ELSE 0
             END) Errors
        ,SUM(CASE WHEN status = 'rsProcessingAborted' THEN 1
                  ELSE 0
             END) Aborted
      FROM BASE
      GROUP BY [Start_Year]
        ,[Start_Month]
        ,DATEPART(week, TimeStart)
        ,DAY(TimeStart)
      ORDER BY 1
        ,2
        ,3
        ,4