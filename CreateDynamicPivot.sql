ALTER PROCEDURE DynamicPivot
  ( @TargetTable VARCHAR(100),
    @PivotColumn VARCHAR(100),
    @AnchorColumn VARCHAR(100),
    @WhereClause AS VARCHAR(1000) = ' 1=1',
    @PivotValue VARCHAR(100),
    @Operation CHAR(3),
    @TempTableName VARCHAR(50)
)
/****************************************************************************************
* Take a Linear table and create a dynamically pivoted result.
* Author: Dave Bennett (Based partially on code from Lee Everest: http://sqlserverpedia.com/blog/sql-server-2008/dynamic-pivot-in-tsql/
* Created: 8/26/2011
* Last Modified: 8/26/2011
* Parameters:	@TargetTable VARCHAR(100) --> Table Containing table to pivot
				@PivotColumn VARCHAR(100) --> Column that will be generating the column names
				@AnchorColumn VARCHAR(100) --> Non-pivoted column
				@WhereClause AS VARCHAR(1000) (optional) --> Limiting where statement that limits exactly which columns in the target table are used
				@PivotValue VARCHAR(100) --> The Value that will be the subject of the pivot 
				@Operation CHAR(3) --> The Aggregation function used on the value (MAX, MIN, SUM, COUNT, etc)
				@TempTableName VARCHAR(50) --> Name to use for the Global Temp Table that contains the pivoted results
* Output: Global temp Pivoted table				
* Example: 
		EXEC [dbo].[DynamicPivot]
		@TargetTable = N'TaskFields',
		@PivotColumn = N'[KEY]',
		@AnchorColumn = N'TaskID',
		@PivotValue = N'Value',
		@WhereClause = ' TaskID between 20 and 24',
		@Operation = N'MAX',
		@TempTableName = 'Pivot_Out'

*****************************************************************************************/ 

AS
BEGIN
	SET NOCOUNT ON
	DECLARE @SQL AS VARCHAR(MAX)
	DECLARE @NewColumnList AS VARCHAR(MAX)
	DECLARE @TableDef VARCHAR(MAX)
	DECLARE @table TABLE
	   (
		SourceColumnNames VARCHAR(1000)
	   )
	INSERT @table
      EXEC ( 'SELECT ' + @PivotColumn + ' FROM ' + @TargetTable + ' WHERE ' + @WhereClause
          )
	SELECT @NewColumnList = COALESCE(@NewColumnList + ', ', '')
		  + QUOTENAME(SourceColumnNames)
	   FROM ( SELECT DISTINCT SourceColumnNames
				FROM @table
			) AS B
			
	SELECT @TableDef = @AnchorColumn + ' VARCHAR(200),' + REPLACE(@NewColumnList,']','] VARCHAR(2000)')
        
	SET @SQL = '
	IF OBJECT_ID(N''tempdb..##' + @TempTableName + ''',N''U'') is NOT null
		DRop Table ##' + @TempTableName + ' 
	CREATE TABLE ##' +@TempTableName + ' (' + @TableDef + ')
	'
	EXEC (@SQL);			

	SET @SQL = '
		WITH PivotData AS
		(
		SELECT
			   ' + @PivotColumn + ',
			   ' + @AnchorColumn + ',
			   ' + @PivotValue + '
		FROM ' + @TargetTable + '
		)
		INSERT INTO ##' + @TempTableName + '
		SELECT
			   ' + @AnchorColumn + ',
			   ' + @NewColumnList + '
		FROM PivotData
		PIVOT
		(
			   ' + @Operation + '(' + @PivotValue + ')
			   FOR ' + @PivotColumn + '
			   IN (' + @NewColumnList + ')
		) AS PivotResult
		ORDER BY ' + @AnchorColumn + ''

	EXEC (@SQL)	   

END
GO
