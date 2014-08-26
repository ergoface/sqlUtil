/* Logins with no matching User */
USE MASTER; 
CREATE TABLE #dbusers ( sid VARBINARY(85) ) 

EXEC sp_MSforeachdb 'insert #dbusers select sid from [?].sys.database_principals where type != ''R''' 

SELECT name
   FROM sys.server_principals
   WHERE sid IN ( SELECT sid
                     FROM sys.server_principals
                     WHERE TYPE != 'R'
                        AND name NOT LIKE ( '##%##' )
                  EXCEPT
                  SELECT DISTINCT sid
                     FROM #dbusers ) 
GO 
DROP TABLE #dbusers 