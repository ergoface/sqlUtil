USE ReportServer
SELECT CAT.Path,CAT.Name,EL.Status, MAX(Q1.TimeStart) STARTTime, MAX(el.UserName) UserName
FROM 
(
  SELECT EL.ReportID,CAT.ItemID,CAT.Path,CAT.Name,
    MAX(EL.TimeStart) TimeStart
  FROM dbo.ExecutionLog EL ,dbo.Catalog CAT 
  WHERE EL.ReportID = CAT.ItemID
  GROUP BY EL.ReportID,CAT.ItemID,CAT.Path,CAT.Name
) Q1,
  dbo.ExecutionLog EL,
  dbo.Catalog CAT
WHERE Q1.ReportID = EL.ReportID
  AND Q1.TimeStart = EL.TimeStart
  AND Q1.ItemID = CAT.ItemID
  AND Q1.Path = CAT.Path
  AND Q1.ReportID = CAT.ItemID 
  AND EL.TimeStart >= '2010-10-28 00:00:00.000'
  AND EL.Status <> 'rsSuccess'
  --AND EL.UserName = 'CORP\A1ITSQL'
GROUP BY CAT.Path,CAT.Name,EL.Status
