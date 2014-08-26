/*******************************************************************
Show all tables, row counts and space used for a database and tables
  in it.
********************************************************************/

EXEC sys.sp_spaceused 

CREATE TABLE #RowCountsAndSizes (TableName NVARCHAR(128),rows CHAR(11),     
       reserved VARCHAR(18),data VARCHAR(18),index_size VARCHAR(18),
       unused VARCHAR(18))

EXEC       sp_MSForEachTable 'INSERT INTO #RowCountsAndSizes EXEC sp_spaceused ''?'' '

SELECT     TableName,CONVERT(bigint,rows) AS NumberOfRows,
           CONVERT(bigint,left(reserved,len(reserved)-3)) AS SizeinKB
		   ,CAST(((CONVERT(bigint,left(reserved,len(reserved)-3))*1.00) / SUM(CONVERT(bigint,left(reserved,len(reserved)-3))) OVER(PARTITION BY 1) )*100 AS DECIMAL (8,2))PercentOfTotal
FROM       #RowCountsAndSizes
ORDER BY   NumberOfRows DESC,SizeinKB DESC,TableName

DROP TABLE #RowCountsAndSizes 