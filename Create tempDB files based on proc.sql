/*--------------------------------------------------------------------------
Written by Mohammed Mawla, The Pythian Group
 
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF
  ANY KIND; USE IT AT YOUR OWN RESPONSIBILITY
 
  PLEASE TEST THE CODE THROUGHLY BEFORE APPLYING IT TO ANY PRODUCTION
  
  This code creates the SQL to create the appropriate number of tempdb data files based on processor count
---------------------------------------------------------------------------*/
 
USE Master
GO
SET NOCOUNT ON
GO
PRINT '-- Instance name: ' + @@servername + ' ;
/* Version: ' + @@version + ' */'
 
-- Variables
 
DECLARE @BITS BIGINT                      -- Affinty Mask
  ,@NUMPROCS SMALLINT                       -- Number of cores addressed by instance
  ,@tempdb_files_count INT                  -- Number of exisiting datafiles
  ,@tempdbdev_location NVARCHAR(4000)       -- Location of TEMPDB primary datafile
  ,@X INT                                   -- Counter
  ,@SQL NVARCHAR(MAX)
  ,@new_tempdbdev_size_MB INT               -- Size of the new files,in Megabytes
  ,@new_tempdbdev_Growth_MB INT             -- New files growth rate,in Megabytes
  ,@new_files_Location NVARCHAR(4000)
       -- New files path
 
-- Initialize variables
 
SELECT @X = 1
     ,@BITS = 1
SELECT @new_tempdbdev_size_MB = 4096              -- Four Gbytes , it's easy to increase that after file creation but harder to shrink.
     ,@new_tempdbdev_Growth_MB = 512            -- 512 Mbytes  , can be easily shrunk
     ,@new_files_Location = NULL
                -- NULL means create in same location as primary file.
 
IF OBJECT_ID('tempdb..#SVer') IS NOT NULL 
   BEGIN
      DROP TABLE #SVer
   END
CREATE TABLE #SVer
   (
    ID INT
   ,Name SYSNAME
   ,Internal_Value INT
   ,Value NVARCHAR(512)
   )
INSERT #SVer
      EXEC master.dbo.xp_msver processorCount
 
-- Get total number of Cores detected by the Operating system
 
SELECT @NUMPROCS = Internal_Value
   FROM #SVer
PRINT '-- TOTAL numbers of CPU cores on server :'
   + CAST(@NUMPROCS AS VARCHAR(5))
SET @NUMPROCS = 0
 
-- Get number of Cores addressed by instance.
 
WHILE @X <= ( SELECT Internal_Value
               FROM #SVer
            )
   AND @x <= 32 
   BEGIN
      SELECT @NUMPROCS = CASE WHEN CAST (VALUE AS INT) & @BITS > 0
                              THEN @NUMPROCS + 1
                              ELSE @NUMPROCS
                         END
         FROM sys.configurations
         WHERE NAME = 'AFFINITY MASK'
      SET @BITS = ( @BITS * 2 )
      SET @X = @X + 1
   END
 
IF ( SELECT Internal_Value
      FROM #SVer
   ) > 32 
   BEGIN
      WHILE @X <= ( SELECT Internal_Value
                     FROM #SVer
                  ) 
         BEGIN
            SELECT @NUMPROCS = CASE WHEN CAST (VALUE AS INT) & @BITS > 0
                                    THEN @NUMPROCS + 1
                                    ELSE @NUMPROCS
                               END
               FROM sys.configurations
               WHERE NAME = 'AFFINITY64 MASK'
            SET @BITS = ( @BITS * 2 )
            SET @X = @X + 1
         END
   END
 
IF @NUMPROCS = 0 
   SELECT @NUMPROCS = Internal_Value
      FROM #SVer
 
PRINT '-- Number of CPU cores Configured for usage by instance :'
   + CAST(@NUMPROCS AS VARCHAR(5))
 
-------------------------------------------------------------------------------------
-- Here you define how many files should exist per core ; Feel free to change
-------------------------------------------------------------------------------------
 
-- IF cores < 8 then no change , if between 8 & 32 inclusive then 1/2 of cores number
IF @NUMPROCS > 8
   AND @NUMPROCS <= 32 
   SELECT @NUMPROCS = @NUMPROCS / 2
 
-- IF cores > 32 then files should be 1/4 of cores number
IF @NUMPROCS > 32 
   SELECT @NUMPROCS = @NUMPROCS / 4
 
-- Get number of exisiting TEMPDB datafiles and the location of the primary datafile.
 
SELECT @tempdb_files_count = COUNT(*)
     ,@tempdbdev_location = ( SELECT REVERSE(SUBSTRING(REVERSE(physical_name),
                                                       CHARINDEX('\',
                                                              REVERSE(physical_name)),
                                                       LEN(physical_name)))
                                 FROM tempdb.sys.database_files
                                 WHERE name = 'tempdev'
                            )
   FROM tempdb.sys.database_files
   WHERE type_desc = 'Rows'
      AND state_desc = 'Online'
 
PRINT '-- Current Number of Tempdb datafiles :'
   + CAST(@tempdb_files_count AS VARCHAR(5))
 
-- Determine if we already have enough datafiles
IF @tempdb_files_count >= @NUMPROCS 
   BEGIN
      PRINT '--****Number of Recommedned datafiles is already there****'
      RETURN
   END
 
SET @new_files_Location = ISNULL(@new_files_Location, @tempdbdev_location)
 
-- Determine if the new location exists or not
DECLARE @file_results TABLE
   (
    file_exists INT
   ,file_is_a_directory INT
   ,parent_directory_exists INT
   )
 
INSERT INTO @file_results
      ( file_exists
      ,file_is_a_directory
      ,parent_directory_exists
      )
      EXEC master.dbo.xp_fileexist @new_files_Location
 
IF ( SELECT file_is_a_directory
      FROM @file_results
   ) = 0 
   BEGIN
      PRINT '-- New files Directory Does NOT exist , please specify a correct folder!'
      RETURN
   END
 
-- Determine if we have enough free space on the destination drive
 
DECLARE @FreeSpace TABLE
   (
    Drive CHAR(1)
   ,MB_Free BIGINT
   )
INSERT INTO @FreeSpace
      EXEC master..xp_fixeddrives
 
IF ( SELECT MB_Free
      FROM @FreeSpace
      WHERE drive = LEFT(@new_files_Location, 1)
   ) < @NUMPROCS * @new_tempdbdev_size_MB 
   BEGIN
      PRINT '-- WARNING: Not enough free space on '
         + UPPER(LEFT(@new_files_Location, 1))
         + ':\ to accomodate the new files. Around '
         + CAST(@NUMPROCS * @new_tempdbdev_size_MB AS VARCHAR(10))
         + ' Mbytes are needed; Please add more space or choose a new location!'
 
   END
 
-- Determine if any of the exisiting datafiles have different size than proposed ones.
IF EXISTS ( SELECT ( CONVERT (BIGINT, size) * 8 ) / 1024
               FROM tempdb.sys.database_files
               WHERE type_desc = 'Rows'
                  AND ( CONVERT (BIGINT, size) * 8 ) / 1024 <> @new_tempdbdev_size_MB ) 
   PRINT '
/*
WARNING: Some Existing datafile(s) do NOT have the same size as new ones.
It''s recommended if ALL datafiles have same size for optimal proportional-fill performance.Use ALTER DATABASE and DBCC SHRINKFILE to resize files
 
Optimizing tempdb Performance : http://msdn.microsoft.com/en-us/library/ms175527.aspx
'
 
PRINT '****Proposed New Tempdb Datafiles, PLEASE REVIEW CODE BEFORE RUNNIG  *****/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
'
-- Generate the statements
WHILE @tempdb_files_count < @NUMPROCS 
   BEGIN
 
      SELECT @SQL = 'ALTER DATABASE [tempdb] ADD FILE (NAME = N''tempdev_0'
            + CAST (@tempdb_files_count + 1 AS VARCHAR(5))
            + ''',FILENAME = N''' + @new_files_Location + 'tempdev_0'
            + CAST (@tempdb_files_count + 1 AS VARCHAR(5)) + '.ndf'',SIZE = '
            + CAST(@new_tempdbdev_size_MB AS VARCHAR(15)) + 'MB,FILEGROWTH = '
            + CAST(@new_tempdbdev_Growth_MB AS VARCHAR(15)) + 'MB )
GO'
      PRINT @SQL
      SET @tempdb_files_count = @tempdb_files_count + 1
   END    