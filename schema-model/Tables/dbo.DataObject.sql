CREATE TABLE [dbo].[DataObject]
(
[DataObjectID] [int] NOT NULL IDENTITY(1, 1),
[DataObjectName] [nvarchar] (100) NOT NULL,
[ObjectType] [nvarchar] (10) NULL CONSTRAINT [DF_SysTable_ObjectType] DEFAULT (N'Table'),
[DatabaseName] [nvarchar] (50) NULL CONSTRAINT [DF_SysTable_DatabaseName] DEFAULT (N'pcINTEGRATOR'),
[IdentityYN] [bit] NOT NULL CONSTRAINT [DF_SysTable_IdentityYN] DEFAULT ((0)),
[InstanceIDYN] [bit] NOT NULL CONSTRAINT [DF_DataObject_InstanceIDYN] DEFAULT ((0)),
[VersionIDYN] [bit] NOT NULL CONSTRAINT [DF_DataObject_VersionIDYN] DEFAULT ((0)),
[DeletedIDYN] [bit] NOT NULL CONSTRAINT [DF_DataObject_DeletedIDYN] DEFAULT ((0)),
[CreateViewYN] [bit] NOT NULL CONSTRAINT [DF_DataObject_CreateViewYN] DEFAULT ((0)),
[VersionLevel] [nvarchar] (100) NULL,
[Introduced] [nvarchar] (100) NULL,
[Comment] [nvarchar] (1024) NULL,
[Created] [datetime] NULL,
[Changed] [datetime] NULL,
[SortOrder] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_DataObject_SelectYN] DEFAULT ((1)),
[DeletedYN] [bit] NOT NULL CONSTRAINT [DF_DataObject_DeletedYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SysTable_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataObject_Upd]
	ON [dbo].[DataObject]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DO
	SET
		[Version] = @Version
	FROM
		[DataObject] DO
		INNER JOIN Inserted I ON	
			I.DataObjectID = DO.DataObjectID

	UPDATE DO
	SET
		[SortOrder] = CASE WHEN I.[SortOrder] IS NOT NULL THEN I.[SortOrder] ELSE DO.[SortOrder] END
	FROM
		[DataObject] DO
		INNER JOIN Inserted I ON	
			REPLACE(I.DataObjectName, '@Template_', '') = REPLACE(DO.DataObjectName, '@Template_', '')
GO
ALTER TABLE [dbo].[DataObject] ADD CONSTRAINT [PK_DataObject] PRIMARY KEY CLUSTERED ([DataObjectID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [SysTableName_Unique] ON [dbo].[DataObject] ([DataObjectName], [ObjectType], [DatabaseName])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Table, Template, View', 'SCHEMA', N'dbo', 'TABLE', N'DataObject', 'COLUMN', N'ObjectType'
GO
EXEC sp_addextendedproperty N'MS_Description', N'If Source Version is of the level or lower, a manual routine is selected instead of automatic routine during upgrade.', 'SCHEMA', N'dbo', 'TABLE', N'DataObject', 'COLUMN', N'VersionLevel'
GO
