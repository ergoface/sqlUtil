/*** Query to display the status and recipients of email report subscriptions ***/
SELECT  Name ReportName
   , subs.LastStatus
   , InactiveFlags
   , LastRunTime
   ,path
   , REPLACE(REPLACE(CAST(CAST(subs.extensionsettings AS XML).query('/ParameterValues/ParameterValue/Value[../Name = ''TO'']') AS VARCHAR(4000)),
                       '</Value>', ''), '<Value>', '') + '; ' EmailTo
FROM ReportServer.dbo.Subscriptions subs
   INNER JOIN ReportServer.dbo.Catalog AS C
     ON subs.Report_OID = C.ItemID
WHERE subs.DeliveryExtension = 'Report Server Email' 
ORDER BY Path 
     