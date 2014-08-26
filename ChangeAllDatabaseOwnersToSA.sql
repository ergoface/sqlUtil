USE DBAUtil
go
CREATE PROCEDURE ChangeAllDatabaseOwnersToSA
	
AS
/**************************************************************************************
* Description: Finds all databases in the current instance that are owned by credentials
*   other than 'SA' and changes them to SA to keep personal login loss from killing databases.
* Author: Dave Bennett
* Created: 1/23/2012
* Last Updated: 1/23/2012 
* Relies on: N/A	
* Modifies: N/A
* Parameters:None
* Example: Exec ChangeAllDatabaseOwnersToSA
***************************************************************************************/
BEGIN
  SET NOCOUNT ON
	
	DECLARE @dbName NVARCHAR(100), @Owner NVARCHAR(50), @SQL NVARCHAR(4000);

	DECLARE dbs CURSOR FAST_FORWARD READ_ONLY FOR
	SELECT NAME, SUSER_SNAME(owner_sid) dbOwner
		FROM   sys.databases
		WHERE SUSER_SNAME(owner_sid) != 'sa' OR SUSER_SNAME(owner_sid) is null; 

	OPEN dbs

	FETCH NEXT FROM dbs INTO @dbName, @Owner

	WHILE @@FETCH_STATUS = 0
	BEGIN

	PRINT 'Changed: ' + @dbName +' Owner: '+ ISNULL(@Owner,'')
	SET @SQL = 'ALTER AUTHORIZATION ON DATABASE::' + @dbName + ' TO sa'
	EXEC (@SQL)

	FETCH NEXT FROM dbs INTO @dbName, @Owner

	END

	CLOSE dbs
	DEALLOCATE dbs
   
END
GO
              