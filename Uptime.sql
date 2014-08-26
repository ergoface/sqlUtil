/*** Displays the Restart Date & Server Status for a given instance ****/
USE master
go
SET NOCOUNT ON
DECLARE @crdate DATETIME, @hr VARCHAR(50), @min VARCHAR(5)
--SELECT crdate RestartDate FROM sysdatabases WHERE NAME='tempdb'
SELECT @crdate=crdate FROM sysdatabases WHERE NAME='tempdb'
SELECT @hr=(DATEDIFF ( mi, @crdate,GETDATE()))/60
IF ((DATEDIFF ( mi, @crdate,GETDATE()))/60)=0
SELECT @min=(DATEDIFF ( mi, @crdate,GETDATE()))
ELSE
SELECT @min=(DATEDIFF ( mi, @crdate,GETDATE()))-((DATEDIFF( mi, @crdate,GETDATE()))/60)*60
PRINT 'SQL Server "' + CONVERT(VARCHAR(50),SERVERPROPERTY('SERVERNAME'))+ '" Was restarted on: ' + CAST(@crdate AS VARCHAR(20)) + ', Now Online for the past '+@hr+' hours & '+@min+' minutes'
IF NOT EXISTS (SELECT 1 FROM master.dbo.sysprocesses WHERE program_name = N'SQLAgent - Generic Refresher')
BEGIN
PRINT 'SQL Server is running but SQL Server Agent <<NOT>> running'
END
ELSE BEGIN
PRINT 'SQL Server and SQL Server Agent both are running'
END