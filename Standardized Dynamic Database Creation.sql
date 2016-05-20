/**************************************************************************************
* Description:Create DB script for   <XXXXXXX> database.
* Author: Dave Bennett
* Created: 9/30/2014
* Last Updated: 6/26/2015
* Relies on: N/A
* Modifies: Drops existing database if it exists
***************************************************************************************/

USE [master]
GO
/************************************************************
* Instructions:
* 1.) Set the @DataDrive and @LogDrive folders to the appropriate location for the deploy environment.
* 2.) Change the @DBName to the name of the database being created/deployed.
* 3.) If filestream is needed, change the value of the @NeedFileStream flag to 1.
*
*************************************************************/
DECLARE
        @DataDrive NVARCHAR(100)              = N'U:' /* Specify Root data location */
      , @LogDrive NVARCHAR(100)               = N'V:' /* Specify Root Log location */
      , @DBName NVARCHAR(50)                  = N'LASsNTP' /* Database Name used for all directory and file creation */
      , @NeedFileStream BIT                   = 0  /* If this database will use Filestream set to 1 */
	  , @UserDataSize NVARCHAR(50)            = N'6MB' /* Initial Size of user data file*/
	  , @UserDataGrowthAmount NVARCHAR(50)    = N'10MB' /* Growth increment for user data file */
	  , @LogSize NVARCHAR(20)                 = N'6MB' /* Initial Size of log file */
	  , @LogGrowthAmount NVARCHAR(20)         = N'16MB' /* Growth increment for log file */
      , @FilestreamFolder NVARCHAR(300) 
	  , @DirCheck NVARCHAR(100)
	  , @DataFile NVARCHAR(300)
      , @UserData NVARCHAR(300)
      , @LogFile NVARCHAR(300)
      , @DirExists BIT		   = 0
      , @SQL NVARCHAR(2048);
SET @DirCheck = @DataDrive + N'\Data\' + @DBName;
SET @DataFile = @DirCheck + N'\' + @DBName + N'.mdf';
SET @UserData = @DirCheck + N'\' + +@DBName + N'_UserData.ndf';

/*** Check to see if the Data directory exists. If not, attempt to create it ***/
DECLARE @file_results TABLE
        (
          file_exists INT
        , file_is_a_directory INT
        , parent_directory_exists INT
        );
 
INSERT INTO @file_results
        (
          file_exists
        , file_is_a_directory
        , parent_directory_exists
        )
        EXEC master.dbo.xp_fileexist @DirCheck

SELECT
        @DirExists = FR.file_is_a_directory
    FROM
        @file_results AS FR
IF @DirExists = 0
   BEGIN
         PRINT 'Directory does not exist, creating new one'
         EXECUTE master.dbo.xp_create_subdir @DirCheck
         PRINT @DirCheck + N' created on ' + @@servername
   END  
DELETE
        @file_results

/*** Check to see if the Log directory exists. If not, attempt to create it ***/
SET @DirCheck = @LogDrive + N'\TLog\' + @DBName;
INSERT INTO @file_results
        (
          file_exists
        , file_is_a_directory
        , parent_directory_exists
        )
        EXEC master.dbo.xp_fileexist @DirCheck

SELECT
        @DirExists = FR.file_is_a_directory
    FROM
        @file_results AS FR
IF @DirExists = 0
   BEGIN
         PRINT 'Directory does not exist, creating new one'
         EXECUTE master.dbo.xp_create_subdir @DirCheck
         PRINT @DirCheck + N' created on ' + @@servername
   END 
SET @LogFile = @DirCheck + N'\' + @DBName + N'_log.ldf'

/*** Check to see if we are doing filestream and set directory if needed. ***/
IF @NeedFileStream = 1 
   BEGIN
		SET @FilestreamFolder = @DataDrive + N'\Data\' + @DBName + N'\Upload';
   END

USE [master];

/* We have to use Dynamic SQL because TSQL is too stupid to allow vairables in database manipulation commands */
/****** Drop database if it exists ******/
IF EXISTS ( SELECT
                    name
                FROM
                    sys.databases
                WHERE
                    name = @DBName )
   BEGIN
         SET @SQL = 'DROP DATABASE ' + @DBName;
         EXEC sys.sp_executesql @SQL;
   END	


/****** Create Database    ******/
IF @NeedFileStream = 1
	BEGIN
		SET @SQL = '
		CREATE DATABASE ' + @DBName + ' ON PRIMARY 
		( NAME = ''' + @DBName + ''', FILENAME = N''' + @DataFile
			+ ''' , SIZE = 4096KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB ),
			FILEGROUP [UserData] DEFAULT
		( NAME = N''' + @DBName + '_UserData'', FILENAME = N''' + @UserData
			+ ''' , SIZE = ' + @UserDataSize + ' , MAXSIZE = UNLIMITED, FILEGROWTH = ' +  @UserDataGrowthAmount + ' ),
			FILEGROUP [' + @DBName + '_Filestream] CONTAINS FILESTREAM  DEFAULT
        ( NAME = N''' + @DBName + '_Filestream'', FILENAME = N''' + @FilestreamFolder + ''' , MAXSIZE = UNLIMITED)
			LOG ON 
		( NAME = N''' + @DBName + '_log'', FILENAME = N''' + @LogFile
			+ ''' , SIZE = '+  @LogSize + ' , MAXSIZE = 2048GB , FILEGROWTH = ' + @LogGrowthAmount + ' )
		'
	END
ELSE
	BEGIN	
		SET @SQL = '
		CREATE DATABASE ' + @DBName + ' ON PRIMARY 
		( NAME = ''' + @DBName + ''', FILENAME = N''' + @DataFile
			+ ''' , SIZE = 4096KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB ),
			FILEGROUP [UserData] DEFAULT
		( NAME = N''' + @DBName + '_UserData'', FILENAME = N''' + @UserData
			+ ''' , SIZE = ' + @UserDataSize + ' , MAXSIZE = UNLIMITED, FILEGROWTH = ' +  @UserDataGrowthAmount + ' )
			LOG ON 
		( NAME = N''' + @DBName + '_log'', FILENAME = N''' + @LogFile
			+ ''' , SIZE = '+  @LogSize + ' , MAXSIZE = 2048GB , FILEGROWTH = ' + @LogGrowthAmount + ' )
		'
	END
EXEC sys.sp_executesql @SQL;

SET @SQL = '
ALTER DATABASE ' + @DBName + ' SET COMPATIBILITY_LEVEL = 110;
ALTER DATABASE ' + @DBName + ' SET RECOVERY FULL;
ALTER AUTHORIZATION ON DATABASE::' + @DBName + ' TO sa;
'
EXEC sys.sp_executesql @SQL;
