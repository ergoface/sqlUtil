USE [master]
GO
/****** Object:  StoredProcedure [dbo].[AddUserNRoll2AllDBs]    Script Date: 08/16/2011 14:45:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[AddUserNRoll2AllDBs] (@USERID NVARCHAR(200), @ROLE NVARCHAR(50))
/************************************************************************
* Procedure to add a User and a specific role to every database within
*  an instance. Allows a user to be added to every database. The login
*  must have already been created in the instance.
* Author: Dave Bennett
* Created: 8/11/2011
* Last Modified: 8/11/2011
* Relies on: sp_ForEachDB
*
* Example:
* Exec AddUserNRoll2AllDBs @USERID = 'corp\foo', @ROLE = 'db_owner'
*************************************************************************/
AS
BEGIN
	DECLARE @SQL NVARCHAR(2000)
	SET @SQL ='
		USE [?];
		IF NOT EXISTS (SELECT * 
		FROM sys.database_principals
		WHERE name = ''' + @USERID +''')
		BEGIN
		CREATE USER [' + @USERID + '] FOR LOGIN [' + @USERID + '];
		EXEC sp_addrolemember N''' + @ROLE +''', N''' + @USERID + '''
		END
		'
	EXEC sp_ForEachDB @Command = @SQL, @User_Only = 1
END

