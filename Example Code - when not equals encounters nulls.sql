/* Example of comparison differences with NULL values and the <> (not equals) operator */
CREATE TABLE #t1 (Id INT, C1 VARCHAR(50));
CREATE TABLE #t2 (Id INT, C1 VARCHAR(50));
INSERT INTO #t1
        ( Id, C1 )
    VALUES
        ( 1  -- Id - int
          , 'A'  -- C1 - varchar(50)
          ),
		  (2,'B')
		  ,(3,'C');
INSERT INTO #t2
        ( Id, C1 )
    VALUES
        ( 1  -- Id - int
          , 'A'  -- C1 - varchar(50)
          )
		  ,(2,'R')
		  ,(3, NULL)

Select '#T1'
SELECT * FROM #t1 AS T
Select '#T2'
SELECT * FROM #t2 AS T
Select 'WHERE t1.C1 <> t2.c1'
SELECT *
FROM #t1 AS T1
INNER JOIN #t2 AS T2
ON t1.Id = t2.Id
WHERE t1.C1 <> t2.c1
Select 'WHERE ISNULL(t1.C1,''Null'') <> ISNULL(t2.c1,''Null'')'
SELECT *
FROM #t1 AS T1
INNER JOIN #t2 AS T2
ON t1.Id = t2.Id
WHERE ISNULL(t1.C1,'Null') <> ISNULL(t2.c1,'Null')
