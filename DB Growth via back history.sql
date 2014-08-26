/*** Database Size Growth Query ****/
IF OBJECT_ID('tempdb..#dbs') > 0 
    DROP TABLE #dbs
IF OBJECT_ID('tempdb..#Drives') > 0 
    DROP TABLE #Drives
IF OBJECT_ID('tempdb..#Results') > 0 
    DROP TABLE #Results

CREATE TABLE #dbs
(
  DBNAME sysname
, DBID INT
, [Total Size in MB] INT
, [Available Space In MB] INT
, DriveLetter CHAR(1)
)

INSERT INTO
    #dbs
    (
      DBNAME
    , DBID
    , [Total Size in MB]
    , [Available Space In MB]
    , DriveLetter
    )
    EXEC sp_MSforeachdb '
		USE [?];

		SELECT
			DB_NAME() As DBNAME
		  , DB_ID() AS DBID
		  , SUM(size / 128) AS ''Total Size in MB''
		  , SUM(size / 128 - CAST(FILEPROPERTY(name , ''SpaceUsed'') AS int) / 128) AS ''Available Space In MB''
		  , LEFT(physical_name, 1) AS DriveLetter
		FROM
			[?].sys.database_files
		WHERE
			type_desc = ''ROWS''
		GROUP BY LEFT(physical_name, 1)    
	'

CREATE TABLE #Drives
(
  DriverLetter CHAR(1) PRIMARY KEY CLUSTERED
, FreeMBs INT NOT NULL
, FreeGBs AS CONVERT(DECIMAL(18 , 2) , FreeMBs / 1024.0)
)

INSERT INTO
    #Drives ( DriverLetter , FreeMBs )
    EXEC xp_fixeddrives


--
--SELECT
--    DB_NAME() As DBNAME
--  , DB_ID() AS DBID
--  , SUM(size / 128) AS 'Total Size in MB'
--  , SUM(size / 128 - CAST(FILEPROPERTY(name , 'SpaceUsed') AS int) / 128) AS 'Available Space In MB'
--FROM
--    sys.database_files
--WHERE
--    type_desc = 'ROWS'


--Rémi : I deleted 4 logging tables I had build on March 25th, hence the ±350 MB drop.
;
WITH    CTE_Backups ( database_name,  backup_start_date
                , backup_finish_date,BackupDate, MinutesForBackup
           , GB_backup_size
           , seqFirst, seqLast )
          AS (
               SELECT
                bs.database_name
                , bs.backup_start_date
                , bs.backup_finish_date
              , DATEADD(D , 0 , DATEDIFF(D , 0 , bs.backup_start_date)) AS BackupDate
              , CONVERT(DECIMAL(18 , 5) , DATEDIFF(s , bs.backup_start_date ,
                                                   bs.backup_finish_date)
                / 60.0) AS MinutesForBackup
              , CONVERT(DECIMAL(18 , 3) , bs.backup_size / 1024 / 1024 / 1024) AS GB_backup_size
              , ROW_NUMBER() OVER ( PARTITION BY bs.database_name ORDER BY bs.backup_start_date ) AS seqFirst
              , ROW_NUMBER() OVER ( PARTITION BY bs.database_name ORDER BY bs.backup_start_date DESC ) AS seqLast
               FROM
                msdb.dbo.backupset bs
               WHERE
                name IS NOT NULL
                AND bs.[type] = 'D'
             )
    SELECT
        CONVERT(INT , dtBackups.[Available Space In GB]
        / CASE WHEN dtBackups.GB_ExpectedDailyGrowth <> 0
               THEN dtBackups.GB_ExpectedDailyGrowth
               ELSE 0.0001
          END) AS DaysUntillDBGrowth
      , *
     -- *
--    INTO
--        #Results
    FROM
        (
          SELECT
            a.database_name
          , dbs.DriveLetter
          , drv.FreeGBs AS FreeGBs_Drive
          , a.BackupDate AS BackupDate_First
          , b.BackupDate AS BackupDate_Last
          , DATEDIFF(dd , a.BackupDate , b.BackupDate) AS DaysPeriod
          , a.MinutesForBackup AS MinutesForBackup_First
          , b.MinutesForBackup AS MinutesForBackup_Last
          , b.MinutesForBackup - a.MinutesForBackup AS MinutesForBackup_Delta
          , a.GB_backup_size AS GB_backup_size_First
          , b.GB_backup_size AS GB_backup_size_Last
          , b.GB_backup_size - a.GB_backup_size AS GB_BackupGrowth
          , a.seqLast - a.seqFirst AS QtyofBackups
          , CASE WHEN CONVERT(DECIMAL(18 , 3) , ( b.GB_backup_size - a.GB_backup_size )) > .001 Then
            CONVERT(DECIMAL(18 , 3) , ( b.GB_backup_size - a.GB_backup_size )
            / DATEDIFF(dd , a.BackupDate , b.BackupDate)) 
            ELSE 0 END AS GB_ExpectedDailyGrowth
          , CASE WHEN CONVERT(DECIMAL(18 , 3) , ( b.GB_backup_size - a.GB_backup_size )) > .001 Then
            CONVERT(DECIMAL(18 , 3) , ( b.GB_backup_size - a.GB_backup_size )
            / DATEDIFF(dd , a.BackupDate , b.BackupDate) * 365.256) 
            ELSE 0 END AS GB_ExpectedAnnualGrowth
          , CONVERT(DECIMAL(18 , 3) , dbs.[Total Size in MB] / 1024.0) AS [Total Size in GB]
          , CONVERT(DECIMAL(18 , 3) , dbs.[Available Space In MB] / 1024.0) AS [Available Space In GB]
          FROM
            CTE_Backups a
            INNER JOIN CTE_Backups b
                ON a.seqFirst = b.seqLast
                   AND a.seqLast = b.seqFirst
                   AND a.database_name = b.database_name
            INNER JOIN #dbs dbs
                ON b.database_name = dbs.DBNAME
            INNER JOIN #Drives drv
                ON dbs.DriveLetter = drv.DriverLetter
          WHERE
            a.seqFirst = 1
        ) dtBackups
    ORDER BY
        database_name
        
        
        SELECT * FROM sys.database_files AS DF