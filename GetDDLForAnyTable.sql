USE master
GO
IF OBJECT_ID('[dbo].[sp_GetDDLa]') IS NOT NULL 
  DROP PROCEDURE [dbo].[sp_GetDDLa] 
GO
-- USAGE: exec sp_GetDDLa GMACT
--   or   exec sp_GetDDLa 'bob.example'
--   or   exec sp_GetDDLa '[schemaname].[tablename]'
--   or   exec sp_GetDDLa #temp
--#################################################################################################
-- copyright 2004-2013 by Lowell Izaguirre scripts*at*stormrage.com all rights reserved.
-- http://www.stormrage.com/SQLStuff/sp_GetDDL_Latest.txt
--Purpose: Script Any Table, Temp Table or Object
--
-- see the thread here for lots of details: http://www.sqlservercentral.com/Forums/Topic751783-566-7.aspx

-- You can use this however you like...this script is not rocket science, but it took a bit of work to create.
-- the only thing that I ask
-- is that if you adapt my procedure or make it better, to simply send me a copy of it,
-- so I can learn from the things you've enhanced.The feedback you give will be what makes
-- it worthwhile to me, and will be fed back to the SQL community.
-- add this to your toolbox of helpful scripts.
--#################################################################################################
--
-- V300  uses String concatination and sys.tables instead of a cursor
-- V301  enhanced 07/31/2009 to include extended properties definitions
-- V302  fixes an issue where the schema is created , ie 'bob', but no user named 'bob' owns the schema, so the table is not found
-- V303  fixes an issue where all rules are appearing, instead of jsut the rule related to a column
-- V304  testing whether vbCrLf is better than just CHAR(13), some formatting cleanup with GO statements
--       also fixed an issue with the conversion from syscolumns to sys.columns, max-length is only field we need, not [precision]
-- V305  user feedback helped me find that the type_name function should call user_type_id instead of system_type_id
--       also fixed issue where identity definition missing from numeric/decimal definition
-- V306  fixes the computed columns definition that got broken/removed somehow in V300
--       also formatting when decimal is not an identity
-- V307  fixes bug identified by David Griffiths-491597 from SSC where the  @TABLE_ID
--       is reselected, but without it's schema  , potentially selecting the wrong table
--       also fixed is the missing size definition for varbinary, also found by David Griffith
-- V308  abtracted all SQLs to use Table Alaises
--       added logic to script a temp table.
--       added warning about possibly not being marked as system object.
-- V309  added logic based on feedback from Vincent Wylenzek @SSC to return the definition from sys.sql_modules for
--       any object like procedure/view/function/trigger, and not just a table. 
--       note previously, if you pointed sp_GetDDLa at a view, it returned the view definition as a table...
--       now it will return the view definition instead.
-- V309a returns multi row recordset, one line per record 
-- V310a fixed the commented out code related to collation identified by moadh.bs @SSC
--       changed the DEFAULT definitions to not include the default name.
-- V310b Added PERSISTED to calculated columns where applicable
-- V310b fixed COLLATE statement for temp tables
-- V310c fixed NVARCHAR size misreported as doubled.
-- V311  fixed issue where indexes did not identify if the column was ASC or DESC found by nikus @ SSC
-- V311a fixed issue where indexes did not identify if the index was CLUSTERED or NONCLUSTERED found by nikus @ SSC 02/22/2013
-- V312  got rid of all upper casing, and allowing all scripts to generate the exact object names in cases of case sensitive databases.
--       now using the case sensitive name of the table passed: so of you did 'exec sp_getDDLA invoicedocs , it might return the script for InvoiceDocs, as that is how it is spelled in sys.objects.
--       added if exists(drop table/procedure/function) statement to the scripting automatically.
--       toggled the commented out code to list any default constraints by name, hopefully to be more accurate..
--       formatting of index statements to be multi line for better readability
--V314   03/30/2015
--       did i mention this scripts out temp tables too? sp_getDDLa #tmp
--       scripts any object:table,#temptable procedure, function, view or trigger
--       added ability to script synonyms
--       moved logic for REAL datatype to fix error when scripting real columns
--       added OmaCoders suggestion to script column extended properties as well.
--       added matt_slack suggestion to script schemaname as part of index portion of script.
--       minor script cleanup to use QUOTENAME insead of concatenating square brackets.
--       changed compatibility to 2008 and above only, now filtered idnexes with WHERE statmeents script correctly
--       foreign key tables and columns  in script now quotenamed to accoutn for spaces in names; previously an error for Applciation ID instead of [Application ID]
-- DROP PROCEDURE [dbo].[sp_GetDDLa]
--#############################################################################
--if you are going to put this in MASTER, and want it to be able to query
--each database's sys.indexes, you MUST mark it as a system procedure:
--EXECUTE sp_ms_marksystemobject 'sp_GetDDLa'
--#############################################################################
CREATE PROCEDURE [dbo].[sp_GetDDLa]
  @TBL                VARCHAR(255)
AS
BEGIN
  SET NOCOUNT ON
  DECLARE     @TBLNAME                VARCHAR(200),
              @SCHEMANAME             VARCHAR(255),
              @STRINGLEN              INT,
              @TABLE_ID               INT,
              @FINALSQL               VARCHAR(MAX),
              @CONSTRAINTSQLS         VARCHAR(MAX),
              @CHECKCONSTSQLS         VARCHAR(MAX),
              @RULESCONSTSQLS         VARCHAR(MAX),
              @FKSQLS                 VARCHAR(MAX),
              @TRIGGERSTATEMENT       VARCHAR(MAX),
              @EXTENDEDPROPERTIES     VARCHAR(MAX),
              @INDEXSQLS              VARCHAR(MAX),
              @vbCrLf                 CHAR(2),
              @ISSYSTEMOBJECT         INT,
              @PROCNAME               VARCHAR(256),
              @input                  VARCHAR(MAX),
              @ObjectTypeFound        VARCHAR(255)

--##############################################################################
-- INITIALIZE
--##############################################################################
  SET @input = ''
  --new code: determine whether this proc is marked as a system proc with sp_ms_marksystemobject,
  --which flips the is_ms_shipped bit in sys.objects
    SELECT @ISSYSTEMOBJECT = ISNULL(is_ms_shipped,0),@PROCNAME = ISNULL(name,'sp_GetDDL') FROM sys.objects WHERE OBJECT_ID = @@PROCID
  IF @ISSYSTEMOBJECT IS NULL 
    SELECT @ISSYSTEMOBJECT = ISNULL(is_ms_shipped,0),@PROCNAME = ISNULL(name,'pp_GetDDL') FROM master.sys.objects WHERE OBJECT_ID = @@PROCID
  IF @ISSYSTEMOBJECT IS NULL 
    SET @ISSYSTEMOBJECT = 0  
  IF @PROCNAME IS NULL
    SET @PROCNAME = 'sp_GetDDLa'
  --SET @TBL =  '[DBO].[WHATEVER1]'
  --does the tablename contain a schema?
  SET @vbCrLf = CHAR(13) + CHAR(10)
  SELECT @SCHEMANAME = ISNULL(PARSENAME(@TBL,2),'dbo') ,
         @TBLNAME    = PARSENAME(@TBL,1)
  SELECT
    @TBLNAME    = [name],
    @TABLE_ID   = [OBJECT_ID]
  FROM sys.objects OBJS
  WHERE [TYPE]          IN ('S','U')
    AND [name]          <>  'dtproperties'
    AND [name]           =  @TBLNAME
    AND [SCHEMA_ID] =  SCHEMA_ID(@SCHEMANAME) ;

--##############################################################################
-- Check If TEMP TableName is Valid
--##############################################################################
  IF LEFT(@TBLNAME,1) = '#'
    BEGIN
      PRINT '--TEMP TABLE  ' + quotename(@TBLNAME) + '  FOUND'
      IF OBJECT_ID('tempdb..' + quotename(@TBLNAME)) IS NOT NULL
        BEGIN
          PRINT '--GOIN TO TEMP PROCESSING'
          GOTO TEMPPROCESS
        END
    END
  ELSE
    BEGIN
      PRINT '--Non-Temp Table, ' + quotename(@TBLNAME) + ' continue Processing'
    END
--##############################################################################
-- Check If TableName is Valid
--##############################################################################
  IF ISNULL(@TABLE_ID,0) = 0
    BEGIN
      --V309 code: see if it is an object and not a table.
      SELECT
        @TBLNAME    = [name],
        @TABLE_ID   = [OBJECT_ID],
        @ObjectTypeFound = type_desc
      FROM sys.objects OBJS
      --WHERE [type_desc]     IN('SQL_STORED_PROCEDURE','VIEW','SQL_TRIGGER','AGGREGATE_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION','SQL_SCALAR_FUNCTION','SYNONYMN')
      WHERE [TYPE]          IN ('P','V','TR','AF','IF','FN','TF','SN')
        AND [name]          <>  'dtproperties'
        AND [name]           =  @TBLNAME
        AND [SCHEMA_ID] =  SCHEMA_ID(@SCHEMANAME) ;
      IF ISNULL(@TABLE_ID,0) <> 0  
        BEGIN
          --adding a drop statement.
          IF @ObjectTypeFound = 'SYNONYM'
            BEGIN
               SELECT @FINALSQL = 
                'IF EXISTS(SELECT * FROM sys.synonyms WHERE name = ''' 
                                + name 
                                + ''''
                                + ' AND base_object_name <> ''' + base_object_name + ''')'
                                + @vbCrLf
                                + '  DROP SYNONYM ' + quotename(name) + ''
                                + @vbCrLf
                                +'GO'
                                + @vbCrLf
                                +'IF NOT EXISTS(SELECT * FROM sys.synonyms WHERE name = ''' 
                                + name 
                                + ''')'
                                + @vbCrLf
                                + 'CREATE SYNONYM ' + quotename(name) + ' FOR ' + base_object_name +';'
                                from sys.synonyms
                                WHERE  [name]   =  @TBLNAME
                                AND [SCHEMA_ID] =  SCHEMA_ID(@SCHEMANAME);
            END
          ELSE
            BEGIN
              SELECT @FINALSQL = 
              'IF OBJECT_ID(''' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ''') IS NOT NULL ' + @vbcrlf
              + 'DROP ' + CASE 
                            WHEN OBJS.[type] IN ('P')
                            THEN ' PROCEDURE '
                            WHEN OBJS.[type] IN ('V')
                            THEN ' VIEW      '
                            WHEN OBJS.[type] IN ('TR')
                            THEN ' TRIGGER   '
                            ELSE ' FUNCTION  '
                          END 
                          + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ' + @vbcrlf + 'GO' + @vbcrlf
              + def.definition 
              FROM sys.objects OBJS 
                INNER JOIN sys.sql_modules def
                  ON OBJS.object_id = def.object_id
              WHERE OBJS.[type]          IN ('P','V','TR','AF','IF','FN','TF')
                AND OBJS.[name]          <>  'dtproperties'
                AND OBJS.[name]           =  @TBLNAME
                AND OBJS.[schema_id] =  SCHEMA_ID(@SCHEMANAME) ;
            END
          SET @input = @FINALSQL  
            --ten years worth of days from todays date:
         ;WITH E01(N) AS (SELECT 1 UNION ALL SELECT 1 UNION ALL
                          SELECT 1 UNION ALL SELECT 1 UNION ALL
                          SELECT 1 UNION ALL SELECT 1 UNION ALL
                          SELECT 1 UNION ALL SELECT 1 UNION ALL
                          SELECT 1 UNION ALL SELECT 1), --         10 or 10E01 rows
               E02(N) AS (SELECT 1 FROM E01 a, E01 b),  --        100 or 10E02 rows
               E04(N) AS (SELECT 1 FROM E02 a, E02 b),  --     10,000 or 10E04 rows
               E08(N) AS (SELECT 1 FROM E04 a, E04 b),  --100,000,000 or 10E08 rows
               --E16(N) AS (SELECT 1 FROM E08 a, E08 b),  --10E16 or more rows than you'll EVER need,
               Tally(N) AS (SELECT ROW_NUMBER() OVER (ORDER BY N) FROM E08),
             ItemSplit(
                       ItemOrder,
                       Item
                      ) AS (
                            SELECT N,
                              SUBSTRING(@vbCrLf + @input + @vbCrLf,N + DATALENGTH(@vbCrLf),CHARINDEX(@vbCrLf,@vbCrLf + @input + @vbCrLf,N + DATALENGTH(@vbCrLf)) - N - DATALENGTH(@vbCrLf))
                            FROM Tally
                            WHERE N < DATALENGTH(@vbCrLf + @input)
                            --WHERE N < DATALENGTH(@vbCrLf + @input) -- REMOVED added @vbCrLf
                              AND SUBSTRING(@vbCrLf + @input + @vbCrLf,N,DATALENGTH(@vbCrLf)) = @vbCrLf --Notice how we find the delimiter
                           )
        SELECT
          --row_number() over (order by ItemOrder) as ItemID,
          Item
        FROM ItemSplit;
         RETURN 0
        END
      ELSE
        BEGIN
        SET @FINALSQL = 'Object ' + quotename(@SCHEMANAME) + '.' + quotename(@TBLNAME) + ' does not exist in Database ' + quotename(DB_NAME())   + ' ' 
                      --+ CASE 
                      --    WHEN @ISSYSTEMOBJECT = 0 THEN @vbCrLf + ' (also note that ' + @PROCNAME + ' is not marked as a system proc and cross db access to sys.tables will fail.)'
                      --    ELSE ''
                      --  END
      IF LEFT(@TBLNAME,1) = '#' 
        SET @FINALSQL = @FINALSQL + ' OR in The tempdb database.'
      SELECT @FINALSQL AS Item;
      RETURN 0
        END  
      
    END
--##############################################################################
-- Valid Table, Continue Processing
--##############################################################################
 SELECT 
   @FINALSQL =  'IF OBJECT_ID(''' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ''') IS NOT NULL ' + @vbcrlf
              + 'DROP TABLE ' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ' + @vbcrlf + 'GO' + @vbcrlf
              + 'CREATE TABLE ' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ( '
  --removed invalid code here which potentially selected wrong table--thanks David Grifiths @SSC!
  SELECT
    @STRINGLEN = MAX(LEN(COLS.[name])) + 1
  FROM sys.objects OBJS
    INNER JOIN sys.columns COLS
      ON  OBJS.[object_id] = COLS.[object_id]
      AND OBJS.[object_id] = @TABLE_ID;
--##############################################################################
--Get the columns, their definitions and defaults.
--##############################################################################
  SELECT
    @FINALSQL = @FINALSQL
    + CASE
        WHEN COLS.[is_computed] = 1
        THEN @vbCrLf
             + QUOTENAME(COLS.[name])
             + ' '
             + SPACE(@STRINGLEN - LEN(COLS.[name]))
             + 'AS ' + ISNULL(CALC.definition,'')
             + CASE 
                 WHEN CALC.is_persisted = 1 
                 THEN ' PERSISTED'
                 ELSE ''
               END
        ELSE @vbCrLf
             + QUOTENAME(COLS.[name])
             + ' '
             + SPACE(@STRINGLEN - LEN(COLS.[name]))
             + UPPER(TYPE_NAME(COLS.[user_type_id]))
             + CASE
--IE NUMERIC(10,2)
               WHEN TYPE_NAME(COLS.[user_type_id]) IN ('decimal','numeric')
               THEN '('
                    + CONVERT(VARCHAR,COLS.[precision])
                    + ','
                    + CONVERT(VARCHAR,COLS.[scale])
                    + ') '
                    + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[precision])
                    + ','
                    + CONVERT(VARCHAR,COLS.[scale])))
                    + SPACE(7)
                    + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                    + CASE
                        WHEN COLUMNPROPERTY ( @TABLE_ID , COLS.[name] , 'IsIdentity' ) = 0
                        THEN ''
                        ELSE ' IDENTITY('
                               + CONVERT(VARCHAR,ISNULL(IDENT_SEED(@TBLNAME),1) )
                               + ','
                               + CONVERT(VARCHAR,ISNULL(IDENT_INCR(@TBLNAME),1) )
                               + ')'
                        END

                    + CASE
                        WHEN COLS.[is_nullable] = 0
                        THEN ' NOT NULL'
                        ELSE '     NULL'
                      END
--IE FLOAT(53)
               WHEN  TYPE_NAME(COLS.[user_type_id]) IN ('float') --,'real')
               THEN
               --addition: if 53, no need to specifically say (53), otherwise display it
                    CASE
                      WHEN COLS.[precision] = 53
                      THEN SPACE(11 - LEN(CONVERT(VARCHAR,COLS.[precision])))
                           + SPACE(7)
                           + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                      ELSE '('
                           + CONVERT(VARCHAR,COLS.[precision])
                           + ') '
                           + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[precision])))
                           + SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                      END
--ie VARCHAR(40)
--##############################################################################
-- COLLATE STATEMENTS
-- personally i do not like collation statements,
-- but included here to make it easy on those who do
--##############################################################################
               WHEN  TYPE_NAME(COLS.[user_type_id]) IN ('char','varchar')
               THEN CASE
                      WHEN  COLS.[max_length] = -1
                      THEN  '(max)'
                            + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[max_length])))
                            + SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                            ----collate to comment out when not desired
                            --+ CASE
                            --    WHEN COLS.collation_name IS NULL
                            --    THEN ''
                            --    ELSE ' COLLATE ' + COLS.collation_name
                            --  END
                            + CASE
                                WHEN COLS.[is_nullable] = 0
                                THEN ' NOT NULL'
                                ELSE '     NULL'
                              END
                      ELSE '('
                           + CONVERT(VARCHAR,COLS.[max_length])
                           + ') '
                           + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[max_length])))
                           + SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           ----collate to comment out when not desired
                           --+ CASE
                           --     WHEN COLS.collation_name IS NULL
                           --     THEN ''
                           --     ELSE ' COLLATE ' + COLS.collation_name
                           --   END
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                    END
--ie NVARCHAR(40)
               WHEN TYPE_NAME(COLS.[user_type_id]) IN ('nchar','nvarchar')
               THEN CASE
                      WHEN  COLS.[max_length] = -1
                      THEN '(max)'
                           + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length] / 2))))
                           + SPACE(7)
                           + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           ----collate to comment out when not desired
                           --+ CASE
                           --     WHEN COLS.collation_name IS NULL
                           --     THEN ''
                           --     ELSE ' COLLATE ' + COLS.collation_name
                           --   END
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN  ' NOT NULL'
                               ELSE '     NULL'
                             END
                      ELSE '('
                           + CONVERT(VARCHAR,(COLS.[max_length] / 2))
                           + ') '
                           + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length] / 2))))
                           + SPACE(7)
                           + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           ----collate to comment out when not desired
                           --+ CASE
                           --     WHEN COLS.collation_name IS NULL
                           --     THEN ''
                           --     ELSE ' COLLATE ' + COLS.collation_name
                           --   END
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                    END
--ie datetime
               WHEN TYPE_NAME(COLS.[user_type_id]) IN ('datetime','money','text','image','real')
               THEN SPACE(18 - LEN(TYPE_NAME(COLS.[user_type_id])))
                    + '              '
                    + CASE
                        WHEN COLS.[is_nullable] = 0
                        THEN ' NOT NULL'
                        ELSE '     NULL'
                      END
--IE VARBINARY(500)
              WHEN TYPE_NAME(COLS.[user_type_id]) = 'varbinary'
              THEN
                CASE
                  WHEN COLS.[max_length] = -1
                  THEN '(max)'
                       + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length]))))
                       + SPACE(7)
                       + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                       + CASE WHEN COLS.[is_nullable] = 0
                           THEN ' NOT NULL'
                           ELSE ' NULL'
                         END
                  ELSE '('
                       + CONVERT(VARCHAR,(COLS.[max_length]))
                       + ') '
                       + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length]))))
                       + SPACE(7)
                       + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                       + CASE
                           WHEN COLS.[is_nullable] = 0
                           THEN ' NOT NULL'
                           ELSE ' NULL'
                         END
                END
--IE INT
               ELSE SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                            + CASE
                                WHEN COLUMNPROPERTY ( @TABLE_ID , COLS.[name] , 'IsIdentity' ) = 0
                                THEN '              '
                                ELSE ' IDENTITY('
                                     + CONVERT(VARCHAR,ISNULL(IDENT_SEED(@TBLNAME),1) )
                                     + ','
                                     + CONVERT(VARCHAR,ISNULL(IDENT_INCR(@TBLNAME),1) )
                                     + ')'
                              END
                            + SPACE(2)
                            + CASE
                                WHEN COLS.[is_nullable] = 0
                                THEN ' NOT NULL'
                                ELSE '     NULL'
                              END
               END
             + CASE
                 WHEN COLS.[default_object_id] = 0
                 THEN ''
                 --ELSE ' DEFAULT '  + ISNULL(def.[definition] ,'')
                 --optional section in case NAMED default constraints are needed:
                 ELSE '  CONSTRAINT ' + quotename(def.name) + ' DEFAULT ' + ISNULL(def.[definition] ,'')
                        --i thought it needed to be handled differently! NOT!
               END  --CASE cdefault
      END --iscomputed
    + ','
    FROM sys.columns COLS
      LEFT OUTER JOIN  sys.default_constraints  DEF
        ON COLS.[default_object_id] = DEF.[object_id]
      LEFT OUTER JOIN sys.computed_columns CALC
         ON  COLS.[object_id] = CALC.[object_id]
         AND COLS.[column_id] = CALC.[column_id]
    WHERE COLS.[object_id]=@TABLE_ID
    ORDER BY COLS.[column_id]
--##############################################################################
--used for formatting the rest of the constraints:
--##############################################################################
  SELECT
    @STRINGLEN = MAX(LEN([name])) + 1
  FROM sys.objects OBJS
--##############################################################################
--PK/Unique Constraints and Indexes, using the 2005/08 INCLUDE syntax
--##############################################################################
  DECLARE @Results  TABLE (
                    [SCHEMA_ID]             INT,
                    [SCHEMA_NAME]           VARCHAR(255),
                    [OBJECT_ID]             INT,
                    [OBJECT_NAME]           VARCHAR(255),
                    [index_id]              INT,
                    [index_name]            VARCHAR(255),
                    [ROWS]                  BIGINT,
                    [SizeMB]                DECIMAL(19,3),
                    [IndexDepth]            INT,
                    [TYPE]                  INT,
                    [type_desc]             VARCHAR(30),
                    [fill_factor]           INT,
                    [is_unique]             INT,
                    [is_primary_key]        INT ,
                    [is_unique_constraint]  INT,
                    [index_columns_key]     VARCHAR(MAX),
                    [index_columns_include] VARCHAR(MAX),
                    [has_filter] bit ,
                    [filter_definition] VARCHAR(MAX))
  INSERT INTO @Results
    SELECT
      SCH.schema_id, SCH.[name] AS SCHEMA_NAME,
      OBJS.[object_id], OBJS.[name] AS OBJECT_NAME,
      IDX.index_id, ISNULL(IDX.[name], '---') AS index_name,
      partitions.Rows, partitions.SizeMB, INDEXPROPERTY(OBJS.[object_id], IDX.[name], 'IndexDepth') AS IndexDepth,
      IDX.type, IDX.type_desc, IDX.fill_factor,
      IDX.is_unique, IDX.is_primary_key, IDX.is_unique_constraint,
      ISNULL(Index_Columns.index_columns_key, '---') AS index_columns_key,
      ISNULL(Index_Columns.index_columns_include, '---') AS index_columns_include,
      IDX.[has_filter],
      IDX.[filter_definition]
    FROM sys.objects OBJS
      INNER JOIN sys.schemas SCH ON OBJS.schema_id=SCH.schema_id
      INNER JOIN sys.indexes IDX ON OBJS.[object_id]=IDX.[object_id]
      INNER JOIN (
                  SELECT
                    [OBJECT_ID], index_id, SUM(row_count) AS ROWS,
                    CONVERT(NUMERIC(19,3), CONVERT(NUMERIC(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(NUMERIC(19,3), 128)) AS SizeMB
                  FROM sys.dm_db_partition_stats STATS
                  GROUP BY [OBJECT_ID], index_id
                 ) AS partitions 
        ON  IDX.[object_id]=partitions.[object_id] 
        AND IDX.index_id=partitions.index_id

    CROSS APPLY (
                 SELECT
                   LEFT(index_columns_key, LEN(index_columns_key)-1) AS index_columns_key,
                  LEFT(index_columns_include, LEN(index_columns_include)-1) AS index_columns_include
                 FROM
                      (
                       SELECT
                              (
                              SELECT QUOTENAME(COLS.[name]) + CASE WHEN IXCOLS.is_descending_key = 0 THEN ' asc' ELSE ' desc' END + ',' + ' '
                               FROM sys.index_columns IXCOLS
                                 INNER JOIN sys.columns COLS
                                   ON  IXCOLS.column_id   = COLS.column_id
                                   AND IXCOLS.[object_id] = COLS.[object_id]
                               WHERE IXCOLS.is_included_column = 0
                                 AND IDX.[object_id] = IXCOLS.[object_id] 
                                 AND IDX.index_id = IXCOLS.index_id
                               ORDER BY key_ordinal
                               FOR XML PATH('')
                              ) AS index_columns_key,
                             (
                             SELECT QUOTENAME(COLS.[name]) + ',' + ' '
                              FROM sys.index_columns IXCOLS
                                INNER JOIN sys.columns COLS
                                  ON  IXCOLS.column_id   = COLS.column_id
                                  AND IXCOLS.[object_id] = COLS.[object_id]
                              WHERE IXCOLS.is_included_column = 1
                                AND IDX.[object_id] = IXCOLS.[object_id] 
                                AND IDX.index_id = IXCOLS.index_id
                              ORDER BY index_column_id
                              FOR XML PATH('')
                             ) AS index_columns_include
                      ) AS Index_Columns
                ) AS Index_Columns
    WHERE SCH.[name]  LIKE CASE 
                                     WHEN @SCHEMANAME = '' 
                                     THEN SCH.[name] 
                                     ELSE @SCHEMANAME 
                                   END
    AND OBJS.[name] LIKE CASE 
                                  WHEN @TBLNAME = ''  
                                  THEN OBJS.[name] 
                                  ELSE @TBLNAME 
                                END
    ORDER BY 
      SCH.[name], 
      OBJS.[name], 
      IDX.[name]
--@Results table has both PK,s Uniques and indexes in thme...pull them out for adding to funal results:
  SET @CONSTRAINTSQLS = ''
  SET @INDEXSQLS      = ''

--##############################################################################
--constriants
--##############################################################################
  SELECT @CONSTRAINTSQLS = @CONSTRAINTSQLS 
         + CASE
             WHEN is_primary_key = 1 OR is_unique = 1
             THEN @vbCrLf
                  + 'CONSTRAINT   ' + quotename(index_name) + ' '
                  + CASE  
                      WHEN is_primary_key = 1 
                      THEN ' PRIMARY KEY ' 
                      ELSE CASE  
                             WHEN is_unique = 1     
                             THEN ' UNIQUE      '      
                             ELSE '' 
                           END 
                    END
                  + type_desc 
                  + CASE 
                      WHEN type_desc='NONCLUSTERED' 
                      THEN '' 
                      ELSE '   ' 
                    END
                  + ' (' + index_columns_key + ')'
                  + CASE 
                      WHEN index_columns_include <> '---' 
                      THEN ' INCLUDE (' + index_columns_include + ')' 
                      ELSE '' 
                    END
                  + CASE 
                      WHEN fill_factor <> 0 
                      THEN ' WITH FILLFACTOR = ' + CONVERT(VARCHAR(30),fill_factor) 
                      ELSE '' 
                    END
             ELSE ''
           END + ','
  FROM @RESULTS
  WHERE [type_desc] != 'HEAP'
    AND is_primary_key = 1 
    OR  is_unique = 1
  ORDER BY 
    is_primary_key DESC,
    is_unique DESC
--##############################################################################
--indexes
--##############################################################################
  SELECT @INDEXSQLS = @INDEXSQLS 
         + CASE
             WHEN is_primary_key = 0 OR is_unique = 0
             THEN @vbCrLf
                  + 'CREATE ' + type_desc + ' INDEX ' + quotename(index_name) + ' '
                  + @vbCrLf
                  + '   ON ' + quotename([schema_name]) + '.' + quotename([OBJECT_NAME])
                  + ' (' + index_columns_key + ')'
                  + CASE 
                     WHEN index_columns_include <> '---' 
                     THEN @vbCrLf + '   INCLUDE (' + index_columns_include + ')' 
                     ELSE '' 
                   END
                  --2008 filtered indexes syntax
                  + CASE 
                      WHEN has_filter = 1 
                      THEN @vbCrLf + '   WHERE ' + filter_definition
                      ELSE ''
                    END
                  + CASE 
                      WHEN fill_factor <> 0 
                      THEN @vbCrLf + '   WITH FILLFACTOR = ' + CONVERT(VARCHAR(30),fill_factor) 
                      ELSE '' 
                    END
           END
  FROM @RESULTS
  WHERE [type_desc] != 'HEAP'
    AND is_primary_key = 0 
    AND is_unique = 0
  ORDER BY 
    is_primary_key DESC,
    is_unique DESC

  IF @INDEXSQLS <> ''
    SET @INDEXSQLS = @vbCrLf + 'GO' + @vbCrLf + @INDEXSQLS
--##############################################################################
--CHECK Constraints
--##############################################################################
  SET @CHECKCONSTSQLS = ''
  SELECT
    @CHECKCONSTSQLS = @CHECKCONSTSQLS
    + @vbCrLf
    + ISNULL('CONSTRAINT   ' + quotename(OBJS.[name]) + ' '
    + SPACE(@STRINGLEN - LEN(OBJS.[name]))
    + ' CHECK ' + ISNULL(CHECKS.definition,'')
    + ',','')
  FROM sys.objects OBJS
    INNER JOIN sys.check_constraints CHECKS ON OBJS.[object_id] = CHECKS.[object_id]
  WHERE OBJS.type = 'C'
    AND OBJS.parent_object_id = @TABLE_ID
--##############################################################################
--FOREIGN KEYS
--##############################################################################
  SET @FKSQLS = '' ;
  SELECT
    @FKSQLS=@FKSQLS
    + @vbCrLf
    + 'CONSTRAINT   ' + quotename(OBJECT_NAME(constid)) + ''
    + SPACE(@STRINGLEN - LEN(OBJECT_NAME(constid) ))
    + '  FOREIGN KEY ('   + quotename(COL_NAME(fkeyid,fkey))
    + ') REFERENCES '    + quotename(OBJECT_NAME(rkeyid))
    +'(' + quotename(COL_NAME(rkeyid,rkey)) + '),'
  FROM sysforeignkeys FKEYS
  WHERE fkeyid = @TABLE_ID
--##############################################################################
--RULES
--##############################################################################
  SET @RULESCONSTSQLS = ''
  SELECT
    @RULESCONSTSQLS = @RULESCONSTSQLS
    + ISNULL(
             @vbCrLf
             + 'if not exists(SELECT [name] FROM sys.objects WHERE TYPE=''R'' AND schema_id = ' + CONVERT(VARCHAR(30),OBJS.schema_id) + ' AND [name] = ''' + quotename(OBJECT_NAME(COLS.[rule_object_id])) + ''')' + @vbCrLf
             + MODS.definition  + @vbCrLf + 'GO' +  @vbCrLf
             + 'EXEC sp_binderule  ' + quotename(OBJS.[name]) + ', ''' + quotename(OBJECT_NAME(COLS.[object_id])) + '.' + quotename(COLS.[name]) + '''' + @vbCrLf + 'GO' ,'')
  FROM sys.columns COLS 
    INNER JOIN sys.objects OBJS
      ON OBJS.[object_id] = COLS.[object_id]
    INNER JOIN sys.sql_modules MODS
      ON COLS.[rule_object_id] = MODS.[object_id]
  WHERE COLS.[rule_object_id] <> 0
    AND COLS.[object_id] = @TABLE_ID
--##############################################################################
--TRIGGERS
--##############################################################################
  SET @TRIGGERSTATEMENT = ''
  SELECT
    @TRIGGERSTATEMENT = @TRIGGERSTATEMENT +  @vbCrLf + MODS.[definition] + @vbCrLf + 'GO'
  FROM sys.sql_modules MODS
  WHERE [OBJECT_ID] IN(SELECT
                         [OBJECT_ID]
                       FROM sys.objects OBJS
                       WHERE TYPE = 'TR'
                       AND [parent_object_id] = @TABLE_ID)
  IF @TRIGGERSTATEMENT <> ''
    SET @TRIGGERSTATEMENT = @vbCrLf + 'GO' + @vbCrLf + @TRIGGERSTATEMENT
--##############################################################################
--NEW SECTION QUERY ALL EXTENDED PROPERTIES
--##############################################################################
  SET @EXTENDEDPROPERTIES = ''
  SELECT  @EXTENDEDPROPERTIES =
          @EXTENDEDPROPERTIES + @vbCrLf +
         'EXEC sys.sp_addextendedproperty
          @name = N''' + [name] + ''', @value = N''' + REPLACE(CONVERT(VARCHAR(MAX),[VALUE]),'''','''''') + ''',
          @level0type = N''SCHEMA'', @level0name = ' + quotename(@SCHEMANAME) + ',
          @level1type = N''TABLE'', @level1name = ' + quotename(@TBLNAME) + ';'
 --SELECT objtype, objname, name, value
  FROM fn_listextendedproperty (NULL, 'schema', @SCHEMANAME, 'table', @TBLNAME, NULL, NULL);
  --OMacoder suggestion for column extended properties http://www.sqlservercentral.com/Forums/FindPost1651606.aspx
  SELECT @EXTENDEDPROPERTIES =
         @EXTENDEDPROPERTIES + @vbCrLf +
         'EXEC sys.sp_addextendedproperty
         @name = N''' + [name] + ''', @value = N''' + REPLACE(convert(varchar(max),[value]),'''','''''') + ''',
         @level0type = N''SCHEMA'', @level0name = ' + quotename(@SCHEMANAME) + ',
         @level1type = N''TABLE'', @level1name = ' + quotename(@TBLNAME) + ',
         @level2type = N''COLUMN'', @level2name = ' + quotename([objname]) + ';'
  --SELECT objtype, objname, name, value
  FROM fn_listextendedproperty (NULL, 'schema', @SCHEMANAME, 'table', @TBLNAME, 'column', NULL)

  IF @EXTENDEDPROPERTIES <> ''
    SET @EXTENDEDPROPERTIES = @vbCrLf + 'GO' + @vbCrLf + @EXTENDEDPROPERTIES
--##############################################################################
--FINAL CLEANUP AND PRESENTATION
--##############################################################################
--at this point, there is a trailing comma, or it blank
  SELECT
    @FINALSQL = @FINALSQL
                + @CONSTRAINTSQLS
                + @CHECKCONSTSQLS
                + @FKSQLS
--note that this trims the trailing comma from the end of the statements
  SET @FINALSQL = SUBSTRING(@FINALSQL,1,LEN(@FINALSQL) -1) ;
  SET @FINALSQL = @FINALSQL + ')' + @vbCrLf ;

  SET @input = @vbCrLf
       + @FINALSQL
       + @INDEXSQLS
       + @RULESCONSTSQLS
       + @TRIGGERSTATEMENT
       + @EXTENDEDPROPERTIES
  --ten years worth of days from todays date:
   ;WITH E01(N) AS (SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1), --         10 or 10E01 rows
         E02(N) AS (SELECT 1 FROM E01 a, E01 b),  --        100 or 10E02 rows
         E04(N) AS (SELECT 1 FROM E02 a, E02 b),  --     10,000 or 10E04 rows
         E08(N) AS (SELECT 1 FROM E04 a, E04 b),  --100,000,000 or 10E08 rows
         --E16(N) AS (SELECT 1 FROM E08 a, E08 b),  --10E16 or more rows than you'll EVER need,
         Tally(N) AS (SELECT ROW_NUMBER() OVER (ORDER BY N) FROM E08),
       ItemSplit(
                 ItemOrder,
                 Item
                ) AS (
                      SELECT N,
                        SUBSTRING(@vbCrLf + @input + @vbCrLf,N + DATALENGTH(@vbCrLf),CHARINDEX(@vbCrLf,@vbCrLf + @input + @vbCrLf,N + DATALENGTH(@vbCrLf)) - N - DATALENGTH(@vbCrLf))
                      FROM Tally
                      WHERE N < DATALENGTH(@vbCrLf + @input)
                      --WHERE N < DATALENGTH(@vbCrLf + @input) -- REMOVED added @vbCrLf
                        AND SUBSTRING(@vbCrLf + @input + @vbCrLf,N,DATALENGTH(@vbCrLf)) = @vbCrLf --Notice how we find the delimiter
                     )
  SELECT
    --row_number() over (order by ItemOrder) as ItemID,
    Item
  FROM ItemSplit
  RETURN;     
--##############################################################################
-- END Normal Table Processing
--############################################################################## 
    
--simple, primitive version to get the results of a TEMP table from the TEMP db.  
--##############################################################################
-- NEW Temp Table Logic
--##############################################################################     
TEMPPROCESS:
  SELECT @TABLE_ID = OBJECT_ID('tempdb..' + @TBLNAME)

--##############################################################################
-- Valid temp Table, Continue Processing
--##############################################################################
SELECT 
  @FINALSQL =  'IF OBJECT_ID(''tempdb.' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ''') IS NOT NULL ' + @vbcrlf
               + 'DROP TABLE ' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@TBLNAME) + ' ' + @vbcrlf + 'GO' + @vbcrlf
               + 'CREATE TABLE ' + quotename(@SCHEMANAME) + '.' + quotename(@TBLNAME) + ' ( '
  --removed invalud cide here which potentially selected wrong table--thansk David Grifiths @SSC!
  SELECT
    @STRINGLEN = MAX(LEN(COLS.[name])) + 1
  FROM tempdb.sys.objects OBJS
    INNER JOIN tempdb.sys.columns COLS
      ON  OBJS.[object_id] = COLS.[object_id]
      AND OBJS.[object_id] = @TABLE_ID;
--##############################################################################
--Get the columns, their definitions and defaults.
--##############################################################################
  SELECT
    @FINALSQL = @FINALSQL
    + CASE
        WHEN COLS.[is_computed] = 1
        THEN @vbCrLf
             + QUOTENAME(COLS.[name])
             + ' '
             + SPACE(@STRINGLEN - LEN(COLS.[name]))
             + 'AS ' + ISNULL(CALC.definition,'')
              + CASE 
                 WHEN CALC.is_persisted = 1 
                 THEN ' PERSISTED'
                 ELSE ''
               END
        ELSE @vbCrLf
             + QUOTENAME(COLS.[name])
             + ' '
             + SPACE(@STRINGLEN - LEN(COLS.[name]))
             + UPPER(TYPE_NAME(COLS.[user_type_id]))
             + CASE
--IE NUMERIC(10,2)
               WHEN TYPE_NAME(COLS.[user_type_id]) IN ('decimal','numeric')
               THEN '('
                    + CONVERT(VARCHAR,COLS.[precision])
                    + ','
                    + CONVERT(VARCHAR,COLS.[scale])
                    + ') '
                    + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[precision])
                    + ','
                    + CONVERT(VARCHAR,COLS.[scale])))
                    + SPACE(7)
                    + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                    + CASE
                        WHEN COLS.is_identity = 1
                        THEN ' IDENTITY(1,1)'
                        ELSE ''
                        ----WHEN COLUMNPROPERTY ( @TABLE_ID , COLS.[name] , 'IsIdentity' ) = 1
                        ----THEN ' IDENTITY('
                        ----       + CONVERT(VARCHAR,ISNULL(IDENT_SEED('tempdb..' + @TBLNAME),1) )
                        ----       + ','
                        ----       + CONVERT(VARCHAR,ISNULL(IDENT_INCR('tempdb..' + @TBLNAME),1) )
                        ----       + ')'
                        ----ELSE ''
                        END

                    + CASE
                        WHEN COLS.[is_nullable] = 0
                        THEN ' NOT NULL'
                        ELSE '     NULL'
                      END
--IE FLOAT(53)
               WHEN  TYPE_NAME(COLS.[user_type_id]) IN ('float') --,'real')
               THEN
               --addition: if 53, no need to specifically say (53), otherwise display it
                    CASE
                      WHEN COLS.[precision] = 53
                      THEN SPACE(11 - LEN(CONVERT(VARCHAR,COLS.[precision])))
                           + SPACE(7)
                           + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                      ELSE '('
                           + CONVERT(VARCHAR,COLS.[precision])
                           + ') '
                           + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[precision])))
                           + SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                      END
--ie VARCHAR(40)
--##############################################################################
-- COLLATE STATEMENTS in tempdb!
-- personally i do not like collation statements,
-- but included here to make it easy on those who do
--##############################################################################

               WHEN  TYPE_NAME(COLS.[user_type_id]) IN ('char','varchar')
               THEN CASE
                      WHEN  COLS.[max_length] = -1
                      THEN  '(max)'
                            + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[max_length])))
                            + SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                            ----collate to comment out when not desired
                            --+ CASE
                            --    WHEN COLS.collation_name IS NULL
                            --    THEN ''
                            --    ELSE ' COLLATE ' + COLS.collation_name
                            --  END
                            + CASE
                                WHEN COLS.[is_nullable] = 0
                                THEN ' NOT NULL'
                                ELSE '     NULL'
                              END
                      ELSE '('
                           + CONVERT(VARCHAR,COLS.[max_length])
                           + ') '
                           + SPACE(6 - LEN(CONVERT(VARCHAR,COLS.[max_length])))
                           + SPACE(7) + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           ----collate to comment out when not desired
                           --+ CASE
                           --     WHEN COLS.collation_name IS NULL
                           --     THEN ''
                           --     ELSE ' COLLATE ' + COLS.collation_name
                           --   END
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                    END
--ie NVARCHAR(40)
               WHEN TYPE_NAME(COLS.[user_type_id]) IN ('nchar','nvarchar')
               THEN CASE
                      WHEN  COLS.[max_length] = -1
                      THEN '(max)'
                           + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length] / 2))))
                           + SPACE(7)
                           + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           -- --collate to comment out when not desired
                           --+ CASE
                           --     WHEN COLS.collation_name IS NULL
                           --     THEN ''
                           --     ELSE ' COLLATE ' + COLS.collation_name
                           --   END
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN  ' NOT NULL'
                               ELSE '     NULL'
                             END
                      ELSE '('
                           + CONVERT(VARCHAR,(COLS.[max_length] / 2))
                           + ') '
                           + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length] / 2))))
                           + SPACE(7)
                           + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                           -- --collate to comment out when not desired
                           --+ CASE
                           --     WHEN COLS.collation_name IS NULL
                           --     THEN ''
                           --     ELSE ' COLLATE ' + COLS.collation_name
                           --   END
                           + CASE
                               WHEN COLS.[is_nullable] = 0
                               THEN ' NOT NULL'
                               ELSE '     NULL'
                             END
                    END
--ie datetime
               WHEN TYPE_NAME(COLS.[user_type_id]) IN ('datetime','money','text','image','real')
               THEN SPACE(18 - LEN(TYPE_NAME(COLS.[user_type_id])))
                    + '              '
                    + CASE
                        WHEN COLS.[is_nullable] = 0
                        THEN ' NOT NULL'
                        ELSE '     NULL'
                      END
--IE VARBINARY(500)
              WHEN TYPE_NAME(COLS.[user_type_id]) = 'varbinary'
              THEN
                CASE
                  WHEN COLS.[max_length] = -1
                  THEN '(max)'
                       + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length]))))
                       + SPACE(7)
                       + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                       + CASE WHEN COLS.[is_nullable] = 0
                           THEN ' NOT NULL'
                           ELSE ' NULL'
                         END
                  ELSE '('
                       + CONVERT(VARCHAR,(COLS.[max_length]))
                       + ') '
                       + SPACE(6 - LEN(CONVERT(VARCHAR,(COLS.[max_length]))))
                       + SPACE(7)
                       + SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                       + CASE
                           WHEN COLS.[is_nullable] = 0
                           THEN ' NOT NULL'
                           ELSE ' NULL'
                         END
                END
--IE INT
               ELSE SPACE(16 - LEN(TYPE_NAME(COLS.[user_type_id])))
                            + CASE
                                WHEN COLS.is_identity = 1
                                THEN ' IDENTITY(1,1)'
                                ELSE '              '
                                ----WHEN COLUMNPROPERTY ( @TABLE_ID , COLS.[name] , 'IsIdentity' ) = 1
                                ----THEN ' IDENTITY('
                                ----     + CONVERT(VARCHAR,ISNULL(IDENT_SEED('tempdb..' + @TBLNAME),1) )
                                ----     + ','
                                ----     + CONVERT(VARCHAR,ISNULL(IDENT_INCR('tempdb..' + @TBLNAME),1) )
                                ----     + ')'
                                ----ELSE '              '
                              END
                            + SPACE(2)
                            + CASE
                                WHEN COLS.[is_nullable] = 0
                                THEN ' NOT NULL'
                                ELSE '     NULL'
                              END
               END
             + CASE
                 WHEN COLS.[default_object_id] = 0
                 THEN ''
                 ELSE ' DEFAULT '  + ISNULL(def.[definition] ,'')
                 --optional section in case NAMED default cosntraints are needed:
                 --ELSE ' CONSTRAINT [' + def.name + '] DEFAULT '+ REPLACE(REPLACE(ISNULL(def.[definition] ,''),'((','('),'))',')')
                        --i thought it needed to be handled differently! NOT!
               END  --CASE cdefault



      END --iscomputed
    + ','
    FROM tempdb.sys.columns COLS
      LEFT OUTER JOIN  tempdb.sys.default_constraints  DEF
        ON COLS.[default_object_id] = DEF.[object_id]
      LEFT OUTER JOIN tempdb.sys.computed_columns CALC
         ON  COLS.[object_id] = CALC.[object_id]
         AND COLS.[column_id] = CALC.[column_id]
    WHERE COLS.[object_id]=@TABLE_ID
    ORDER BY COLS.[column_id]
--##############################################################################
--used for formatting the rest of the constraints:
--##############################################################################
  SELECT
    @STRINGLEN = MAX(LEN([name])) + 1
  FROM tempdb.sys.objects OBJS
--##############################################################################
--PK/Unique Constraints and Indexes, using the 2005/08 INCLUDE syntax
--##############################################################################
  DECLARE @Results2  TABLE (
                    [SCHEMA_ID]             INT,
                    [SCHEMA_NAME]           VARCHAR(255),
                    [OBJECT_ID]             INT,
                    [OBJECT_NAME]           VARCHAR(255),
                    [index_id]              INT,
                    [index_name]            VARCHAR(255),
                    [ROWS]                  BIGINT,
                    [SizeMB]                DECIMAL(19,3),
                    [IndexDepth]            INT,
                    [TYPE]                  INT,
                    [type_desc]             VARCHAR(30),
                    [fill_factor]           INT,
                    [is_unique]             INT,
                    [is_primary_key]        INT ,
                    [is_unique_constraint]  INT,
                    [index_columns_key]     VARCHAR(MAX),
                    [index_columns_include] VARCHAR(MAX),
                    [has_filter] bit ,
                    [filter_definition] VARCHAR(MAX))
  INSERT INTO @Results2
    SELECT
      SCH.schema_id, SCH.[name] AS SCHEMA_NAME,
      OBJS.[object_id], OBJS.[name] AS OBJECT_NAME,
      IDX.index_id, ISNULL(IDX.[name], '---') AS index_name,
      partitions.Rows, partitions.SizeMB, INDEXPROPERTY(OBJS.[object_id], IDX.[name], 'IndexDepth') AS IndexDepth,
      IDX.type, IDX.type_desc, IDX.fill_factor,
      IDX.is_unique, IDX.is_primary_key, IDX.is_unique_constraint,
      ISNULL(Index_Columns.index_columns_key, '---') AS index_columns_key,
      ISNULL(Index_Columns.index_columns_include, '---') AS index_columns_include,
      IDX.has_filter,
      IDX.filter_definition
    FROM tempdb.sys.objects OBJS
      INNER JOIN tempdb.sys.schemas SCH ON OBJS.schema_id=SCH.schema_id
      INNER JOIN tempdb.sys.indexes IDX ON OBJS.[object_id]=IDX.[object_id]
      INNER JOIN (
                  SELECT
                    [OBJECT_ID], index_id, SUM(row_count) AS ROWS,
                    CONVERT(NUMERIC(19,3), CONVERT(NUMERIC(19,3), SUM(in_row_reserved_page_count+lob_reserved_page_count+row_overflow_reserved_page_count))/CONVERT(NUMERIC(19,3), 128)) AS SizeMB
                  FROM tempdb.sys.dm_db_partition_stats STATS
                  GROUP BY [OBJECT_ID], index_id
                 ) AS partitions 
        ON  IDX.[object_id]=partitions.[object_id] 
        AND IDX.index_id=partitions.index_id
    CROSS APPLY (
                 SELECT
                   LEFT(index_columns_key, LEN(index_columns_key)-1) AS index_columns_key,
                  LEFT(index_columns_include, LEN(index_columns_include)-1) AS index_columns_include
                 FROM
                      (
                       SELECT
                              (
                              SELECT QUOTENAME(COLS.[name]) + CASE WHEN IXCOLS.is_descending_key = 0 THEN ' asc' ELSE ' desc' END + ',' + ' '
                               FROM tempdb.sys.index_columns IXCOLS
                                 INNER JOIN tempdb.sys.columns COLS
                                   ON  IXCOLS.column_id   = COLS.column_id
                                   AND IXCOLS.[object_id] = COLS.[object_id]
                               WHERE IXCOLS.is_included_column = 0
                                 AND IDX.[object_id] = IXCOLS.[object_id] 
                                 AND IDX.index_id = IXCOLS.index_id
                               ORDER BY key_ordinal
                               FOR XML PATH('')
                              ) AS index_columns_key,
                             (
                             SELECT QUOTENAME(COLS.[name]) + ',' + ' '
                              FROM tempdb.sys.index_columns IXCOLS
                                INNER JOIN tempdb.sys.columns COLS
                                  ON  IXCOLS.column_id   = COLS.column_id
                                  AND IXCOLS.[object_id] = COLS.[object_id]
                              WHERE IXCOLS.is_included_column = 1
                                AND IDX.[object_id] = IXCOLS.[object_id] 
                                AND IDX.index_id = IXCOLS.index_id
                              ORDER BY index_column_id
                              FOR XML PATH('')
                             ) AS index_columns_include
                      ) AS Index_Columns
                ) AS Index_Columns
    WHERE SCH.[name]  LIKE CASE 
                                     WHEN @SCHEMANAME = '' 
                                     THEN SCH.[name] 
                                     ELSE @SCHEMANAME 
                                   END
    AND OBJS.[name] LIKE CASE 
                                  WHEN @TBLNAME = ''  
                                  THEN OBJS.[name] 
                                  ELSE @TBLNAME 
                                END
    ORDER BY 
      SCH.[name], 
      OBJS.[name], 
      IDX.[name]
--@Results2 table has both PK,s Uniques and indexes in thme...pull them out for adding to funal results:
  SET @CONSTRAINTSQLS = ''
  SET @INDEXSQLS      = ''

--##############################################################################
--constriants
--##############################################################################
  SELECT @CONSTRAINTSQLS = @CONSTRAINTSQLS 
         + CASE
             WHEN is_primary_key = 1 OR is_unique = 1
             THEN @vbCrLf
                  + 'CONSTRAINT   ' + quotename(index_name) + ' '
                  + SPACE(@STRINGLEN - LEN(index_name))
                  + CASE  
                      WHEN is_primary_key = 1 
                      THEN ' PRIMARY KEY ' 
                      ELSE CASE  
                             WHEN is_unique = 1     
                             THEN ' UNIQUE      '      
                             ELSE '' 
                           END 
                    END
                  + type_desc 
                  + CASE 
                      WHEN type_desc='NONCLUSTERED' 
                      THEN '' 
                      ELSE '   ' 
                    END
                  + ' (' + index_columns_key + ')'
                  + CASE 
                      WHEN index_columns_include <> '---' 
                      THEN ' INCLUDE (' + index_columns_include + ')' 
                      ELSE '' 
                    END
                  + CASE 
                      WHEN fill_factor <> 0 
                      THEN ' WITH FILLFACTOR = ' + CONVERT(VARCHAR(30),fill_factor) 
                      ELSE '' 
                    END
             ELSE ''
           END + ','
  FROM @Results2
  WHERE [type_desc] != 'HEAP'
    AND is_primary_key = 1 
    OR  is_unique = 1
  ORDER BY 
    is_primary_key DESC,
    is_unique DESC
--##############################################################################
--indexes
--##############################################################################
  SELECT @INDEXSQLS = @INDEXSQLS 
         + CASE
             WHEN is_primary_key = 0 OR is_unique = 0
             THEN @vbCrLf
                  + 'CREATE ' + type_desc + ' INDEX ' + quotename(index_name) + ' '
                  + @vbCrLf
                   + '   ON ' + quotename([schema_name]) + '.' + quotename([OBJECT_NAME])
                  + ' (' + index_columns_key + ')'
                  + CASE 
                     WHEN index_columns_include <> '---' 
                     THEN @vbCrLf + '   INCLUDE (' + index_columns_include + ')' 
                     ELSE '' 
                   END
                  --2008 filtered indexes syntax
                  + CASE 
                      WHEN has_filter = 1 
                      THEN @vbCrLf + '   WHERE ' + filter_definition
                      ELSE ''
                    END
                  + CASE 
                      WHEN fill_factor <> 0 
                      THEN @vbCrLf + '   WITH FILLFACTOR = ' + CONVERT(VARCHAR(30),fill_factor) 
                      ELSE '' 
                    END
           END
  FROM @Results2
  WHERE [type_desc] != 'HEAP'
    AND is_primary_key = 0 
    AND is_unique = 0
  ORDER BY 
    is_primary_key DESC,
    is_unique DESC

  IF @INDEXSQLS <> ''
    SET @INDEXSQLS = @vbCrLf + 'GO' + @vbCrLf + @INDEXSQLS
--##############################################################################
--CHECK Constraints
--##############################################################################
  SET @CHECKCONSTSQLS = ''
  SELECT
    @CHECKCONSTSQLS = @CHECKCONSTSQLS
    + @vbCrLf
    + ISNULL('CONSTRAINT   ' + quotename(OBJS.[name]) + ' '
    + SPACE(@STRINGLEN - LEN(OBJS.[name]))
    + ' CHECK ' + ISNULL(CHECKS.definition,'')
    + ',','')
  FROM tempdb.sys.objects OBJS
    INNER JOIN tempdb.sys.check_constraints CHECKS ON OBJS.[object_id] = CHECKS.[object_id]
  WHERE OBJS.type = 'C'
    AND OBJS.parent_object_id = @TABLE_ID
--##############################################################################
--FOREIGN KEYS
--##############################################################################
  SET @FKSQLS = '' ;
  SELECT
    @FKSQLS=@FKSQLS
    + @vbCrLf
    + 'CONSTRAINT   ' + quotename(OBJECT_NAME(constid)) +''
    + SPACE(@STRINGLEN - LEN(OBJECT_NAME(constid) ))
    + '  FOREIGN KEY ('   + quotename(COL_NAME(fkeyid,fkey))
    + ') REFERENCES '    + quotename(OBJECT_NAME(rkeyid))
    +'(' + quotename(COL_NAME(rkeyid,rkey)) + '),'
  FROM sysforeignkeys FKEYS
  WHERE fkeyid = @TABLE_ID
--##############################################################################
--RULES
--##############################################################################
  SET @RULESCONSTSQLS = ''
  SELECT
    @RULESCONSTSQLS = @RULESCONSTSQLS
    + ISNULL(
             @vbCrLf
             + 'if not exists(SELECT [name] FROM tempdb.sys.objects WHERE TYPE=''R'' AND schema_id = ' + CONVERT(VARCHAR(30),OBJS.schema_id) + ' AND [name] = ''' + quotename(OBJECT_NAME(COLS.[rule_object_id])) + ''')' + @vbCrLf
             + MODS.definition  + @vbCrLf + 'GO' +  @vbCrLf
             + 'EXEC sp_binderule  ' + quotename(OBJS.[name]) + ', ''' + quotename(OBJECT_NAME(COLS.[object_id])) + '.' + quotename(COLS.[name]) + '''' + @vbCrLf + 'GO' ,'')
  FROM tempdb.sys.columns COLS 
    INNER JOIN tempdb.sys.objects OBJS
      ON OBJS.[object_id] = COLS.[object_id]
    INNER JOIN tempdb.sys.sql_modules MODS
      ON COLS.[rule_object_id] = MODS.[object_id]
  WHERE COLS.[rule_object_id] <> 0
    AND COLS.[object_id] = @TABLE_ID
--##############################################################################
--TRIGGERS
--##############################################################################
  SET @TRIGGERSTATEMENT = ''
  SELECT
    @TRIGGERSTATEMENT = @TRIGGERSTATEMENT +  @vbCrLf + MODS.[definition] + @vbCrLf + 'GO'
  FROM tempdb.sys.sql_modules MODS
  WHERE [OBJECT_ID] IN(SELECT
                         [OBJECT_ID]
                       FROM tempdb.sys.objects OBJS
                       WHERE TYPE = 'TR'
                       AND [parent_object_id] = @TABLE_ID)
  IF @TRIGGERSTATEMENT <> ''
    SET @TRIGGERSTATEMENT = @vbCrLf + 'GO' + @vbCrLf + @TRIGGERSTATEMENT
--##############################################################################
--NEW SECTION QUERY ALL EXTENDED PROPERTIES
--##############################################################################
  SET @EXTENDEDPROPERTIES = ''
  SELECT  @EXTENDEDPROPERTIES =
          @EXTENDEDPROPERTIES + @vbCrLf +
         'EXEC tempdb.sys.sp_addextendedproperty
          @name = N''' + [name] + ''', @value = N''' + REPLACE(CONVERT(VARCHAR(MAX),[VALUE]),'''','''''') + ''',
          @level0type = N''SCHEMA'', @level0name = ' + quotename(@SCHEMANAME + ',
          @level1type = N''TABLE'', @level1name = [' + @TBLNAME) + '];'
 --SELECT objtype, objname, name, value
  FROM fn_listextendedproperty (NULL, 'schema', @SCHEMANAME, 'table', @TBLNAME, NULL, NULL);
  --OMacoder suggestion for column extended properties http://www.sqlservercentral.com/Forums/FindPost1651606.aspx
  SELECT @EXTENDEDPROPERTIES =
         @EXTENDEDPROPERTIES + @vbCrLf +
         'EXEC sys.sp_addextendedproperty
         @name = N''' + [name] + ''', @value = N''' + REPLACE(convert(varchar(max),[value]),'''','''''') + ''',
         @level0type = N''SCHEMA'', @level0name = ' + quotename(@SCHEMANAME) + ',
         @level1type = N''TABLE'', @level1name = ' + quotename(@TBLNAME) + ',
         @level2type = N''COLUMN'', @level2name = ' + quotename([objname]) + ';'
  --SELECT objtype, objname, name, value
  FROM fn_listextendedproperty (NULL, 'schema', @SCHEMANAME, 'table', @TBLNAME, 'column', NULL)

  IF @EXTENDEDPROPERTIES <> ''
    SET @EXTENDEDPROPERTIES = @vbCrLf + 'GO' + @vbCrLf + @EXTENDEDPROPERTIES
--##############################################################################
--FINAL CLEANUP AND PRESENTATION
--##############################################################################
--at this point, there is a trailing comma, or it blank
  SELECT
    @FINALSQL = @FINALSQL
                + @CONSTRAINTSQLS
                + @CHECKCONSTSQLS
                + @FKSQLS
--note that this trims the trailing comma from the end of the statements
  SET @FINALSQL = SUBSTRING(@FINALSQL,1,LEN(@FINALSQL) -1) ;
  SET @FINALSQL = @FINALSQL + ')' + @vbCrLf ;

  SET @input = @vbCrLf
       + @FINALSQL
       + @INDEXSQLS
       + @RULESCONSTSQLS
       + @TRIGGERSTATEMENT
       + @EXTENDEDPROPERTIES
--ten years worth of days from todays date:
   ;WITH E01(N) AS (SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1 UNION ALL
                    SELECT 1 UNION ALL SELECT 1), --         10 or 10E01 rows
         E02(N) AS (SELECT 1 FROM E01 a, E01 b),  --        100 or 10E02 rows
         E04(N) AS (SELECT 1 FROM E02 a, E02 b),  --     10,000 or 10E04 rows
         E08(N) AS (SELECT 1 FROM E04 a, E04 b),  --100,000,000 or 10E08 rows
         --E16(N) AS (SELECT 1 FROM E08 a, E08 b),  --10E16 or more rows than you'll EVER need,
         Tally(N) AS (SELECT ROW_NUMBER() OVER (ORDER BY N) FROM E08),
       ItemSplit(
                 ItemOrder,
                 Item
                ) AS (
                      SELECT N,
                        SUBSTRING(@vbCrLf + @input + @vbCrLf,N + DATALENGTH(@vbCrLf),CHARINDEX(@vbCrLf,@vbCrLf + @input + @vbCrLf,N + DATALENGTH(@vbCrLf)) - N - DATALENGTH(@vbCrLf))
                      FROM Tally
                      WHERE N < DATALENGTH(@vbCrLf + @input)
                      --WHERE N < DATALENGTH(@vbCrLf + @input) -- REMOVED added @vbCrLf
                        AND SUBSTRING(@vbCrLf + @input + @vbCrLf,N,DATALENGTH(@vbCrLf)) = @vbCrLf --Notice how we find the delimiter
                     )
  SELECT
    --row_number() over (order by ItemOrder) as ItemID,
    Item
  FROM ItemSplit
         
  RETURN;     
END --PROC
GO
--#################################################################################################
--Mark as a system object
EXECUTE sp_ms_marksystemobject 'sp_GetDDLa'
GRANT EXECUTE ON dbo.sp_GetDDLa TO PUBLIC;
--#################################################################################################
GO