/****************************************************************
* Show all user tables in a given database with the row count
*   for each table
*  Created:3/13/2012
* This is a brute force approach, and is slow and costly on large databases.
* Not recommened for prod or large databases.
* Author: Dave Bennett
*****************************************************************/

DECLARE  @TableInfo TABLE(TableName Varchar(255),Rows Int)
Insert Into @TableInfo
EXEC sp_MSforeachtable "SELECT '?' [TableName], count(*) Rows from ?;"
SELECT * FROM @TableInfo
ORDER BY Rows DESC