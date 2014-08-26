/************************************************************************
* This is a collection of scripts that can be run in a single go or separately.
*  The scripts do the following:
* 1. Check for Orphaned users in all databases in the instance
* 2. Check for Logins that lack a matching user in any database
* 3. Show all logins on the instance with their server level roles
* 4. Show users and their database roles
* 5. Show the last time SQL logins had their passwords changed
* 6. Show explicitly granted permissions to specific objects (within a single database)
*
* Collected and tweaked by Dave Bennett (@ergoface) http://datadoing.blogspot.com/
* Last Modified: 5/29/2013
************************************************************************/


/* Show all orphaned user accounts (users without a matching login) */

SELECT 'Checking for Orphaned Users';
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

/* Logins with no matching User */
SELECT 'Checking for Logins with no matching User';
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

/* Show all logins on a given server instance and their assigned roles */
SELECT 'Show Logins and their assigned server roles';

IF CAST(SERVERPROPERTY('productversion') AS CHAR(1)) = '8' 
   BEGIN
		/* SQL SERVER 2000 */
      SELECT @@servername Instance
           ,[name] [Login]
           ,xstatus
           ,ISNULL(DB_NAME(dbid), 'master') DefaultDB
           ,CASE WHEN xstatus & 4 = 4 THEN 'X'
                 ELSE ''
            END NTNAME
           ,CASE WHEN xstatus & 16 = 16 THEN 'X'
                 ELSE ''
            END Sysadmin
           ,CASE WHEN xstatus & 32 = 32 THEN 'X'
                 ELSE ''
            END securityadmin
           ,CASE WHEN xstatus & 64 = 64 THEN 'X'
                 ELSE ''
            END serveradmin
           ,CASE WHEN xstatus & 128 = 128 THEN 'X'
                 ELSE ''
            END setupadmin
           ,CASE WHEN xstatus & 256 = 256 THEN 'X'
                 ELSE ''
            END processadmin
           ,CASE WHEN xstatus & 512 = 512 THEN 'X'
                 ELSE ''
            END diskadmin
           ,CASE WHEN xstatus & 1024 = 1024 THEN 'X'
                 ELSE ''
            END dbcreator
           ,CASE WHEN xstatus & 4096 = 4096 THEN 'X'
                 ELSE ''
            END bulkadmin
         FROM master.dbo.sysxlogins
         WHERE srvid IS NULL
         ORDER BY CASE WHEN xstatus & 4 = 4 THEN 'X'
                       ELSE ''
                  END
           ,[Name]
   END
ELSE 
   BEGIN

		/*  SQL SERVER 2005+ */
      SELECT @@servername Instance
           ,[name] [Login]
           ,loginname
           ,DBNAME
           ,IsNTNAME
           ,IsNTGROUP
           ,IsNTUSER
           ,SYSADMIN
           ,securityadmin
           ,serveradmin
           ,setupadmin
           ,processadmin
           ,diskadmin
           ,dbcreator
           ,bulkadmin
         FROM master.sys.syslogins
         ORDER BY isntname
           ,ISNTGROUP DESC
           ,[NAME]
   END
go	
	
/***** List Users (as opposed to logins) and which DB they exist in and what DB Roles they are assigned in a given instance  *****/
SELECT 'Show users and their DB Roles across all DBs in the instance';

IF OBJECT_ID('Tempdb..#Userlist') IS NOT NULL 
   DROP TABLE #UserList;
	
CREATE TABLE #UserList
   (
    DB VARCHAR(100)
   ,UserName VARCHAR(100)
   ,RoleName VARCHAR(30)
   );
 
DECLARE @cmdtxt VARCHAR(4000)

SET @cmdtxt = ' Insert into #UserList
				select ''?'' as DB, b.name as USERName, c.name as RoleName 
      			from [?].dbo.sysmembers a  
				join [?].dbo.sysusers  b 
       				on a.memberuid = b.uid 	
       			join [?].dbo.sysusers c
					on a.groupuid = c.uid'
--EXEC master.dbo.sp_foreachdb @command =@cmdtxt
EXEC sp_MSForEachDB @cmdtxt
SELECT UserName
     ,DB
     ,RoleName
   FROM #UserList AS UL
   ORDER BY UserName
     ,DB	

GO
SELECT 'Show the last time the password was changed for all SQL Logins';
/* Show status and last password set on all SQL Logins*/
USE Master
GO
SELECT [name]
     ,sid
     ,create_date
     ,modify_date
     ,LOGINPROPERTY([name], 'PasswordLastSetTime') AS 'PasswordLastSetTime'
     ,DATEDIFF(DAY,
               CAST(LOGINPROPERTY([name], 'PasswordLastSetTime') AS DATETIME),
               GETDATE()) DaysSinceChange
     ,is_disabled
   FROM sys.sql_logins

GO	

 /* Explicit Permissions on objects */
SELECT 'Show explicit Object permissions in a given database';

SELECT dp.Class
     ,dps1.Name AS Grantee
     ,dps1.type_desc
     ,dps2.Name AS Grantor
     ,so.Name
     ,so.Type
     ,dp.Permission_Name
     ,dp.State_Desc
   FROM sys.database_permissions AS dp
      JOIN Sys.Database_Principals dps1
         ON dp.grantee_Principal_ID = dps1.Principal_ID
      JOIN Sys.Database_Principals dps2
         ON dp.grantor_Principal_ID = dps2.Principal_ID 
      JOIN sys.objects AS so
         ON dp.major_id = so.object_id
    --WHERE so.Name = '<Name of Proc>'
/*Best Regards, Uri Dimant SQL Server MVP 
http://dimantdatabasesolutions.blogspot.com/ 
http://sqlblog.com/blogs/uri_dimant/ */