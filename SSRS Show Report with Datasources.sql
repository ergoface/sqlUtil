/* SSRS Show Report with Datasource(s) */
USE [ReportServer];
GO


SELECT
        R.Name
      , R.Path
      , C.Path DatasourcePath
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
    ORDER BY
        R.Path
      , R.Name;
	