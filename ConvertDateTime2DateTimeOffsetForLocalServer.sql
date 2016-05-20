/*Example code for converting datetime to DateTimeOffset using server local time */
DECLARE @TimeZoneOffset INT,
        @DateTimeOnly DATETIME	;
SET @DateTimeOnly = GETDATE()

SELECT @TimeZoneOffset =  DATEDIFF(MINUTE,SYSUTCDATETIME(),SYSDATETIME()) 
SELECT TODATETIMEOFFSET(@DateTimeOnly,@TimeZoneOffset)


