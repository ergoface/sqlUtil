/* Lightweight list of all tables and row counts in the current DB, sorted by row count */

SELECT
        S.name [Schema]
      , T.name AS [TABLE NAME]
      , I.row_count AS [ROWCOUNT]
    FROM
        sys.tables AS T
    INNER JOIN sys.dm_db_partition_stats AS I
        ON T.object_id = I.object_id
           AND I.index_id < 2
    INNER JOIN sys.schemas AS S
        ON S.schema_id = T.schema_id
    ORDER BY
        I.row_count DESC; 