USE
ReportServer
GO
/* Find what report uses a given query snippet SSRS */
Declare @Namespace NVARCHAR(500) 
Declare @SQL   VARCHAR(max) 
DECLARE @QueryText VARCHAR(max);
/* Put your query snippet here */
SET @QueryText = 'DATA2'
 
SELECT @Namespace= SUBSTRING( 
                   x.CatContent   
                  ,x.CIndex 
                  ,CHARINDEX('"',x.CatContent,x.CIndex+7) - x.CIndex 
                ) 
      FROM 
     ( 
         SELECT CatContent = CONVERT(NVARCHAR(MAX),CONVERT(XML,CONVERT(VARBINARY(MAX),C.Content))) 
                ,CIndex    = CHARINDEX('xmlns="',CONVERT(NVARCHAR(MAX),CONVERT(XML,CONVERT(VARBINARY(MAX),C.Content)))) 
           FROM Reportserver.dbo.Catalog C 
          WHERE C.Content is not null 
            AND C.Type  = 2 
     ) X 
 
SELECT @Namespace = REPLACE(@Namespace,'xmlns="','') + '' ;

SELECT @SQL = 'WITH XMLNAMESPACES ( DEFAULT ''' + @Namespace + ''', ''http://schemas.microsoft.com/SQLServer/reporting/reportdesigner'' AS rd ) 
SELECT  ReportName        = name 
       ,DataSetName        = x.value(''(@Name)[1]'', ''VARCHAR(250)'')  
       ,DataSourceName    = x.value(''(Query/DataSourceName)[1]'',''VARCHAR(250)'') 
       ,CommandText        = x.value(''(Query/CommandText)[1]'',''VARCHAR(max)'') 
       
  FROM (  SELECT C.Name,CONVERT(XML,CONVERT(VARBINARY(MAX),C.Content)) AS reportXML 
           FROM  ReportServer.dbo.Catalog C 
          WHERE  C.Content is not null 
            AND  C.Type = 2 
           --report name 
       ) a 
  CROSS APPLY reportXML.nodes(''/Report/DataSets/DataSet'') r ( x ) 
 where  x.value(''(Query/CommandText)[1]'',''VARCHAR(max)'') like ''%' + @QueryText + '%''  
ORDER BY name ' 
EXEC(@SQL)


