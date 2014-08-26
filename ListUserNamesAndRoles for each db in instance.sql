/***** List Users (as opposed to logins) and which DB they exist in and what DB Roles they are assigned in a given instance  *****/

 IF OBJECT_ID('Tempdb..#Userlist') IS NOT NULL
	DROP TABLE #UserList;
	
 CREATE TABLE #UserList (DB VARCHAR(100), UserName VARCHAR(100), RoleName VARCHAR(30));
 
 declare @cmdtxt varchar(4000)

 SET @cmdtxt = ' Insert into #UserList
				select ''?'' as DB, b.name as USERName, c.name as RoleName 
      			from [?].dbo.sysmembers a  
				join [?].dbo.sysusers  b 
       				on a.memberuid = b.uid 	
       			join [?].dbo.sysusers c
					on a.groupuid = c.uid'
--EXEC master.dbo.sp_foreachdb @command =@cmdtxt
EXEC sp_MSForEachDB @cmdtxt
SELECT UserName, DB, RoleName FROM  #UserList AS UL	
ORDER BY UserName, DB				
