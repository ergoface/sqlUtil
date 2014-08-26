/* List Logins and Roles to all DBs in an Instance */

/* List SysAdmins (who have all access to all DBs)*/
SELECT p.name AS [Name]
     ,p.type_desc
     ,p.is_disabled
     ,p.create_date
     ,p.modify_date
     ,p.default_database_name
   FROM sys.server_principals r
      INNER JOIN sys.server_role_members m
      ON r.principal_id = m.role_principal_id 
      INNER JOIN sys.server_principals p
      ON p.principal_id = m.member_principal_id
   WHERE r.type = 'R'
      AND r.name = N'sysadmin'

/* List Users, Roles and permissions in Each DB */
DECLARE @DB_USers TABLE
   (
    DBName SYSNAME
   ,UserName SYSNAME
   ,LoginType SYSNAME
   ,AssociatedRole VARCHAR(MAX)
   ,create_date DATETIME
   ,modify_date DATETIME
   )
 
INSERT @DB_USers
      EXEC sp_MSforeachdb '
use [?]
SELECT ''?'' AS DB_Name,
case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName,
prin.type_desc AS LoginType,
isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date
FROM sys.database_principals prin
LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00) and
prin.is_fixed_role <> 1 AND prin.name NOT LIKE ''##%'''
 
SELECT dbname
     ,username
     ,logintype
     ,create_date
     ,modify_date
     ,STUFF(( SELECT ',' + CONVERT(VARCHAR(500), associatedrole)
               FROM @DB_USers user2
               WHERE user1.DBName = user2.DBName
                  AND user1.UserName = user2.UserName
            FOR
              XML PATH('')
            ), 1, 1, '') AS Permissions_user
   FROM @DB_USers user1
   GROUP BY dbname
     ,username
     ,logintype
     ,create_date
     ,modify_date
   ORDER BY DBName
     ,user1.LoginType
     ,username
     
SELECT username
     ,logintype
     ,create_date
     ,modify_date
     ,dbname
     ,STUFF(( SELECT ',' + CONVERT(VARCHAR(500), associatedrole)
               FROM @DB_USers user2
               WHERE user1.DBName = user2.DBName
                  AND user1.UserName = user2.UserName
            FOR
              XML PATH('')
            ), 1, 1, '') AS Permissions_user
   FROM @DB_USers user1
   WHERE user1.LoginType <> 'DATABASE_ROLE'
   GROUP BY username
     ,dbname
     ,logintype
     ,create_date
     ,modify_date
   ORDER BY username
     ,DBName    