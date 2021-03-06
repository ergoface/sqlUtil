/*SSRS Reports that take the most time to run*/
SELECT     Catalog.Path, Catalog.Name, ExecutionLog.UserName, ExecutionLog.RequestType, ExecutionLog.Format, ExecutionLog.Parameters, ExecutionLog.TimeStart, 
                      ExecutionLog.TimeEnd, ExecutionLog.TimeDataRetrieval, ExecutionLog.TimeProcessing, ExecutionLog.TimeRendering, ExecutionLog.Source, ExecutionLog.Status, 
                      ExecutionLog.ByteCount, ExecutionLog.[RowCount]
FROM         ExecutionLog INNER JOIN
                      Catalog ON ExecutionLog.ReportID = Catalog.ItemID
ORDER BY TimeDataRetrieval + TimeProcessing desc