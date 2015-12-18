/* SSRS Show Report with Datasource(s) */
USE [ReportServer];
GO
 IF OBJECT_ID('tempdb..#ReportDefs') IS NOT NULL
	DROP TABLE #ReportDefs;

SELECT
        R.Name ReportName
      , R.Path
	  , r.Type
	  ,CASE r.Type
       WHEN 2 THEN 'Report'
       WHEN 5 THEN 'Data Source'
       WHEN 7 THEN 'Report Part'
       WHEN 8 THEN 'Shared Dataset'
       ELSE 'Other'
     END AS TypeDescription
      , C.Path DatasourcePath
	  , c.Name DataSource
	  , CONVERT(XML, CONVERT(VARCHAR(MAX), CONVERT(VARBINARY(MAX), r.CONTENT))) Def
	INTO #ReportDefs
    FROM
        dbo.Catalog AS R
    INNER JOIN ExtendedDataSources AS DS
        ON DS.ItemID = R.ItemID
           OR DS.SubscriptionID = R.ItemID
    LEFT OUTER JOIN (
                      DataSource AS DSL
                      INNER JOIN Catalog C
                        ON DSL.[ItemID] = C.[ItemID]
                    ) 
        ON DS.[Link] = DSL.[ItemID]
WHERE c.Path NOT IN('/Information Technology/Data Sources/PSTAGE.OKC_APP'
                   ,'/Information Technology/Data Sources/CEN-DW.PstageCache'
				  -- ,'/Information Technology/Data Sources/PODS_UET_REP.SQLRPT_KSAROK'
				   )
				   AND r.Path NOT LIKE '%Graveyard%'
    ORDER BY
        R.Path
      , R.Name;


	
SELECT
     ReportName
	 ,Path
	 ,DatasourcePath
	 ,DataSource
	 ,[Type]
	 ,TypeDescription
	-- ,Def
    ,ISNULL(Query.value('(./*:CommandType/text())[1]','nvarchar(1024)'),'Query') AS CommandType
    ,Query.value('(./*:CommandText/text())[1]','nvarchar(max)') AS CommandText
FROM #ReportDefs
--Get all the Query elements (The "*:" ignores any xml namespaces)
CROSS APPLY #ReportDefs.Def.nodes('//*:Query') Queries(Query)
ORDER BY DataSource


SELECT DISTINCT RD.DataSource
,RD.DatasourcePath

FROM #ReportDefs AS RD



