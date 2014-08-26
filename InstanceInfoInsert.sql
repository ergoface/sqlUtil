DECLARE @ServerID INT
SELECT @ServerID = ServerId FROM DatabaseInformationTracker.dbo.Servers AS S
WHERE ServerName = SERVERPROPERTY('MachineName')

SELECT @ServerID, @@SERVERNAME, 'Unknown', CAST(SERVERPROPERTY('edition') AS VARCHAR) +
 ' - ' + CAST(SERVERPROPERTY('productversion') AS VARCHAR) + ' ' + 
 CAST(SERVERPROPERTY('productlevel') AS VARCHAR) ,  GETDATE(), SYSTEM_USER, GETDATE(), SYSTEM_USER