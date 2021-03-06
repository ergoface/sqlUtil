/* ***************************************************************************
 * This routine grants execute privilege to all procs in a given database to *
 * a specific user.                                                          *
 * ***************************************************************************/

USE [kar_channel_lineup] -- Database to use
DECLARE @DB  sysname ; set @DB = DB_NAME()
DECLARE @U  sysname ; set @U = QUOTENAME('CORP\VLandau') --Enter User to grant 

DECLARE @ID           integer,
        @LAST_ID     integer,
        @NAME        varchar(1000),
        @SQL         varchar(4000)

SET @LAST_ID = 0

WHILE @LAST_ID IS NOT NULL
BEGIN
    SELECT @ID = MIN(id)
    FROM dbo.sysobjects
    WHERE id > @LAST_ID  AND type = 'P' AND category = 0
    
    SET @LAST_ID = @ID
    
    -- We have a record so go get the name
    IF @ID IS NOT NULL
    BEGIN
        SELECT @NAME = name
        FROM dbo.sysobjects
        WHERE id = @ID
    
        -- Build the DCL to do the GRANT
        SET @SQL = 'GRANT EXECUTE ON ' + @NAME + ' TO ' + @U
        
        -- Run the SQL Statement you just generated
        EXEC master.dbo.xp_execresultset @SQL, @DB
    END 
END
