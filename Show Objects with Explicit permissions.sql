/*Find explict permissions on objects in a database */

SELECT
dp.Class,
dps1.Name As Grantee,
dps1.type_desc,
dps2.Name As Grantor,
so.Name,
so.Type,
dp.Permission_Name,
dp.State_Desc
FROM sys.database_permissions AS dp
JOIN Sys.Database_Principals dps1
ON dp.grantee_Principal_ID = dps1.Principal_ID
JOIN Sys.Database_Principals dps2
ON dp.grantor_Principal_ID = dps2.Principal_ID
    JOIN sys.objects AS so
    ON dp.major_id = so.object_id
    --WHERE so.Name = 'UpdateStock'
--Best Regards, Uri Dimant SQL Server MVP http://dimantdatabasesolutions.blogspot.com/ http://sqlblog.com/blogs/uri_dimant/

USE DBA
GO
GRANT EXEC ON dbo.GenInstanceDBInfo TO SSRS_RO  