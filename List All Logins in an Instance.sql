/* List all Logins on a given Instance */
SELECT @@SERVERNAME Server
,CASE WHEN type = 'S' THEN 'SQL'
	  WHEN type = 'U' THEN 'AD'
	  WHEN	type = 'G' THEN 'AD Group'
	END	LoginType
,name UserName
FROM sys.server_principals 
WHERE TYPE IN ('U', 'S', 'G')
and name not like '%##%'
ORDER BY Logintype, UserName