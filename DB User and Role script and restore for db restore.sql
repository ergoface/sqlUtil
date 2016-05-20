/********************************************************************************************
 Script to be used to grab current users/roles/permissions for a database prior to 
   restoring that database from a different environment which might/will have different
   users/ permissions defined than the currrent. 

Run this script just prior to restoring a copy of the database from a different environment
  then run the resultant script after you have restored the database to reset the users
  to the status they were in prior to the restore.

NOTE: This script does not create any logins since it is only designed to restore the users 
        to the database that were there prior to the db being restored from a different server.
Credits:
Script DB Level Permissions v2.1
Source: http://www.sqlservercentral.com/scripts/Security/71562/
Modified by Dave Bennett to include additional Role features

Drop script derived from a thread in sqlservercentral: http://www.sqlservercentral.com/Forums/Topic676687-146-1.aspx
Also Modified by Dave Bennett
Last Modified: 5/20/2016
********************************************************************************************/

DECLARE 
    @sql VARCHAR(2048)
   

/**************************************************************************/
/******** Script out Drop existing Users to clear out incoming users *****/
/*************************************************************************/
SELECT @sql = 'USE' + SPACE(1) + QUOTENAME(DB_NAME()) + '
GO';
SET @sql = @sql + '
DECLARE @sql VARCHAR(MAX) = '''';

SELECT @sql = @sql + ''
PRINT ''''Dropping '' + dp.name + ''''''
EXECUTE sp_revokedbaccess '''''' + dp.name + ''''''
''
    FROM sys.database_principals dp
    WHERE dp.type <> ''R''
        AND ((NOT EXISTS ( SELECT 1
                            FROM sys.schemas s
                            WHERE s.principal_id = dp.principal_id ))
		 OR (SUSER_NAME(sid) IS NULL))
    ORDER BY dp.name;
EXEC ( @sql );
GO
';
PRINT @sql
/**********************************************************************************
***** Script out all current users, roles and permissions to be used after restore 
***********************************************************************************/
DECLARE 
       @sort INT
DECLARE tmp CURSOR FOR


/*********************************************/
/*********   DB CONTEXT STATEMENT    *********/
/*********************************************/
SELECT '-- [-- DB CONTEXT --] --' AS [-- SQL STATEMENTS --],
        1 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT  'USE' + SPACE(1) + QUOTENAME(DB_NAME()) AS [-- SQL STATEMENTS --],
        1 AS [-- RESULT ORDER HOLDER --]

UNION

SELECT '' AS [-- SQL STATEMENTS --],
        2 AS [-- RESULT ORDER HOLDER --]

UNION

/*********************************************/
/*********     DB USER CREATION      *********/
/*********************************************/

SELECT '-- [-- DB USERS --] --' AS [-- SQL STATEMENTS --],
        3 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT  'IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = ' + SPACE(1) + '''' + [name] + '''' + ') BEGIN CREATE USER ' + SPACE(1) + QUOTENAME([name]) + ' FOR LOGIN ' + QUOTENAME([name]) + ' WITH DEFAULT_SCHEMA = ' + QUOTENAME([default_schema_name]) + SPACE(1) + 'END; ' AS [-- SQL STATEMENTS --],
        4 AS [-- RESULT ORDER HOLDER --]
FROM    sys.database_principals AS rm
WHERE [type] IN ('U', 'S', 'G') -- windows users, sql users, windows groups

UNION
/*********************************************/
/*******     DB ROLE CREATION ****************/
/*********************************************/
SELECT '-- [-- DB ROLE CREATION --] --' AS [-- SQL STATEMENTS --],
        5 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT 'IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''' + dp.name + ''') CREATE ROLE ' + DP.name + ';', 5  AS [-- RESULT ORDER HOLDER --]
FROM sys.database_principals  AS DP
INNER JOIN sys.database_principals AS DP2
	ON dp.owning_principal_id = dp2.principal_id
	WHERE dp.type = 'R' AND DP.is_fixed_role = 0 AND DP.principal_id > 0
UNION
/*********************************************/
/*********    DB ROLE PERMISSIONS    *********/
/*********************************************/
SELECT '-- [-- DB ROLES --] --' AS [-- SQL STATEMENTS --],
        6 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT  'EXEC sp_addrolemember @rolename ='
    + SPACE(1) + QUOTENAME(USER_NAME(rm.role_principal_id), '''') + ', @membername =' + SPACE(1) + QUOTENAME(USER_NAME(rm.member_principal_id), '''') AS [-- SQL STATEMENTS --],
        7 AS [-- RESULT ORDER HOLDER --]
FROM    sys.database_role_members AS rm
WHERE   USER_NAME(rm.member_principal_id) IN (  
                                                --get user names on the database
                                                SELECT [name]
                                                FROM sys.database_principals
                                                WHERE [principal_id] > 4 -- 0 to 4 are system users/schemas
                                                and [type] IN ('G', 'S', 'U') -- S = SQL user, U = Windows user, G = Windows group
												AND SUSER_Sname(sid) IS NOT NULL -- don't try and add back curently orphaned users
                                              )
--ORDER BY rm.role_principal_id ASC


UNION

SELECT '' AS [-- SQL STATEMENTS --],
        8 AS [-- RESULT ORDER HOLDER --]

UNION

/*********************************************/
/*********  OBJECT LEVEL PERMISSIONS *********/
/*********************************************/
SELECT '-- [-- OBJECT LEVEL PERMISSIONS --] --' AS [-- SQL STATEMENTS --],
        9 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT  CASE 
            WHEN perm.state <> 'W' THEN perm.state_desc 
            ELSE 'GRANT'
        END
        + SPACE(1) + perm.permission_name + SPACE(1) + 'ON ' + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + '.' + QUOTENAME(obj.name) --select, execute, etc on specific objects
        + CASE
                WHEN cl.column_id IS NULL THEN SPACE(0)
                ELSE '(' + QUOTENAME(cl.name) + ')'
          END
        + SPACE(1) + 'TO' + SPACE(1) + QUOTENAME(USER_NAME(usr.principal_id)) COLLATE database_default
        + CASE 
                WHEN perm.state <> 'W' THEN SPACE(0)
                ELSE SPACE(1) + 'WITH GRANT OPTION'
          END
            AS [-- SQL STATEMENTS --],
        10 AS [-- RESULT ORDER HOLDER --]
FROM    
    sys.database_permissions AS perm
        INNER JOIN
    sys.objects AS obj
            ON perm.major_id = obj.[object_id]
        INNER JOIN
    sys.database_principals AS usr
            ON perm.grantee_principal_id = usr.principal_id
        LEFT JOIN
    sys.columns AS cl
            ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
WHERE  SUSER_Sname(usr.sid) IS NOT NULL -- don't try and add back curently orphaned users
--ORDER BY perm.permission_name ASC, perm.state_desc ASC



UNION

SELECT '' AS [-- SQL STATEMENTS --],
    11 AS [-- RESULT ORDER HOLDER --]

UNION

/*********************************************/
/*********    DB LEVEL PERMISSIONS   *********/
/*********************************************/
SELECT '-- [--DB LEVEL PERMISSIONS --] --' AS [-- SQL STATEMENTS --],
        12 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT  CASE 
            WHEN perm.state <> 'W' THEN perm.state_desc --W=Grant With Grant Option
            ELSE 'GRANT'
        END
    + SPACE(1) + perm.permission_name --CONNECT, etc
    + SPACE(1) + 'TO' + SPACE(1) + '[' + USER_NAME(usr.principal_id) + ']' COLLATE database_default --TO <user name>
    + CASE 
            WHEN perm.state <> 'W' THEN SPACE(0) 
            ELSE SPACE(1) + 'WITH GRANT OPTION' 
      END
        AS [-- SQL STATEMENTS --],
        13 AS [-- RESULT ORDER HOLDER --]
FROM    sys.database_permissions AS perm
    INNER JOIN
    sys.database_principals AS usr
    ON perm.grantee_principal_id = usr.principal_id


WHERE   [perm].[major_id] = 0
    AND [usr].[principal_id] > 4 -- 0 to 4 are system users/schemas
    AND [usr].[type] IN ('G', 'S', 'U', 'R') -- S = SQL user, U = Windows user, G = Windows group, R = db_Role
	AND SUSER_Sname(usr.sid) IS NOT NULL -- don't try and add back curently orphaned users

UNION

SELECT '' AS [-- SQL STATEMENTS --],
        14 AS [-- RESULT ORDER HOLDER --]

UNION 

SELECT '-- [--DB LEVEL SCHEMA PERMISSIONS --] --' AS [-- SQL STATEMENTS --],
        15 AS [-- RESULT ORDER HOLDER --]
UNION
SELECT  CASE
            WHEN perm.state <> 'W' THEN perm.state_desc --W=Grant With Grant Option
            ELSE 'GRANT'
            END
                + SPACE(1) + perm.permission_name --CONNECT, etc
                + SPACE(1) + 'ON' + SPACE(1) + class_desc + '::' COLLATE database_default --TO <user name>
                + QUOTENAME(SCHEMA_NAME(major_id))
                + SPACE(1) + 'TO' + SPACE(1) + QUOTENAME(USER_NAME(grantee_principal_id)) COLLATE database_default
                + CASE
                    WHEN perm.state <> 'W' THEN SPACE(0)
                    ELSE SPACE(1) + 'WITH GRANT OPTION'
                    END
            AS [-- SQL STATEMENTS --],
        16 AS [-- RESULT ORDER HOLDER --]
from sys.database_permissions AS perm
    inner join sys.schemas s
        on perm.major_id = s.schema_id
    inner join sys.database_principals dbprin
        on perm.grantee_principal_id = dbprin.principal_id
WHERE class = 3 --class 3 = schema


ORDER BY [-- RESULT ORDER HOLDER --]


OPEN tmp
FETCH NEXT FROM tmp INTO @sql, @sort
WHILE @@FETCH_STATUS = 0
BEGIN
        PRINT @sql
        FETCH NEXT FROM tmp INTO @sql, @sort    
END

CLOSE tmp
DEALLOCATE tmp 