/* Search all report definitions for "Some thing"
 Be prepared for Def to be a big ugly field as it contians the full xml for each found report 
 */
USE [ReportServer]
GO
SELECT * FROM (

            SELECT ItemId
                 ,[Name]
                 ,ModifiedDate
                 ,u.UserName ModifiedBy
                 ,GETDATE() InsertedDate
                 ,CAST(CONVERT(XML, CONVERT(VARCHAR(MAX), CONVERT(VARBINARY(MAX), CONTENT))) AS VARCHAR(max)) Def
               FROM Catalog C 
                  INNER JOIN Users U
                  ON u.UserID = c.ModifiedByID
               WHERE Content IS NOT NULL AND Type != 3 ) Rep
WHERE Def LIKE '%<Item to change>%'               
                  

GO


