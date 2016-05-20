/********************************************************************************************* 
Create script to Remove all users from a database (except those that own schemas)
Based on a thread from SQLServerCentral http://www.sqlservercentral.com/Forums/Topic676687-146-1.aspx
 Modifed by Dave Bennett
 Last Modifed: 5/20/2016
 ********************************************************************************************/
DECLARE @sql NVARCHAR(MAX);
SET @sql = '';

SELECT @sql = @sql + '
PRINT ''Dropping ' + dp.name + '''
EXECUTE sp_revokedbaccess ''' + dp.name + '''
'
    FROM sys.database_principals dp
    WHERE dp.type <> 'R'
        AND NOT EXISTS ( SELECT 1
                            FROM sys.schemas s
                            WHERE s.principal_id = dp.principal_id )
    ORDER BY dp.name;
PRINT ( @sql );



