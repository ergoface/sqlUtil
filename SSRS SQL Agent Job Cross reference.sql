/* List SQL Agent Job IDs for SSRS report schedules */
SELECT dbo.Schedule.ScheduleID, dbo.[Catalog].ItemID, dbo.[Catalog].Name
FROM dbo.Schedule INNER JOIN
dbo.ReportSchedule ON dbo.Schedule.ScheduleID = dbo.ReportSchedule.ScheduleID INNER JOIN
dbo.[Catalog] ON dbo.ReportSchedule.ReportID = dbo.[Catalog].ItemID 