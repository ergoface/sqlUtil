/* Show all orphaned user accounts (users without a matching login) */
SET NOCOUNT ON
CREATE TABLE #orph_users
   (
    db SYSNAME
   ,username SYSNAME
   ,type_desc VARCHAR(30)
   ,type VARCHAR(30)
   )
EXEC master.sys.sp_msforeachdb 'INSERT INTO #orph_users
 SELECT ''?'', u.name , u.type_desc, u.type
 FROM  [?].sys.database_principals u 
  LEFT JOIN  [?].sys.server_principals l ON u.sid = l.sid 
 WHERE l.sid IS NULL 
  AND u.type NOT IN (''A'', ''R'', ''C'') -- not a db./app. role or certificate
  AND u.principal_id > 4 -- not dbo, guest or INFORMATION_SCHEMA
  AND u.name NOT LIKE ''%DataCollector%'' 
  AND u.name NOT LIKE ''mdw%'' -- not internal users in msdb or MDW databases'
    
SELECT *
   FROM #orph_users;
DROP TABLE #orph_users

