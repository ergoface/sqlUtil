/************************
* This will list all SQL Agent Jobs on the current Server
* Works for SQL 2000+
*************************/

USE msdb ;
GO

EXEC dbo.sp_help_job ;
GO
