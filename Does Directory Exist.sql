/* Does Directory Exist */
DECLARE @Q AS VARCHAR(500)
DECLARE @FE table (fileExists int, fileIsADir int, ParentExists int)
insert into @fe
 EXEC master.dbo.xp_fileexist 'C:\Downloads'
IF EXISTS (SELECT * FROM @fe WHERE fileIsADir = 1
 )
SELECT GETDATE()



