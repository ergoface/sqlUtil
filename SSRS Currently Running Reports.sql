/*SSRS Currently Running Reports*/
SELECT  [JobID]
      ,[StartDate]
      ,[ComputerName]
      ,[RequestName]
      ,[RequestPath]
      ,u.UserName
      ,[Description]
      ,[Timeout]
      ,[JobAction]
      ,[JobType]
      ,[JobStatus]
  FROM [ReportServer].[dbo].[RunningJobs]
  INNER JOIN
   ReportServer.dbo.Users AS U
     ON U.UserID = dbo.RunningJobs.UserId
  ORDER BY StartDate