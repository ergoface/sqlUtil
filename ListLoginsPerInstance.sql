/* Show all logins on a given server instance and their assigned roles */

IF CAST(SERVERPROPERTY('productversion') AS CHAR(1)) = '8'
	BEGIN
		/* SQL SERVER 2000 */
		SELECT @@servername Instance , [name] [Login], xstatus,
		isnull(db_name(dbid), 'master') DefaultDB,
		case when xstatus &4 = 4 Then 'X' else '' end NTNAME, 
		case When xstatus &16 = 16 Then 'X' else '' end Sysadmin,
		case when xstatus &32 = 32  Then 'X' else '' end securityadmin,
		case when xstatus &64 = 64 then 'X' else '' end serveradmin,
		case when xstatus &128 = 128 then 'X' else '' end setupadmin,
		case when xstatus &256 = 256 then 'X' else '' end processadmin,
		case when xstatus &512 = 512 then 'X' else '' end diskadmin,
		case when xstatus &1024 = 1024 then 'X' else '' end dbcreator,
		case when xstatus &4096 = 4096 then 'X' else '' end  bulkadmin
		 
		FROM master.dbo.sysxlogins 
		WHERE srvid IS NULL
		Order by case when xstatus &4 = 4 Then 'X' else '' end , [Name]
	END
ELSE
	BEGIN

		/*  SQL SERVER 2005+ */
		SELECT @@servername Instance , [name] [Login],loginname,
			DBNAME, IsNTNAME, IsNTGROUP, IsNTUSER, SYSADMIN, securityadmin,
			serveradmin, setupadmin, processadmin, diskadmin, dbcreator, bulkadmin
		FROM master.sys.syslogins
		ORDER BY isntname, ISNTGROUP DESC, [NAME]
	END
