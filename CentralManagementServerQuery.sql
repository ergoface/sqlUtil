SELECT  *,   

      TheGroup.name AS [Server Group],

      TheGroup.[Description] AS [Group Description],

      TheServer.name,

      TheServer.server_name AS [Server name],

      TheServer.[description] AS [Description]

FROM    msdb.dbo.sysmanagement_shared_server_groups_internal TheGroup

LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers_internal TheServer

      ON    TheGroup.server_group_id = TheServer.server_group_id

WHERE TheGroup.server_type = 0 --only the Database Engine Server Group

AND server_name IS NOT null

ORDER BY [Server Group], [Server name] 



SELECT * FROM    msdb.dbo.sysmanagement_shared_server_groups_internal TheGroup