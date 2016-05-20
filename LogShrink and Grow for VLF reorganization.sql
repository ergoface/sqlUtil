/************************************************************************************************
Log file shrink and grow routine to fix VLF structure on your log file
 Change DB name and file to appropriate db. If In Full or Bulk_Logged mode, do a log backup. 
 This is currently configured for Simple recovery mode databases
 Author: Dave Bennett
 Last Modified: 4/21/2016
************************************************************************************************/

 /*============= Change database Name before running any further =============================*/
USE OfficeOnlyDiscos;
GO

/************************************* Check current status *******************************/
SELECT DF.size / 128 SizeInMeg
      , DF.file_id
      , DF.file_guid
      , DF.type
      , DF.type_desc
      , DF.data_space_id
      , DF.name
      , DF.physical_name
      , DF.state
      , DF.state_desc
      , DF.size
      , DF.max_size
      , DF.growth
      , DF.is_media_read_only
      , DF.is_read_only
      , DF.is_sparse
      , DF.is_percent_growth
FROM sys.database_files AS DF;

 /* Check Log file name and physical name and current sizes */
SELECT D.recovery_model_desc
FROM sys.databases AS D
  WHERE D.name = DB_NAME();
 /* Display current log file VLF layout*/
DBCC loginfo;

/* Check database integrity*/
DBCC CHECKDB WITH NO_INFOMSGS, PHYSICAL_ONLY;
/******************************************************************************************/





/* Write any open transactions*/ 
CHECKPOINT;
/*********************************************
*                                            *
*   If This is a Full or Bulk logged DB,     *
*    Do a log back before proceeding         *
*                                            *
**********************************************/

/* Check for open transactions*/
DBCC OPENTRAN; 
/**** If there are open transactions the below actions will not work !!!  ****************/





/************** Shrink the log(s), then resize it to your desired size **********************/

DECLARE @LogName NVARCHAR(255)
  , @SQL NVARCHAR(4000)
  , @LogSize NVARCHAR(6); 
 /*Set desired log size here, in MB */
SET @LogSize = '256';

/* As there might be more than one log file, use a cursor to loop through all and resize them to the same size */
DECLARE Cur CURSOR STATIC FORWARD_ONLY
FOR
SELECT [name]
    FROM sys.database_files
    WHERE type_desc = 'LOG';
OPEN Cur;
FETCH NEXT FROM Cur INTO @LogName;
WHILE @@FETCH_STATUS = 0
    BEGIN
        DBCC SHRINKFILE(@LogName, TRUNCATEONLY); 
        SELECT DF.size / 128 SizeInMeg
              , *
            FROM sys.database_files AS DF;
        DBCC loginfo;
        SET @SQL = '
					ALTER DATABASE ' + DB_NAME() + '
					MODIFY FILE
					( NAME = ''' + @LogName + '''
					  , SIZE = ' + @LogSize + '
					)';
        EXEC (@SQL);
        FETCH NEXT FROM Cur INTO @LogName;
    END;
SELECT 'Post Resized Info' Info;
SELECT DF.size / 128 SizeInMeg
      , DF.file_id
      , DF.file_guid
      , DF.type
      , DF.type_desc
      , DF.data_space_id
      , DF.name
      , DF.physical_name
      , DF.state
      , DF.state_desc
      , DF.size
      , DF.max_size
      , DF.growth
      , DF.is_media_read_only
      , DF.is_read_only
      , DF.is_sparse
      , DF.is_percent_growth
    FROM sys.database_files AS DF;
DBCC loginfo;
CLOSE Cur;
DEALLOCATE Cur;