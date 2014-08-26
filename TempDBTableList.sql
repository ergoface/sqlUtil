-- Find out who created the temporary table,and when; the culprit and SPId.
 
SELECT DISTINCT te.name, t.Name, t.create_date, SPID, SessionLoginName
 
FROM ::fn_trace_gettable(( SELECT LEFT(path, LEN(path)-CHARINDEX('\', REVERSE(path))) + '\Log.trc' 

                            FROM    sys.traces -- read all five trace files
 
                            WHERE   is_default = 1 

                          ), DEFAULT) trace
 
INNER JOIN sys.trace_events te on trace.EventClass = te.trace_event_id
 
INNER JOIN TempDB.sys.tables  AS t ON trace.ObjectID = t.OBJECT_ID 

WHERE trace.DatabaseName = 'TempDB'
 
  AND t.Name LIKE '#%'
 
  AND te.name = 'Object:Created' 

  AND DATEPART(dy,t.create_date)= DATEPART(Dy,trace.StartTime) 

  AND ABS(DATEDIFF(Ms,t.create_date,trace.StartTime))<50 --sometimes slightly out
 
ORDER BY t.create_date
