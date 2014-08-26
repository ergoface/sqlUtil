CREATE FUNCTION dbo.ShowIndexStatus(@DateFrom AS DATETIME)
RETURNS TABLE
AS 
/*************************************************************************
* Function to show Index fragmentation status
* Author: Brent Ozar
* Modified by: Dave Bennett
* Modified date: 2/10/2011
* Depends on: tables created the dba_indexDefrag_sp
**************************************************************************/
RETURN(
SELECT TOP 1000 databaseName, COUNT(*) AS Touches, AVG(durationSeconds * 1.00) AS AvgDuration, SUM(durationSeconds) AS TotalDuration, AVG(fragmentation) AS AvgFragmentation
, COUNT(CASE WHEN fragmentation BETWEEN 0 AND 10 THEN 1 END) AS Frag10
, COUNT(CASE WHEN fragmentation BETWEEN 10 AND 20 THEN 1 END) AS Frag20
, COUNT(CASE WHEN fragmentation BETWEEN 20 AND 30 THEN 1 END) AS Frag30
, COUNT(CASE WHEN fragmentation BETWEEN 30 AND 40 THEN 1 END) AS Frag40
, COUNT(CASE WHEN fragmentation BETWEEN 40 AND 50 THEN 1 END) AS Frag50
, COUNT(CASE WHEN fragmentation BETWEEN 50 AND 60 THEN 1 END) AS Frag60
, COUNT(CASE WHEN fragmentation BETWEEN 60 AND 70 THEN 1 END) AS Frag70
, COUNT(CASE WHEN fragmentation BETWEEN 70 AND 80 THEN 1 END) AS Frag80
, COUNT(CASE WHEN fragmentation BETWEEN 80 AND 90 THEN 1 END) AS Frag90
, COUNT(CASE WHEN fragmentation BETWEEN 90 AND 100 THEN 1 END) AS Frag100
FROM DBAUtil.dbo.dba_indexDefragLog
WHERE dateTimeStart > @DateFrom
GROUP BY databaseName
ORDER BY databaseName



)
