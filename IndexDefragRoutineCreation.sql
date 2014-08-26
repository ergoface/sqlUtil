/************************************************************************
* Script to setup Index Defrag routine
* Author: see below
* Implemented in the DBAUtil database
* Last Modified: 2/10/2011
*************************************************************************/
/* Scroll down to the see notes, disclaimers, and licensing information */

Declare @indexDefragLog_rename      varchar(128)
    , @indexDefragExclusion_rename  varchar(128)
    , @indexDefragStatus_rename     varchar(128);

Select @indexDefragLog_rename       = 'dba_indexDefragLog_obsolete_' + Convert(varchar(10), GetDate(), 112)
    , @indexDefragExclusion_rename  = 'dba_indexDefragExclusion_obsolete_' + Convert(varchar(10), GetDate(), 112)
    , @indexDefragStatus_rename     = 'dba_indexDefragStatus_obsolete_' + Convert(varchar(10), GetDate(), 112);

If Exists(Select [object_id] From sys.tables Where [name] = 'dba_indexDefragLog')
    Execute sp_rename dba_indexDefragLog, @indexDefragLog_rename;

If Exists(Select [object_id] From sys.tables Where [name] = 'dba_indexDefragExclusion')
    Execute sp_rename dba_indexDefragExclusion, @indexDefragExclusion_rename;

If Exists(Select [object_id] From sys.tables Where [name] = 'dba_indexDefragStatus')
    Execute sp_rename dba_indexDefragStatus, @indexDefragStatus_rename;
Go

Create Table dbo.dba_indexDefragLog
(
      indexDefrag_id    int identity(1,1)   Not Null
    , databaseID        int                 Not Null
    , databaseName      nvarchar(128)       Not Null
    , objectID          int                 Not Null
    , objectName        nvarchar(128)       Not Null
    , indexID           int                 Not Null
    , indexName         nvarchar(128)       Not Null
    , partitionNumber   smallint            Not Null
    , fragmentation     float               Not Null
    , page_count        int                 Not Null
    , dateTimeStart     datetime            Not Null
    , dateTimeEnd       datetime            Null
    , durationSeconds   int                 Null
    , sqlStatement      varchar(4000)       Null
    , errorMessage      varchar(1000)       Null
    
    Constraint PK_indexDefragLog_v40
        Primary Key Clustered (indexDefrag_id)
);

Print 'dba_indexDefragLog Table Created';

Create Table dbo.dba_indexDefragExclusion
(
      databaseID        int                 Not Null
    , databaseName      nvarchar(128)       Not Null
    , objectID          int                 Not Null
    , objectName        nvarchar(128)       Not Null
    , indexID           int                 Not Null
    , indexName         nvarchar(128)       Not Null
    , exclusionMask     int                 Not Null
        /* 1=Sunday, 2=Monday, 4=Tuesday, 8=Wednesday, 16=Thursday, 32=Friday, 64=Saturday */

    Constraint PK_indexDefragExclusion_v40
        Primary Key Clustered (databaseID, objectID, indexID)
);

Print 'dba_indexDefragExclusion Table Created';

Create Table dbo.dba_indexDefragStatus
(
      databaseID        int
    , databaseName      nvarchar(128)
    , objectID          int
    , indexID           int
    , partitionNumber   smallint
    , fragmentation     float
    , page_count        int
    , range_scan_count  bigint
    , schemaName        nvarchar(128)   Null
    , objectName        nvarchar(128)   Null
    , indexName         nvarchar(128)   Null
    , scanDate          datetime        
    , defragDate        datetime        Null
    , printStatus       bit             Default(0)
    , exclusionMask     int             Default(0)
    
    Constraint PK_indexDefragStatus_v40
        Primary Key Clustered(databaseID, objectID, indexID, partitionNumber)
);

Print 'dba_indexDefragStatus Table Created';

If ObjectProperty(Object_ID('dbo.dba_indexDefrag_sp'), N'IsProcedure') = 1
Begin
    Drop Procedure dbo.dba_indexDefrag_sp;
    Print 'Procedure dba_indexDefrag_sp dropped';
End;
Go

Create Procedure dbo.dba_indexDefrag_sp

    /* Declare Parameters */
      @minFragmentation     float           = 10.0  
        /* in percent, will not defrag if fragmentation less than specified */
    , @rebuildThreshold     float           = 30.0  
        /* in percent, greater than @rebuildThreshold will result in rebuild instead of reorg */
    , @executeSQL           bit             = 1     
        /* 1 = execute; 0 = print command only */
    , @defragOrderColumn    nvarchar(20)    = 'range_scan_count'
        /* Valid options are: range_scan_count, fragmentation, page_count */
    , @defragSortOrder      nvarchar(4)     = 'DESC'
        /* Valid options are: ASC, DESC */
    , @timeLimit            int             = 720 /* defaulted to 12 hours */
        /* Optional time limitation; expressed in minutes */
    , @database             varchar(128)    = Null
        /* Option to specify a database name; null will return all */
    , @tableName            varchar(4000)   = Null  -- databaseName.schema.tableName
        /* Option to specify a table name; null will return all */
    , @forceRescan          bit             = 0
        /* Whether or not to force a rescan of indexes; 1 = force, 0 = use existing scan, if available */
    , @scanMode             varchar(10)     = N'LIMITED'
        /* Options are LIMITED, SAMPLED, and DETAILED */
    , @minPageCount         int             = 8 
        /*  MS recommends > 1 extent (8 pages) */
    , @maxPageCount         int             = Null
        /* NULL = no limit */
    , @excludeMaxPartition  bit             = 0
        /* 1 = exclude right-most populated partition; 0 = do not exclude; see notes for caveats */
    , @onlineRebuild        bit             = 1     
        /* 1 = online rebuild; 0 = offline rebuild; only in Enterprise */
    , @sortInTempDB         bit             = 1
        /* 1 = perform sort operation in TempDB; 0 = perform sort operation in the index's database */
    , @maxDopRestriction    tinyint         = Null
        /* Option to restrict the number of processors for the operation; only in Enterprise */
    , @printCommands        bit             = 0     
        /* 1 = print commands; 0 = do not print commands */
    , @printFragmentation   bit             = 0
        /* 1 = print fragmentation prior to defrag; 
           0 = do not print */
    , @defragDelay          char(8)         = '00:00:05'
        /* time to wait between defrag commands */
    , @debugMode            bit             = 0
        /* display some useful comments to help determine if/where issues occur */

As
/*********************************************************************************
    Name:       dba_indexDefrag_sp

    Author:     Michelle Ufford, http://sqlfool.com

    Purpose:    Defrags one or more indexes for one or more databases

    Notes:

    CAUTION: TRANSACTION LOG SIZE SHOULD BE MONITORED CLOSELY WHEN DEFRAGMENTING.
             DO NOT RUN UNATTENDED ON LARGE DATABASES DURING BUSINESS HOURS.

      @minFragmentation     defaulted to 10%, will not defrag if fragmentation 
                            is less than that
      
      @rebuildThreshold     defaulted to 30% as recommended by Microsoft in BOL;
                            greater than 30% will result in rebuild instead

      @executeSQL           1 = execute the SQL generated by this proc; 
                            0 = print command only

      @defragOrderColumn    Defines how to prioritize the order of defrags.  Only
                            used if @executeSQL = 1.  
                            Valid options are: 
                            range_scan_count = count of range and table scans on the
                                               index; in general, this is what benefits 
                                               the most from defragmentation
                            fragmentation    = amount of fragmentation in the index;
                                               the higher the number, the worse it is
                            page_count       = number of pages in the index; affects
                                               how long it takes to defrag an index

      @defragSortOrder      The sort order of the ORDER BY clause.
                            Valid options are ASC (ascending) or DESC (descending).

      @timeLimit            Optional, limits how much time can be spent performing 
                            index defrags; expressed in minutes.

                            NOTE: The time limit is checked BEFORE an index defrag
                                  is begun, thus a long index defrag can exceed the
                                  time limitation.

      @database             Optional, specify specific database name to defrag;
                            If not specified, all non-system databases will
                            be defragged.

      @tableName            Specify if you only want to defrag indexes for a 
                            specific table, format = databaseName.schema.tableName;
                            if not specified, all tables will be defragged.

      @forceRescan          Whether or not to force a rescan of indexes.  If set
                            to 0, a rescan will not occur until all indexes have
                            been defragged.  This can span multiple executions.
                            1 = force a rescan
                            0 = use previous scan, if there are indexes left to defrag

      @scanMode             Specifies which scan mode to use to determine
                            fragmentation levels.  Options are:
                            LIMITED - scans the parent level; quickest mode,
                                      recommended for most cases.
                            SAMPLED - samples 1% of all data pages; if less than
                                      10k pages, performs a DETAILED scan.
                            DETAILED - scans all data pages.  Use great care with
                                       this mode, as it can cause performance issues.

      @minPageCount         Specifies how many pages must exist in an index in order 
                            to be considered for a defrag.  Defaulted to 8 pages, as 
                            Microsoft recommends only defragging indexes with more 
                            than 1 extent (8 pages).  

                            NOTE: The @minPageCount will restrict the indexes that
                            are stored in dba_indexDefragStatus table.

      @maxPageCount         Specifies the maximum number of pages that can exist in 
                            an index and still be considered for a defrag.  Useful
                            for scheduling small indexes during business hours and
                            large indexes for non-business hours.

                            NOTE: The @maxPageCount will restrict the indexes that
                            are defragged during the current operation; it will not
                            prevent indexes from being stored in the 
                            dba_indexDefragStatus table.  This way, a single scan
                            can support multiple page count thresholds.

      @excludeMaxPartition  If an index is partitioned, this option specifies whether
                            to exclude the right-most populated partition.  Typically,
                            this is the partition that is currently being written to in
                            a sliding-window scenario.  Enabling this feature may reduce
                            contention.  This may not be applicable in other types of 
                            partitioning scenarios.  Non-partitioned indexes are 
                            unaffected by this option.
                            1 = exclude right-most populated partition
                            0 = do not exclude

      @onlineRebuild        1 = online rebuild; 
                            0 = offline rebuild

      @sortInTempDB         Specifies whether to defrag the index in TEMPDB or in the
                            database the index belongs to.  Enabling this option may
                            result in faster defrags and prevent database file size 
                            inflation.
                            1 = perform sort operation in TempDB
                            0 = perform sort operation in the index's database 

      @maxDopRestriction    Option to specify a processor limit for index rebuilds

      @printCommands        1 = print commands to screen; 
                            0 = do not print commands

      @printFragmentation   1 = print fragmentation to screen;
                            0 = do not print fragmentation

      @defragDelay          Time to wait between defrag commands; gives the
                            server a little time to catch up 

      @debugMode            1 = display debug comments; helps with troubleshooting
                            0 = do not display debug comments

    Called by:  SQL Agent Job or DBA

    ----------------------------------------------------------------------------
    DISCLAIMER: 
    This code and information are provided "AS IS" without warranty of any kind,
    either expressed or implied, including but not limited to the implied 
    warranties or merchantability and/or fitness for a particular purpose.
    ----------------------------------------------------------------------------
    LICENSE: 
    This index defrag script is free to download and use for personal, educational, 
    and internal corporate purposes, provided that this header is preserved. 
    Redistribution or sale of this index defrag script, in whole or in part, is 
    prohibited without the author's express written consent.
    ----------------------------------------------------------------------------
    Date        Initials	Version Description
    ----------------------------------------------------------------------------
    2007-12-18  MFU         1.0     Initial Release
    2008-10-17  MFU         1.1     Added @defragDelay, CIX_temp_indexDefragList
    2008-11-17  MFU         1.2     Added page_count to log table
                                    , added @printFragmentation option
    2009-03-17  MFU         2.0     Provided support for centralized execution
                                    , consolidated Enterprise & Standard versions
                                    , added @debugMode, @maxDopRestriction
                                    , modified LOB and partition logic  
    2009-06-18  MFU         3.0     Fixed bug in LOB logic, added @scanMode option
                                    , added support for stat rebuilds (@rebuildStats)
                                    , support model and msdb defrag
                                    , added columns to the dba_indexDefragLog table
                                    , modified logging to show "in progress" defrags
                                    , added defrag exclusion list (scheduling)
    2009-08-28  MFU         3.1     Fixed read_only bug for database lists
    2010-04-20  MFU         4.0     Added time limit option
                                    , added static table with rescan logic
                                    , added parameters for page count & SORT_IN_TEMPDB
                                    , added try/catch logic and additional debug options
                                    , added options for defrag prioritization
                                    , fixed bug for indexes with allow_page_lock = off
                                    , added option to exclude right-most partition
                                    , removed @rebuildStats option
                                    , refer to http://sqlfool.com for full release notes
*********************************************************************************
    Example of how to call this script:

        Exec dbo.dba_indexDefrag_sp
              @executeSQL           = 1
            , @printCommands        = 1
            , @debugMode            = 1
            , @printFragmentation   = 1
            , @forceRescan          = 1
            , @maxDopRestriction    = 1
            , @minPageCount         = 8
            , @maxPageCount         = Null
            , @minFragmentation     = 1
            , @rebuildThreshold     = 30
            , @defragDelay          = '00:00:05'
            , @defragOrderColumn    = 'page_count'
            , @defragSortOrder      = 'DESC'
            , @excludeMaxPartition  = 1
            , @timeLimit            = Null;
*********************************************************************************/																
Set NoCount On;
Set XACT_Abort On;
Set Quoted_Identifier On;

Begin

    Begin Try

        /* Just a little validation... */
        If @minFragmentation Is Null 
            Or @minFragmentation Not Between 0.00 And 100.0
                Set @minFragmentation = 10.0;

        If @rebuildThreshold Is Null
            Or @rebuildThreshold Not Between 0.00 And 100.0
                Set @rebuildThreshold = 30.0;

        If @defragDelay Not Like '00:[0-5][0-9]:[0-5][0-9]'
            Set @defragDelay = '00:00:05';

        If @defragOrderColumn Is Null
            Or @defragOrderColumn Not In ('range_scan_count', 'fragmentation', 'page_count')
                Set @defragOrderColumn = 'range_scan_count';

        If @defragSortOrder Is Null
            Or @defragSortOrder Not In ('ASC', 'DESC')
                Set @defragSortOrder = 'DESC';

        If @scanMode Not In ('LIMITED', 'SAMPLED', 'DETAILED')
            Set @scanMode = 'LIMITED';

        If @debugMode Is Null
            Set @debugMode = 0;

        If @forceRescan Is Null
            Set @forceRescan = 0;

        If @sortInTempDB Is Null
            Set @sortInTempDB = 1;


        If @debugMode = 1 RaisError('Undusting the cogs and starting up...', 0, 42) With NoWait;

        /* Declare our variables */
        Declare   @objectID                 int
                , @databaseID               int
                , @databaseName             nvarchar(128)
                , @indexID                  int
                , @partitionCount           bigint
                , @schemaName               nvarchar(128)
                , @objectName               nvarchar(128)
                , @indexName                nvarchar(128)
                , @partitionNumber          smallint
                , @fragmentation            float
                , @pageCount                int
                , @sqlCommand               nvarchar(4000)
                , @rebuildCommand           nvarchar(200)
                , @dateTimeStart            datetime
                , @dateTimeEnd              datetime
                , @containsLOB              bit
                , @editionCheck             bit
                , @debugMessage             nvarchar(4000)
                , @updateSQL                nvarchar(4000)
                , @partitionSQL             nvarchar(4000)
                , @partitionSQL_Param       nvarchar(1000)
                , @LOB_SQL                  nvarchar(4000)
                , @LOB_SQL_Param            nvarchar(1000)
                , @indexDefrag_id           int
                , @startDateTime            datetime
                , @endDateTime              datetime
                , @getIndexSQL              nvarchar(4000)
                , @getIndexSQL_Param        nvarchar(4000)
                , @allowPageLockSQL         nvarchar(4000)
                , @allowPageLockSQL_Param   nvarchar(4000)
                , @allowPageLocks           int
                , @excludeMaxPartitionSQL   nvarchar(4000);

        /* Initialize our variables */
        Select @startDateTime = GetDate()
            , @endDateTime = DateAdd(minute, @timeLimit, GetDate());

        /* Create our temporary tables */
        Create Table #databaseList
        (
              databaseID        int
            , databaseName      varchar(128)
            , scanStatus        bit
        );

        Create Table #processor 
        (
              [index]           int
            , Name              varchar(128)
            , Internal_Value    int
            , Character_Value   int
        );

        Create Table #maxPartitionList
        (
              databaseID        int
            , objectID          int
            , indexID           int
            , maxPartition      int
        );

        If @debugMode = 1 RaisError('Beginning validation...', 0, 42) With NoWait;

        /* Make sure we're not exceeding the number of processors we have available */
        Insert Into #processor
        Execute xp_msver 'ProcessorCount';

        If @maxDopRestriction Is Not Null And @maxDopRestriction > (Select Internal_Value From #processor)
            Select @maxDopRestriction = Internal_Value
            From #processor;

        /* Check our server version; 1804890536 = Enterprise, 610778273 = Enterprise Evaluation, -2117995310 = Developer */
        If (Select ServerProperty('EditionID')) In (1804890536, 610778273, -2117995310) 
            Set @editionCheck = 1 -- supports online rebuilds
        Else
            Set @editionCheck = 0; -- does not support online rebuilds

        /* Output the parameters we're working with */
        If @debugMode = 1 
        Begin

            Select @debugMessage = 'Your selected parameters are... 
            Defrag indexes with fragmentation greater than ' + Cast(@minFragmentation As varchar(10)) + ';
            Rebuild indexes with fragmentation greater than ' + Cast(@rebuildThreshold As varchar(10)) + ';
            You' + Case When @executeSQL = 1 Then ' DO' Else ' DO NOT' End + ' want the commands to be executed automatically; 
            You want to defrag indexes in ' + @defragSortOrder + ' order of the ' + UPPER(@defragOrderColumn) + ' value;
            You have' + Case When @timeLimit Is Null Then ' not specified a time limit;' Else ' specified a time limit of ' 
                + Cast(@timeLimit As varchar(10)) End + ' minutes;
            ' + Case When @database Is Null Then 'ALL databases' Else 'The ' + @database + ' database' End + ' will be defragged;
            ' + Case When @tableName Is Null Then 'ALL tables' Else 'The ' + @tableName + ' table' End + ' will be defragged;
            We' + Case When Exists(Select Top 1 * From dbo.dba_indexDefragStatus Where defragDate Is Null)
                And @forceRescan <> 1 Then ' WILL NOT' Else ' WILL' End + ' be rescanning indexes;
            The scan will be performed in ' + @scanMode + ' mode;
            You want to limit defrags to indexes with' + Case When @maxPageCount Is Null Then ' more than ' 
                + Cast(@minPageCount As varchar(10)) Else
                ' between ' + Cast(@minPageCount As varchar(10))
                + ' and ' + Cast(@maxPageCount As varchar(10)) End + ' pages;
            Indexes will be defragged' + Case When @editionCheck = 0 Or @onlineRebuild = 0 Then ' OFFLINE;' Else ' ONLINE;' End + '
            Indexes will be sorted in' + Case When @sortInTempDB = 0 Then ' the DATABASE' Else ' TEMPDB;' End + '
            Defrag operations will utilize ' + Case When @editionCheck = 0 Or @maxDopRestriction Is Null 
                Then 'system defaults for processors;' 
                Else Cast(@maxDopRestriction As varchar(2)) + ' processors;' End + '
            You' + Case When @printCommands = 1 Then ' DO' Else ' DO NOT' End + ' want to print the ALTER INDEX commands; 
            You' + Case When @printFragmentation = 1 Then ' DO' Else ' DO NOT' End + ' want to output fragmentation levels; 
            You want to wait ' + @defragDelay + ' (hh:mm:ss) between defragging indexes;
            You want to run in' + Case When @debugMode = 1 Then ' DEBUG' Else ' SILENT' End + ' mode.';

            RaisError(@debugMessage, 0, 42) With NoWait;
        
        End;

        If @debugMode = 1 RaisError('Grabbing a list of our databases...', 0, 42) With NoWait;

        /* Retrieve the list of databases to investigate */
        Insert Into #databaseList
        Select database_id
            , name
            , 0 -- not scanned yet for fragmentation
        From sys.databases
        Where name = IsNull(@database, name)
            And [name] Not In ('master', 'tempdb')-- exclude system databases
            And [state] = 0 -- state must be ONLINE
            And is_read_only = 0;  -- cannot be read_only

        /* Check to see if we have indexes in need of defrag; otherwise, re-scan the database(s) */
        If Not Exists(Select Top 1 * From dbo.dba_indexDefragStatus Where defragDate Is Null)
            Or @forceRescan = 1
        Begin

            /* Truncate our list of indexes to prepare for a new scan */
            Truncate Table dbo.dba_indexDefragStatus;

            If @debugMode = 1 RaisError('Looping through our list of databases and checking for fragmentation...', 0, 42) With NoWait;

            /* Loop through our list of databases */
            While (Select Count(*) From #databaseList Where scanStatus = 0) > 0
            Begin

                Select Top 1 @databaseID = databaseID
                From #databaseList
                Where scanStatus = 0;

                Select @debugMessage = '  working on ' + DB_Name(@databaseID) + '...';

                If @debugMode = 1
                    RaisError(@debugMessage, 0, 42) With NoWait;

               /* Determine which indexes to defrag using our user-defined parameters */
                Insert Into dbo.dba_indexDefragStatus
                (
                      databaseID
                    , databaseName
                    , objectID
                    , indexID
                    , partitionNumber
                    , fragmentation
                    , page_count
                    , range_scan_count
                    , scanDate
                )
                Select
                      ps.database_id As 'databaseID'
                    , QuoteName(DB_Name(ps.database_id)) As 'databaseName'
                    , ps.object_id As 'objectID'
                    , ps.index_id As 'indexID'
                    , ps.partition_number As 'partitionNumber'
                    , Sum(ps.avg_fragmentation_in_percent) As 'fragmentation'
                    , Sum(ps.page_count) As 'page_count'
                    , os.range_scan_count
                    , GetDate() As 'scanDate'
                From sys.dm_db_index_physical_stats(@databaseID, Object_Id(@tableName), Null , Null, @scanMode) As ps
                Join sys.dm_db_index_operational_stats(@databaseID, Object_Id(@tableName), Null , Null) as os
                    On ps.database_id = os.database_id
                    And ps.object_id = os.object_id
                    and ps.index_id = os.index_id
                    And ps.partition_number = os.partition_number
                Where avg_fragmentation_in_percent >= @minFragmentation 
                    And ps.index_id > 0 -- ignore heaps
                    And ps.page_count > @minPageCount 
                    And ps.index_level = 0 -- leaf-level nodes only, supports @scanMode
                Group By ps.database_id 
                    , QuoteName(DB_Name(ps.database_id)) 
                    , ps.object_id 
                    , ps.index_id 
                    , ps.partition_number 
                    , os.range_scan_count
                Option (MaxDop 2);

                /* Do we want to exclude right-most populated partition of our partitioned indexes? */
                If @excludeMaxPartition = 1
                Begin

                    Set @excludeMaxPartitionSQL = '
                        Select ' + Cast(@databaseID As varchar(10)) + ' As [databaseID]
                            , [object_id]
                            , index_id
                            , Max(partition_number) As [maxPartition]
                        From ' + DB_Name(@databaseID) + '.sys.partitions
                        Where partition_number > 1
                            And [rows] > 0
                        Group By object_id
                            , index_id;';

                    Insert Into #maxPartitionList
                    Execute sp_executesql @excludeMaxPartitionSQL;

                End;
                
                /* Keep track of which databases have already been scanned */
                Update #databaseList
                Set scanStatus = 1
                Where databaseID = @databaseID;

            End

            /* We don't want to defrag the right-most populated partition, so
               delete any records for partitioned indexes where partition = Max(partition) */
            If @excludeMaxPartition = 1
            Begin

                Delete ids
                From dbo.dba_indexDefragStatus As ids
                Join #maxPartitionList As mpl
                    On ids.databaseID = mpl.databaseID
                    And ids.objectID = mpl.objectID
                    And ids.indexID = mpl.indexID
                    And ids.partitionNumber = mpl.maxPartition;

            End;

            /* Update our exclusion mask for any index that has a restriction on the days it can be defragged */
            Update ids
            Set ids.exclusionMask = ide.exclusionMask
            From dbo.dba_indexDefragStatus As ids
            Join dbo.dba_indexDefragExclusion As ide
                On ids.databaseID = ide.databaseID
                And ids.objectID = ide.objectID
                And ids.indexID = ide.indexID;
         
        End

        Select @debugMessage = 'Looping through our list... there are ' + Cast(Count(*) As varchar(10)) + ' indexes to defrag!'
        From dbo.dba_indexDefragStatus
        Where defragDate Is Null
            And page_count Between @minPageCount And IsNull(@maxPageCount, page_count);

        If @debugMode = 1 RaisError(@debugMessage, 0, 42) With NoWait;

        /* Begin our loop for defragging */
        While (Select Count(*) 
               From dbo.dba_indexDefragStatus 
               Where (
                           (@executeSQL = 1 And defragDate Is Null) 
                        Or (@executeSQL = 0 And defragDate Is Null And printStatus = 0)
                     )
                And exclusionMask & Power(2, DatePart(weekday, GetDate())-1) = 0
                And page_count Between @minPageCount And IsNull(@maxPageCount, page_count)) > 0
        Begin

            /* Check to see if we need to exit our loop because of our time limit */        
            If IsNull(@endDateTime, GetDate()) < GetDate()
            Begin
                RaisError('Our time limit has been exceeded!', 11, 42) With NoWait;
            End;

            If @debugMode = 1 RaisError('  Picking an index to beat into shape...', 0, 42) With NoWait;

            /* Grab the index with the highest priority, based on the values submitted; 
               Look at the exclusion mask to ensure it can be defragged today */
            Set @getIndexSQL = N'
            Select Top 1 
                  @objectID_Out         = objectID
                , @indexID_Out          = indexID
                , @databaseID_Out       = databaseID
                , @databaseName_Out     = databaseName
                , @fragmentation_Out    = fragmentation
                , @partitionNumber_Out  = partitionNumber
                , @pageCount_Out        = page_count
            From dbo.dba_indexDefragStatus
            Where defragDate Is Null ' 
                + Case When @executeSQL = 0 Then 'And printStatus = 0' Else '' End + '
                And exclusionMask & Power(2, DatePart(weekday, GetDate())-1) = 0
                And page_count Between @p_minPageCount and IsNull(@p_maxPageCount, page_count)
            Order By + ' + @defragOrderColumn + ' ' + @defragSortOrder;
                       
            Set @getIndexSQL_Param = N'@objectID_Out        int OutPut
                                     , @indexID_Out         int OutPut
                                     , @databaseID_Out      int OutPut
                                     , @databaseName_Out    nvarchar(128) OutPut
                                     , @fragmentation_Out   int OutPut
                                     , @partitionNumber_Out int OutPut
                                     , @pageCount_Out       int OutPut
                                     , @p_minPageCount      int
                                     , @p_maxPageCount      int';

            Execute sp_executesql @getIndexSQL
                , @getIndexSQL_Param
                , @p_minPageCount       = @minPageCount
                , @p_maxPageCount       = @maxPageCount
                , @objectID_Out         = @objectID OutPut
                , @indexID_Out          = @indexID OutPut
                , @databaseID_Out       = @databaseID OutPut
                , @databaseName_Out     = @databaseName OutPut
                , @fragmentation_Out    = @fragmentation OutPut
                , @partitionNumber_Out  = @partitionNumber OutPut
                , @pageCount_Out        = @pageCount OutPut;

            If @debugMode = 1 RaisError('  Looking up the specifics for our index...', 0, 42) With NoWait;

            /* Look up index information */
            Select @updateSQL = N'Update ids
                Set schemaName = QuoteName(s.name)
                    , objectName = QuoteName(o.name)
                    , indexName = QuoteName(i.name)
                From dbo.dba_indexDefragStatus As ids
                Inner Join ' + @databaseName + '.sys.objects As o
                    On ids.objectID = o.object_id
                Inner Join ' + @databaseName + '.sys.indexes As i
                    On o.object_id = i.object_id
                    And ids.indexID = i.index_id
                Inner Join ' + @databaseName + '.sys.schemas As s
                    On o.schema_id = s.schema_id
                Where o.object_id = ' + Cast(@objectID As varchar(10)) + '
                    And i.index_id = ' + Cast(@indexID As varchar(10)) + '
                    And i.type > 0
                    And ids.databaseID = ' + Cast(@databaseID As varchar(10));

            Execute sp_executesql @updateSQL;

            /* Grab our object names */
            Select @objectName  = objectName
                , @schemaName   = schemaName
                , @indexName    = indexName
            From dbo.dba_indexDefragStatus
            Where objectID = @objectID
                And indexID = @indexID
                And databaseID = @databaseID;

            If @debugMode = 1 RaisError('  Grabbing the partition count...', 0, 42) With NoWait;

            /* Determine if the index is partitioned */
            Select @partitionSQL = 'Select @partitionCount_OUT = Count(*)
                                        From ' + @databaseName + '.sys.partitions
                                        Where object_id = ' + Cast(@objectID As varchar(10)) + '
                                            And index_id = ' + Cast(@indexID As varchar(10)) + ';'
                , @partitionSQL_Param = '@partitionCount_OUT int OutPut';

            Execute sp_executesql @partitionSQL, @partitionSQL_Param, @partitionCount_OUT = @partitionCount OutPut;

            If @debugMode = 1 RaisError('  Seeing if there are any LOBs to be handled...', 0, 42) With NoWait;
        
            /* Determine if the table contains LOBs */
            Select @LOB_SQL = ' Select @containsLOB_OUT = Count(*)
                                From ' + @databaseName + '.sys.columns With (NoLock) 
                                Where [object_id] = ' + Cast(@objectID As varchar(10)) + '
                                   And (system_type_id In (34, 35, 99)
                                            Or max_length = -1);'
                                /*  system_type_id --> 34 = image, 35 = text, 99 = ntext
                                    max_length = -1 --> varbinary(max), varchar(max), nvarchar(max), xml */
                    , @LOB_SQL_Param = '@containsLOB_OUT int OutPut';

            Execute sp_executesql @LOB_SQL, @LOB_SQL_Param, @containsLOB_OUT = @containsLOB OutPut;

            If @debugMode = 1 RaisError('  Checking for indexes that do not allow page locks...', 0, 42) With NoWait;

            /* Determine if page locks are allowed; for those indexes, we need to always rebuild */
            Select @allowPageLockSQL = 'Select @allowPageLocks_OUT = Count(*)
                                        From ' + @databaseName + '.sys.indexes
                                        Where object_id = ' + Cast(@objectID As varchar(10)) + '
                                            And index_id = ' + Cast(@indexID As varchar(10)) + '
                                            And Allow_Page_Locks = 0;'
                , @allowPageLockSQL_Param = '@allowPageLocks_OUT int OutPut';

            Execute sp_executesql @allowPageLockSQL, @allowPageLockSQL_Param, @allowPageLocks_OUT = @allowPageLocks OutPut;

            If @debugMode = 1 RaisError('  Building our SQL statements...', 0, 42) With NoWait;

            /* If there's not a lot of fragmentation, or if we have a LOB, we should reorganize */
            If (@fragmentation < @rebuildThreshold Or @containsLOB >= 1 Or @partitionCount > 1)
                And @allowPageLocks = 0
            Begin
            
                Set @sqlCommand = N'Alter Index ' + @indexName + N' On ' + @databaseName + N'.' 
                                    + @schemaName + N'.' + @objectName + N' ReOrganize';

                /* If our index is partitioned, we should always reorganize */
                If @partitionCount > 1
                    Set @sqlCommand = @sqlCommand + N' Partition = ' 
                                    + Cast(@partitionNumber As nvarchar(10));

            End
            /* If the index is heavily fragmented and doesn't contain any partitions or LOB's, 
               or if the index does not allow page locks, rebuild it */
            Else If (@fragmentation >= @rebuildThreshold Or @allowPageLocks <> 0)
                And IsNull(@containsLOB, 0) != 1 And @partitionCount <= 1
            Begin

                /* Set online rebuild options; requires Enterprise Edition */
                If @onlineRebuild = 1 And @editionCheck = 1 
                    Set @rebuildCommand = N' Rebuild With (Online = On';
                Else
                    Set @rebuildCommand = N' Rebuild With (Online = Off';
                
                /* Set sort operation preferences */
                If @sortInTempDB = 1 
                    Set @rebuildCommand = @rebuildCommand + N', Sort_In_TempDB = On';
                Else
                    Set @rebuildCommand = @rebuildCommand + N', Sort_In_TempDB = Off';

                /* Set processor restriction options; requires Enterprise Edition */
                If @maxDopRestriction Is Not Null And @editionCheck = 1
                    Set @rebuildCommand = @rebuildCommand + N', MaxDop = ' + Cast(@maxDopRestriction As varchar(2)) + N')';
                Else
                    Set @rebuildCommand = @rebuildCommand + N')';

                Set @sqlCommand = N'Alter Index ' + @indexName + N' On ' + @databaseName + N'.'
                                + @schemaName + N'.' + @objectName + @rebuildCommand;

            End
            Else
                /* Print an error message if any indexes happen to not meet the criteria above */
                If @printCommands = 1 Or @debugMode = 1
                    RaisError('We are unable to defrag this index.', 0, 42) With NoWait;

            /* Are we executing the SQL?  If so, do it */
            If @executeSQL = 1
            Begin

                Set @debugMessage = 'Executing: ' + @sqlCommand;
                
                /* Print the commands we're executing if specified to do so */
                If @printCommands = 1 Or @debugMode = 1
                    RaisError(@debugMessage, 0, 42) With NoWait;

                /* Grab the time for logging purposes */
                Set @dateTimeStart  = GetDate();

                /* Log our actions */
                Insert Into dbo.dba_indexDefragLog
                (
                      databaseID
                    , databaseName
                    , objectID
                    , objectName
                    , indexID
                    , indexName
                    , partitionNumber
                    , fragmentation
                    , page_count
                    , dateTimeStart
                    , sqlStatement
                )
                Select
                      @databaseID
                    , @databaseName
                    , @objectID
                    , @objectName
                    , @indexID
                    , @indexName
                    , @partitionNumber
                    , @fragmentation
                    , @pageCount
                    , @dateTimeStart
                    , @sqlCommand;

                Set @indexDefrag_id = Scope_Identity();

                /* Wrap our execution attempt in a try/catch and log any errors that occur */
                Begin Try

                    /* Execute our defrag! */
                    Execute sp_executesql @sqlCommand;
                    Set @dateTimeEnd = GetDate();
                    
                    /* Update our log with our completion time */
                    Update dbo.dba_indexDefragLog
                    Set dateTimeEnd = @dateTimeEnd
                        , durationSeconds = DateDiff(second, @dateTimeStart, @dateTimeEnd)
                    Where indexDefrag_id = @indexDefrag_id;

                End Try
                Begin Catch

                    /* Update our log with our error message */
                    Update dbo.dba_indexDefragLog
                    Set dateTimeEnd = GetDate()
                        , durationSeconds = -1
                        , errorMessage = Error_Message()
                    Where indexDefrag_id = @indexDefrag_id;

                    If @debugMode = 1 
                        RaisError('  An error has occurred executing this command! Please review the dba_indexDefragLog table for details.'
                            , 0, 42) With NoWait;

                End Catch

                /* Just a little breather for the server */
                WaitFor Delay @defragDelay;

                Update dbo.dba_indexDefragStatus
                Set defragDate = GetDate()
                    , printStatus = 1
                Where databaseID       = @databaseID
                  And objectID         = @objectID
                  And indexID          = @indexID
                  And partitionNumber  = @partitionNumber;

            End
            Else
            /* Looks like we're not executing, just printing the commands */
            Begin
                If @debugMode = 1 RaisError('  Printing SQL statements...', 0, 42) With NoWait;
                
                If @printCommands = 1 Or @debugMode = 1 
                    Print IsNull(@sqlCommand, 'error!');

                Update dbo.dba_indexDefragStatus
                Set printStatus = 1
                Where databaseID       = @databaseID
                  And objectID         = @objectID
                  And indexID          = @indexID
                  And partitionNumber  = @partitionNumber;
            End

        End

        /* Do we want to output our fragmentation results? */
        If @printFragmentation = 1
        Begin

            If @debugMode = 1 RaisError('  Displaying a summary of our action...', 0, 42) With NoWait;

            Select databaseID
                , databaseName
                , objectID
                , objectName
                , indexID
                , indexName
                , partitionNumber
                , fragmentation
                , page_count
                , range_scan_count
            From dbo.dba_indexDefragStatus
            Where defragDate >= @startDateTime
            Order By defragDate;

        End;

    End Try
    Begin Catch

        Set @debugMessage = Error_Message() + ' (Line Number: ' + Cast(Error_Line() As varchar(10)) + ')';
        Print @debugMessage;

    End Catch;

    /* When everything is said and done, make sure to get rid of our temp table */
    Drop Table #databaseList;
    Drop Table #processor;
    Drop Table #maxPartitionList;

    If @debugMode = 1 RaisError('DONE!  Thank you for taking care of your indexes!  :)', 0, 42) With NoWait;

    Set NoCount Off;
    Return 0
End