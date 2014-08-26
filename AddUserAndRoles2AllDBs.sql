/* Create a given User across all databases in an instance for a given login and give it the desired roles */
USE master
GO
--SELECT * FROM sys.databases AS D
DECLARE @SQL VARCHAR(4000),
        @Login VARCHAR(150);
SET @Login = 'CORP\COKC0-DB071V-MSSQLSERVER_DWDEALL'        

SET @SQL = '
USE [?];
If not EXISTS(SELECT USER_ID(''' + @Login +'''))
BEGIN
CREATE USER [' + @Login + '] FOR LOGIN [' + @Login + '];
EXEC sp_addrolemember ''db_datareader'', ''' + @Login +''';
EXEC sp_addrolemember ''db_datawriter'', ''' + @Login +''';
IF DATABASE_PRINCIPAL_ID(''db_executor'') IS NOT NULL
EXEC sp_addrolemember ''db_executor'', ''' + @Login +''';

END
'

EXEC sp_msforeachdb @SQL;


