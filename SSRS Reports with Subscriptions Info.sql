/* Reports with Subscriptions full information 
***** NOTE: This relies on the SchedulePlus view to get human readable schedule information
*********/
USE ReportServer
GO
SELECT
c.Name AS ReportName
, c.Type
, c.Description AS ReportDescription
, u.UserName AS ReportCreatedBy
, s.Description AS SubscriptionDescription
, s.DeliveryExtension AS SubscriptionDelivery
, su.UserName AS SubscriptionOwner
, s.LastStatus
, s.LastRunTime
, s.Parameters
,sch.StartDate AS ScheduleStarted
,sch.LastRunTime AS LastSubRun
, sch.HumanFriendly Schedule
, d.Name AS DataSource
, c.Path
FROM
Catalog c
LEFT OUTER JOIN  Subscriptions s ON c.ItemID = s.Report_OID
INNER JOIN  DataSource d ON c.ItemID = d.ItemID
LEFT OUTER JOIN  Users u ON u.UserID = c.CreatedByID
LEFT OUTER JOIN ReportSchedule rs ON c.ItemID = rs.ReportID
LEFT OUTER JOIN  SchedulePlus sch ON rs.ScheduleID = sch.ScheduleID
LEFT OUTER JOIN Users su on s.ownerID = su.UserID
WHERE
c.Type = 2
 AND rs.ReportID IS NOT NULL
--and s.SubscriptionID is not null
ORDER BY c.Name

