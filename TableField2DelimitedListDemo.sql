/**********************************************************
* This is a demonstration of how you can take the output of a single
* field from a table and export a delimited list using the XML PATH 
* feature of SQL Server 2005+
***********************************************************/

USE [TestScratchPad]
GO
-- Create and populate Test Table

CREATE TABLE [dbo].[ListTest](
	[ListId] [int] IDENTITY(1,1) NOT NULL,
	[ListEntry] [varchar](50) NOT NULL,
 CONSTRAINT [PK_ListTest] PRIMARY KEY CLUSTERED 
(
	[ListId] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO
SET IDENTITY_INSERT [dbo].[ListTest] ON
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (1, N'Stuff')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (2, N'Junk')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (3, N'Glop')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (4, N'Snot')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (5, N'Scum')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (6, N'Crud')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (7, N'Barf')
INSERT [dbo].[ListTest] ([ListId], [ListEntry]) VALUES (8, N'Slime')
SET IDENTITY_INSERT [dbo].[ListTest] OFF

-- Here is the Code that does the real work.
Declare @zoop varchar(3000)
SELECT 
    @zoop =ISNULL(
        (SELECT  ListEntry + ','  FROM ListTest WHERE ListId < 10 GROUP BY ListEntry
        FOR XML PATH (''))
    , '') 
select left(@zoop,len(@zoop)-1) List

/**************************************************
* Note: This works because when you specify an empty string after path, that
* then eliminates the default '<row></row>' that would surround items
* then by using a calculated field for the field you get two benefits:
* first, you can add your delimiting character between entries,
* second, this creates a field without a field name, so the default <ListEntry></ListEntry> tags
* are ommitted. 
* Put it together and you end up with a nice delimited list
***************************************************/
