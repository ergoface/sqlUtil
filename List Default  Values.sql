/* List all default values in all tables in a database */
SELECT t.name as table_name,  c.name as constraint_name,cl.name as column_name,  so.text as Value
FROM
        sysconstraints cn
INNER JOIN
        sysobjects c on cn.constid = c.id
INNER JOIN
        sysobjects t on cn.id = t.id
INNER JOIN
        syscolumns cl on t.id = cl.id and cn.colid = cl.colid
INNER Join
		syscomments so on cl.cdefault = so.id
order by t.name