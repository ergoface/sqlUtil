/*** Routine to show running jobs and their estimated time to completion (if applicable) *****/
select 
convert (varchar(50),(estimated_completion_time/3600000))+'hrs'+
convert (varchar(50), ((estimated_completion_time%3600000)/60000))+'min'+
convert (varchar(50), (((estimated_completion_time%3600000)%60000)/1000))+'sec'
as Estimated_Completion_Time, 
status, command, db_name(database_id), percent_complete
from sys.dm_exec_requests

