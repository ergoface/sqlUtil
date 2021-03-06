
SELECT    d.Name "Database", T.EventName, RowNumber,  ApplicationName, HostName, LoginName,  
                      StartTime, Success, TextData, Duration, EndTime, NTDomainName, NTUserName, CPU, Reads, 
                      Writes
FROM         ksar_marketing.dbo.LoginTrace
	inner join master.dbo.sysdatabases d
		on d.dbid = DatabaseID
	inner join TraceEventList T
		on EventClass = T.EventId
Where eventName = 'Login Failed' and HostName <> 'CKAN0IS01'
Order by d.Name, EventName





Select d.Name, max(EventClass) EventClass

FROM         ksar_marketing.dbo.LoginTrace
	Right join master.dbo.sysdatabases d
		on d.dbid = DatabaseID
	
group by d.Name
order by EventClass
