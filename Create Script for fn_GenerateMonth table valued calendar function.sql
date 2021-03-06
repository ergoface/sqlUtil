USE ReportingMisc
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GenerateMonth]    Script Date: 11/6/2013 8:31:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fn_GenerateMonth](@MonthNum int, @Year int)
/**********************************************************************************************************************
* Name: fn_GenerateMonth
* Description: Returns all the days in a given month, including the previous, or next month days neccessary to display
*               a full 5 row calendar.
* Author: Brian Larson in Paul Turley's SQL Server Reporting Services Recipes
* Parameters: MonthNum ==> Int for number of month to display
*             Year     ==> Int four digit year
* Last Modified: 11/6/2013
* Last Modified by: Dave Bennett
* Example: Select * from fn_GenerateMonth(12,2012)
***********************************************************************************************************************/ 
RETURNS 
@Month TABLE 
(
	-- Add the column definitions for the TABLE variable here
	MonthDate datetime,
	DayNumber int, 
	DayName varchar(12),
	DayOfWeek int,
	WeekOfMonth int,
	MonthName varchar(12)
)
AS
BEGIN
	DECLARE @MonthDate datetime
	DECLARE @WeekOfMonth int
	DECLARE @WeekFillDate datetime
	DECLARE @MonthName	varchar(12)

	SET @WeekOfMonth = 1

	-- Find the first day of the month and the month name.
	SET @MonthDate = RIGHT('0' + CONVERT(varchar(2), @MonthNum),2) + '/01/' + CONVERT(char(4), @Year)
	SET @MonthName = DATENAME(mm, @MonthDate)
	
	-- Back up to the first day of the week containing the first day of the month.
	SET @WeekFillDate = @MonthDate
	WHILE DATEPART(dw, @WeekFillDate) > 1
	BEGIN
		SET @WeekFillDate = DATEADD(dd, -1, @WeekFillDate)

		INSERT INTO @Month (MonthDate,     DayNumber,          DayName,                     DayOfWeek,                   WeekOfMonth,  MonthName)
					VALUES (@WeekFillDate, DAY(@WeekFillDate), DATENAME(dw, @WeekFillDate), DATEPART(dw, @WeekFillDate), @WeekOfMonth, @MonthName)
	END

	WHILE MONTH(@MonthDate) = @MonthNum
	BEGIN
		IF DATEPART(dw, @MonthDate) = 1 AND DAY(@MonthDate) > 1
		BEGIN
			SET @WeekOfMonth = @WeekOfMonth + 1
		END

		INSERT INTO @Month (MonthDate,  DayNumber,       DayName,                  DayOfWeek,                WeekOfMonth,  MonthName)
					VALUES (@MonthDate, DAY(@MonthDate), DATENAME(dw, @MonthDate), DATEPART(dw, @MonthDate), @WeekOfMonth, @MonthName)
	
		SET @MonthDate = DATEADD(dd, 1, @MonthDate)
	END

	-- Finish up the week containing the last day of the month.
	SET @WeekFillDate = DATEADD(dd, -1, @MonthDate)
	WHILE DATEPART(dw, @WeekFillDate) < 7
	BEGIN
		SET @WeekFillDate = DATEADD(dd, 1, @WeekFillDate)

		INSERT INTO @Month (MonthDate,     DayNumber,          DayName,                     DayOfWeek,                   WeekOfMonth,  MonthName)
					VALUES (@WeekFillDate, DAY(@WeekFillDate), DATENAME(dw, @WeekFillDate), DATEPART(dw, @WeekFillDate), @WeekOfMonth, @MonthName)
	END

	
	RETURN 
END

