   /* Script to view the number of open sessions on an instance*/
   
    SELECT COUNT(*),program_name
    FROM sys.sysprocesses
    GROUP BY program_name
    ORDER BY 1 desc