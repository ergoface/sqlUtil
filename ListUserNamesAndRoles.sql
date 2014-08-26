 --List UserNames and Roles for a given database
 
 declare @dbName varchar(100)
 --set @dbName = 'ksar_marketing'
 set @dbName = 'ksar_coxone'
 exec ('select b.name as USERName, c.name as RoleName 
      	from ' + @dbName+'.dbo.sysmembers a '+ 
			'	join '+ @dbName+'.dbo.sysusers  b '+ 
       	'	on a.memberuid = b.uid 	join '+@dbName +'.dbo.sysusers c
	         on a.groupuid = c.uid')
