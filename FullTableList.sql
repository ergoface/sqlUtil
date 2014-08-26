/**********************************************
* The Routine returns all tables and row counts for all databases in the instance
*
***********************************************/

DECLARE @DB  varchar(100), @stSQL nvarchar(800)
Declare @version Decimal(10,2)
--*************
SELECT @version = CAST(LEFT(CAST(SERVERPROPERTY('productversion') AS VARCHAR(20)),2)AS Decimal(10,2))
--SELECT @VERSION
-- Define cursor for all databases in the instance
-- Check for SQL version
if  @version < 9 -- SQL 2000
	Begin
		Declare dbcursor cursor fast_forward local
		for
		select name from master..sysdatabases
	end
ELSE			-- SQL 2005+
	Begin
        Declare dbcursor cursor fast_forward local
		for
        SELECT	name
			FROM master.sys.databases
			WHERE database_id > 4 
			 /* AND name = 'SingleDBYouWant'     **Uncomment this and put the database you want if you only want a single db ** */
			ORDER BY name 
	END

Open dbcursor
Fetch next from dbcursor into @DB

/* Continue until all databases traversed */
while @@fetch_status = 0
	begin	
		/* Get tables and row counts */
		
		Set @stSQL = '
		select ''' + @DB + ''' as DB, Tablename = t.name, Records = i.rows
				from ' + @DB +'..sysobjects t, ' + @DB + '..sysindexes i
				where t.xtype = ''U''
				and i.id = t.id
				and i.indid in (0,1)
				and t.type <> ''S'''

		execute (@stSQL)
		PRINT @stSQL
		Fetch next from dbcursor into @DB
	end

deallocate dbcursor