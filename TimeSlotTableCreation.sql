 DECLARE @StartDate AS datetime
    DECLARE @EndDate AS datetime

    SET @StartDate = '1/1/2012'
    SET @EndDate = '12/31/2017'

DECLARE @Slots TABLE (SlotID INT PRIMARY KEY IDENTITY(1,1),SlotTime DATETIME, WeekDay INT);

WITH Looper AS (
	SELECT @StartDate slottime
	UNION ALL
	SELECT DATEADD(minute,15,slottime)
	FROM Looper
	WHERE DATEADD(minute,15,slottime) <= @EndDate
	)
INSERT INTO @Slots
      ( SlotTime, WeekDay )
   
SELECT 	SlotTime, DATEPART(weekday,slottime)
FROM Looper
OPTION  (MAXRECURSION 0)

SELECT * FROM @Slots AS S