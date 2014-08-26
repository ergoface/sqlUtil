/* Query that exists to stress the CPU -- Just use to crank up CPU usage */
IF object_id('tempdb..#columns') is NOT NULL
DROP TABLE #columns
SELECT * INTO #columns
FROM sys.columns AS C 

DECLARE @RCNT int 
SET @RCNT = 0
SET NOCOUNT ON;
WHILE @RCNT = 0
BEGIN
 UPDATE #columns
 SET column_id = 0 
 WHERE ISNUMERIC(CONVERT(float, CONVERT(nvarchar(20), CONVERT(varchar(20), column_id)))) = 0
 SELECT @RCNT = @@ROWCOUNT 
END

-- Alternate version
--Declare @T DateTime,
--@F Bigint;
--Set @T=GetDate();
--While DATEADD(Second,180,@T)>GETDATE()
--Set @F=POWER(2,30);

