/**** Show same info as SP_WHO2 and the most recent SQL Text for USER SPIDS  ****/

SELECT s.spid
     ,s.blocked
	 ,DB_NAME(s.dbid) DB
     ,s.status
	 ,s.cpu
	 ,s.memusage
	 ,s.physical_io
	 ,s.program_name
	 ,s.hostname
	 ,s.loginame
	 ,s.last_batch
	 ,s.waittime
	 ,s.lastwaittype
     ,t.text SQLText
   FROM sys.sysprocesses S
      CROSS APPLY sys.dm_exec_sql_text(sql_handle) T
   WHERE s.spid >= 50
   ORDER BY
    --last_batch desc,
	 s.blocked desc,DB_NAME(s.dbid) ,s.spid


  