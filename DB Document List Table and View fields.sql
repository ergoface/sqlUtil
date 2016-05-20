/* List all tables and field properties for each table in the database */
SELECT
        OBJECT_SCHEMA_NAME(T.[object_id], DB_ID()) AS [Schema]
      , T.[name] AS [table_name]
	  , ep.value AS [table_description]
      , AC.[name] AS [column_name]
      , TY.[name] AS system_data_type
      , AC.[max_length]
      , AC.[precision]
      , AC.[scale]
      , AC.[is_nullable]
      , p.value Description
	  , dc.definition DefaultValue
	  , dc.name DefaultConstriant
    FROM
        sys.[tables] AS T
LEFT OUTER JOIN sys.extended_properties ep
        ON ep.major_id = t.object_id
           AND ep.minor_id = 0
    INNER JOIN sys.[all_columns] AC
        ON T.[object_id] = AC.[object_id]
    INNER JOIN sys.[types] TY
        ON AC.[system_type_id] = TY.[system_type_id]
           AND AC.[user_type_id] = TY.[user_type_id]
    LEFT OUTER JOIN sys.default_constraints AS DC
		ON t.object_id = dc.parent_object_id
			AND ac.column_id = dc.parent_column_id
    LEFT OUTER JOIN sys.extended_properties p
        ON p.major_id = AC.object_id
           AND p.minor_id = AC.column_id
    WHERE
        T.[is_ms_shipped] = 0
        AND T.name NOT IN('sysdiagrams','tracelog')
    ORDER BY
        T.[name]
      , AC.[column_id];


   /****************************/   
   SELECT
        OBJECT_SCHEMA_NAME(T.[object_id], DB_ID()) AS [Schema]
      , T.[name] AS [view_name]
	  , ep.value AS [view_description]
      , AC.[name] AS [column_name]
      , TY.[name] AS system_data_type
      , AC.[max_length]
      , AC.[precision]
      , AC.[scale]
      , AC.[is_nullable]
      , p.value Description
	  
    FROM
        sys.views  AS T
LEFT OUTER JOIN sys.extended_properties ep
        ON ep.major_id = t.object_id
		AND ep.name LIKE 'MS_Description'
           AND ep.minor_id = 0
    INNER JOIN sys.[all_columns] AC
        ON T.[object_id] = AC.[object_id]
    INNER JOIN sys.[types] TY
        ON AC.[system_type_id] = TY.[system_type_id]
           AND AC.[user_type_id] = TY.[user_type_id]
    LEFT OUTER JOIN sys.default_constraints AS DC
		ON t.object_id = dc.parent_object_id
			AND ac.column_id = dc.parent_column_id
    LEFT OUTER JOIN sys.extended_properties p
        ON p.major_id = AC.object_id
           AND p.minor_id = AC.column_id
		   AND p.name = 'MS_Description'
    WHERE
        T.[is_ms_shipped] = 0
        AND T.name <> 'sysdiagrams'
    ORDER BY
        T.[name]
      , AC.[column_id];