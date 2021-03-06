/* Create a given User across all databases in an instance for a given login and give it the desired roles */
USE master
GO
--SELECT * FROM sys.databases AS D
DECLARE @SQL VARCHAR(4000),
        @Login VARCHAR(150);
SET @Login = 'CORP\CCEN3-DB071V-MSSQLSERVER-ALLDBs_DWDE'        

SET @SQL = '
USE [?];
If USER_ID(''' + @Login +''') Is NULL
BEGIN
Print ''Adding and Roles to ?'';
CREATE USER [' + @Login + '] FOR LOGIN [' + @Login + '];
EXEC sp_addrolemember ''db_datareader'', ''' + @Login +''';
EXEC sp_addrolemember ''db_datawriter'', ''' + @Login +''';
IF DATABASE_PRINCIPAL_ID(''db_executor'') IS NOT NULL
EXEC sp_addrolemember ''db_executor'', ''' + @Login +''';

END
ELSE
Print ''Not Adding User to ?''
'

EXEC sp_msforeachdb @SQL;

