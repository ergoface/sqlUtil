/* Show status and last password set on all SQL Logins*/
USE Master
GO
SELECT [name]
     ,sid
     ,create_date
     ,modify_date
     ,LOGINPROPERTY([name], 'PasswordLastSetTime') AS 'PasswordLastSetTime'
     ,DATEDIFF(DAY,CAST(LOGINPROPERTY([name], 'PasswordLastSetTime') AS datetime) ,GETDATE()) DaysSinceChange
     ,is_disabled
   FROM sys.sql_logins

GO