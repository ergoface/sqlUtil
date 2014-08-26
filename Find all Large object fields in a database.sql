/** Show all large object fields in all user tables in a database ***/

 select * from information_schema.columns where (data_type in 
    ('TEXT', 'NTEXT','IMAGE' ,'XML', 'VARBINARY')
    or 
    (data_type = 'VARCHAR' and character_maximum_length = -1)
    OR
    (data_type = 'NVARCHAR' and character_maximum_length = -1))
	AND (TABLE_NAME NOT LIKE('sys%') AND TABLE_NAME NOT LIKE('MS%') AND TABLE_NAME NOT LIKE('sync%'))

