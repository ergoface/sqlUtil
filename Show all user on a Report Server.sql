/**** Show all users and the number reports executed by them ****/
USE ReportServer
GO
DECLARE @List VARCHAR(max);

SELECT 
    @List = COALESCE(@List,'') + '"' + RIGHT(ExecutionLog.UserName,LEN(UserName)-5) + '", '
   
     
   FROM ExecutionLog 
      INNER JOIN Catalog
      ON ExecutionLog.ReportID = Catalog.ItemID
   WHERE 
   UserName NOT LIKE  'CORP\A1%' -- Eliminate Service Accounts
   AND dbo.ExecutionLog.TimeStart BETWEEN '10/3/2013' AND '10/4/2013'
   GROUP BY UserName 
SELECT @List   
  