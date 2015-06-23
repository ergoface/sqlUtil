/* List Database objects */

/*list all the tables   */     

SELECT
       s.name [Schema]
	   ,T.name AS [TableName]
      , ep.value Description
    FROM
        sys.objects T
		INNER JOIN
        sys.schemas AS S
			ON S.schema_id = T.schema_id
    LEFT OUTER JOIN sys.extended_properties ep
        ON ep.name LIKE 'MS_Description'
           AND ep.major_id = T.object_id
           AND minor_id = 0
    WHERE
        OBJECTPROPERTY(object_id, 'isUserTable') <> 0
        AND is_ms_shipped = 0
        AND T.name <> 'sysdiagrams'
    ORDER BY
        T.name;

/* List Views */
SELECT s.name [Schema]
       , T.name AS [ViewName]
      , ep.value Description
    FROM
        sys.objects T
		INNER JOIN
		sys.schemas AS S
			ON S.schema_id = T.schema_id
    LEFT OUTER JOIN sys.extended_properties ep
        ON ep.name LIKE 'MS_Description'
           AND ep.major_id = T.object_id
           AND minor_id = 0
    WHERE
        OBJECTPROPERTY(object_id, 'IsView') <> 0
        AND is_ms_shipped = 0
        AND T.name <> 'sysdiagrams'
    ORDER BY
        T.name;

/*List scalar functions, their parameters, and their extended properties*/
SELECT s.name [Schema]
       , so.name + REPLACE('(' + COALESCE((
                                           SELECT
                                                name + ', '
                                            FROM
                                                sys.parameters sp
                                            WHERE
                                                sp.object_id = so.object_id
                                                AND parameter_id > 0
                                            ORDER BY
                                                parameter_id
                                         FOR
                                           XML PATH('')
                                         ), '') + ')', ', )', ')') + COALESCE('  /*' + CONVERT(VARCHAR(300), value)
                                                                              + '*/', '') [Scalar functions]
    FROM
        sys.objects so
		INNER JOIN
		sys.schemas AS S
			ON S.schema_id = so.schema_id
    LEFT OUTER JOIN sys.extended_properties ep
        /*get any extended properties*/ ON ep.name LIKE 'MS_Description'
                                           AND major_id = so.object_id
    WHERE
        OBJECTPROPERTY(object_id, 'IsScalarFunction') <> 0;

  /********************************/

/*list all the Table Functions */

SELECT  
 so.name + REPLACE('(' + COALESCE((
                                           SELECT
                                                name + ', '
                                            FROM
                                                sys.parameters sp
                                            WHERE
                                                sp.object_id = so.object_id
                                                AND parameter_id > 0
                                            ORDER BY
                                                parameter_id
                                         FOR
                                           XML PATH('')
                                         ), '') + ')', ', )', ')') + COALESCE('  /*' + CONVERT(VARCHAR(300), ep.value)
                                                                              + '*/', '') AS [Table Functions]
FROM sys.objects so 
LEFT OUTER JOIN sys.extended_properties ep
        /*get any extended properties*/ ON ep.name LIKE 'MS_Description'
                                           AND major_id = so.object_id
WHERE OBJECTPROPERTY(object_id, 'IsTableFunction')<>0

/*list all the Procedures */

SELECT s.name [Schema] 
 ,so.name + REPLACE('(' + COALESCE((
                                           SELECT
                                                name + ', '
                                            FROM
                                                sys.parameters sp
                                            WHERE
                                                sp.object_id = so.object_id
                                                AND parameter_id > 0
                                            ORDER BY
                                                parameter_id
                                         FOR
                                           XML PATH('')
                                         ), '') + ')', ', )', ')') + COALESCE('  /*' + CONVERT(VARCHAR(300), ep.value)
                                                                              + '*/', '') AS [Procedures]
FROM sys.objects so 
INNER JOIN sys.schemas AS S
	ON S.schema_id = so.schema_id
LEFT OUTER JOIN sys.extended_properties ep
        /*get any extended properties*/ ON ep.name LIKE 'MS_Description'
                                           AND major_id = so.object_id
WHERE OBJECTPROPERTY(object_id, 'IsProcedure')<>0

--list all the Triggers

SELECT name AS [Triggers] FROM sys.objects WHERE OBJECTPROPERTY(object_id, 'IsTrigger')<>0