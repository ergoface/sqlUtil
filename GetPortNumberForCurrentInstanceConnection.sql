/* Get the port number of the current instance */
SELECT local_tcp_port

FROM   sys.dm_exec_connections

WHERE  session_id = @@SPID