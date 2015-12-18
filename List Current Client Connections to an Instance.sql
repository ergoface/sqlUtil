/*List Actual Current client connections to an Instance
Author: Dave Bennett
Last Modified: 9/24/2015 */
SELECT
        client_net_address
      , DB_NAME(SP.dbid) DB
      , COUNT(*) NumConnections
    FROM
        sys.dm_exec_connections C
    INNER	 JOIN sys.dm_exec_sessions S
        ON S.session_id = C.session_id
    INNER JOIN sys.sysprocesses SP
        ON SP.spid = S.session_id
    GROUP BY
        client_net_address
      , DB_NAME(SP.dbid)
    ORDER BY
        DB;