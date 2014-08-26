
/**************************************************************************************
* Description: Finds all databases in the current instance that are owned by credentials
*   other than 'SA' and changes them to SA to keep personal login loss from killing databases.
* Author: Dave Bennett
* Created: 1/23/2012
* Last Updated:8/29/2012 - Fixed syntax to all for databases with '-' in the name
***************************************************************************************/

	
	DECLARE @dbName NVARCHAR(200), @Owner NVARCHAR(100), @SQL NVARCHAR(4000);

	DECLARE dbs CURSOR FAST_FORWARD READ_ONLY FOR
	SELECT NAME, SUSER_SNAME(owner_sid) dbOwner
		FROM   sys.databases
		WHERE SUSER_SNAME(owner_sid) != 'sa' OR SUSER_SNAME(owner_sid) is null; 

	OPEN dbs

	FETCH NEXT FROM dbs INTO @dbName, @Owner

	WHILE @@FETCH_STATUS = 0
	BEGIN

	PRINT 'Changed: ' + @dbName +' Owner: '+ ISNULL(@Owner,'')
	SET @SQL = 'ALTER AUTHORIZATION ON DATABASE::[' + @dbName + '] TO sa'
	EXEC (@SQL)

	FETCH NEXT FROM dbs INTO @dbName, @Owner

	END

	CLOSE dbs
	DEALLOCATE dbs

              