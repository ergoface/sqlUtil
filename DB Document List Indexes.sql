/* Index information for all user tables  in a database */
SELECT  S.name [Schema]
       , T.name [Table]
--, t.object_id
      
      , I.name IndexName
      , I.type_desc IndexType
--, i.index_id
      , I.is_unique
      , I.is_primary_key
      , SUBSTRING((
                    SELECT
                            ', ' + C.name AS [text()]
                        FROM
                            sys.index_columns AS IC
                        INNER JOIN sys.columns AS C
                            ON C.column_id = IC.column_id
                        WHERE
                            C.object_id = T.object_id
                            AND IC.index_id = I.index_id
                            AND IC.object_id = T.object_id
                            AND IC.is_included_column = 0
                        ORDER BY
                            IC.key_ordinal
                  FOR
                    XML PATH('')
                  ), 3, 1000) ColumnsIndexed
      , SUBSTRING((
                    SELECT
                            ', ' + C.name AS [text()]
                        FROM
                            sys.index_columns AS IC
                        INNER JOIN sys.columns AS C
                            ON C.column_id = IC.column_id
                        WHERE
                            C.object_id = T.object_id
                            AND IC.index_id = I.index_id
                            AND IC.object_id = T.object_id
                            AND IC.is_included_column = 1
                        ORDER BY
                            IC.key_ordinal
                  FOR
                    XML PATH('')
                  ), 3, 1000) ColumnsIncluded
    FROM
        sys.tables AS T
    INNER JOIN sys.schemas AS S
        ON S.schema_id = T.schema_id
    INNER JOIN sys.indexes I
        ON T.object_id = I.object_id
    WHERE
        T.is_ms_shipped = 0;



