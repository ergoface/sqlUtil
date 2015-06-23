/******Log file shrink and grow routine to fix VLF structure on your log file
 Change DB name and file to appropriate db. If In Full or Bulk_Logged mode, do a log backup. This is currently configured for Simple
******/

USE TimeOffTracker /*============= Change database Name before running any further =============================*/
GO
/************************************* Check current status *******************************/
SELECT size / 128 SizeInMeg,* FROM sys.database_files AS DF /* Check Log file name and physical name and current sizes */
SELECT D.recovery_model_desc FROM sys.databases AS D
WHERE D.name = DB_NAME()
DBCC loginfo /* Display current log file layout*/
/* Check database integrity*/
DBCC CHECKDB WITH NO_INFOMSGS
/******************************************************************************************/





/* Write any open transactions*/ 
CHECKPOINT
/*********************************************
*                                            *
*   If This is a Full or Bulk logged DB,     *
*    Do a log back before proceeding         *
*                                            *
**********************************************/

/* Check for open transactions*/
DBCC OPENTRAN 
/**** If there are open transactions the below actions will not work !!!  ****************/





/************** Shrink the log, then resize it to your desired size **********************/

DECLARE @LogName NVARCHAR(255),
        @SQL NVARCHAR(4000),
		@LogSize NVARCHAR(5); 
SELECT @LogName = [name] FROM sys.database_files WHERE type_desc = 'LOG'


SET @LogSize = '300'; /*Set desired log size here, in MB */


DBCC SHRINKFILE(@LogName, TRUNCATEONLY) 
SELECT size / 128 SizeInMeg,* FROM sys.database_files AS DF
DBCC loginfo
SET @SQL = '
ALTER DATABASE ' + DB_NAME() + '
MODIFY FILE
( NAME = ''' + @LogName + '''
  , SIZE = ' + @LogSize + '
)';
EXEC (@SQL);