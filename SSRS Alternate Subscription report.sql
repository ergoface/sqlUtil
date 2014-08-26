USE ReportServer
GO
WITH  [Sub_Parameters]
        AS ( SELECT [SubscriptionID]
                 ,[Parameters] = CONVERT(XML, a.[Parameters])
               FROM [Subscriptions] a
           ),
      [MySubscriptions]
        AS ( SELECT DISTINCT [SubscriptionID]
                 ,[ParameterName] = QUOTENAME(p.value('(Name)[1]',
                                                      'nvarchar(max)'))
                 ,[ParameterValue] = p.value('(Value)[1]', 'nvarchar(max)')
               FROM [Sub_Parameters] a 
                  CROSS APPLY [Parameters].nodes('/ParameterValues/ParameterValue') t ( p )
           ),
      [SubscriptionsAnalysis]
        AS ( SELECT a.[SubscriptionID]
                 ,a.[ParameterName]
                 ,[ParameterValue] = ( SELECT STUFF(( SELECT [ParameterValue]
                                                            + ', ' AS [text()]
                                                         FROM [MySubscriptions]
                                                         WHERE [SubscriptionID] = a.[SubscriptionID]
                                                            AND [ParameterName] = a.[ParameterName]
                                                    FOR
                                                      XML PATH('')
                                                    ), 1, 0, '') + ''
                                     )
               FROM [MySubscriptions] a
               GROUP BY a.[SubscriptionID]
                 ,a.[ParameterName]
           ),
      SubParams AS (
   SELECT SubscriptionID
        ,Parameters = ( SELECT +STUFF(( SELECT 'Name:' + ParameterName
                                             + ' Values: ' + ParameterValue
                                             + ', '
                                          FROM SubscriptionsAnalysis
                                          WHERE SubscriptionID = A.subscriptionId
                                      FOR
                                        XML PATH('')
                                      ), 1, 0, '') + ''
                      )
      FROM SubscriptionsAnalysis A
      GROUP BY A.SubscriptionID
  )    


SELECT
c.Name AS ReportName,
REPLACE(c.PATH,c.NAME,'') PATH,
CASE WHEN next_run_date >0 THEN CAST(CAST(next_run_date AS VARCHAR(10)) AS DATE ) ELSE NULL END NextRunDate,
'Next Run Time' = CASE len(next_run_time)
WHEN 1 THEN '00:00:00'
WHEN 3 THEN cast('00:0'
+ Left(right(next_run_time,3),1)
+':' + right(next_run_time,2) as char (8))
WHEN 4 THEN cast('00:'
+ Left(right(next_run_time,4),2)
+':' + right(next_run_time,2) as char (8))
WHEN 5 THEN cast('0' + Left(right(next_run_time,5),1)
+':' + Left(right(next_run_time,4),2)
+':' + right(next_run_time,2) as char (8))
WHEN 6 THEN cast(Left(right(next_run_time,6),2)
+':' + Left(right(next_run_time,4),2)
+':' + right(next_run_time,2) as char (8))
END,
Convert(XML,[ExtensionSettings]).value('(//ParameterValue/Value[../Name="TO"])[1]','nvarchar(50)') as [To]
,Convert(XML,[ExtensionSettings]).value('(//ParameterValue/Value[../Name="CC"])[1]','nvarchar(50)') as [CC]
,Convert(XML,[ExtensionSettings]).value('(//ParameterValue/Value[../Name="RenderFormat"])[1]','nvarchar(50)') as [Render Format]
,Convert(XML,[ExtensionSettings]).value('(//ParameterValue/Value[../Name="Subject"])[1]','nvarchar(50)') as [Subject]

,P.Parameters
,[LastStatus]
,[EventType]
,[LastRunTime]
,[DeliveryExtension]

FROM 
 dbo.[Catalog] c
INNER JOIN dbo.[Subscriptions] S ON c.ItemID = S.Report_OID
LEFT JOIN subParams P
	ON s.SubscriptionID = p.SubscriptionID
LEFT OUTER JOIN dbo.ReportSchedule R ON S.SubscriptionID = R.SubscriptionID
INNER JOIN msdb.dbo.sysjobs J ON Convert(nvarchar(128),R.ScheduleID) = J.name
INNER JOIN msdb.dbo.sysjobschedules JS ON J.job_id = JS.job_id

ORDER BY LastRunTime DESC