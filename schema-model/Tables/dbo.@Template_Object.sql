CREATE TABLE [dbo].[@Template_Object]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Object_InstanceID] DEFAULT ((0)),
[ObjectID] [int] NOT NULL,
[ObjectName] [nvarchar] (100) NOT NULL,
[CallistoLabel] [nvarchar] (100) NULL,
[ObjectTypeBM] [int] NOT NULL,
[ParentObjectID] [int] NOT NULL,
[SecurityLevelBM] [int] NOT NULL CONSTRAINT [DF_Object_SecurityLevelBM] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_@Template_Object_SortOrder] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Object_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Object_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Object_Upd]
	ON [dbo].[@Template_Object]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE O
	SET
		[Version] = @Version
	FROM
		[@Template_Object] O
		INNER JOIN Inserted I ON	
			I.ObjectID = O.ObjectID
GO
ALTER TABLE [dbo].[@Template_Object] ADD CONSTRAINT [PK_Object] PRIMARY KEY CLUSTERED ([ObjectID])
GO
ALTER TABLE [dbo].[@Template_Object] ADD CONSTRAINT [FK_Object_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Object] ADD CONSTRAINT [FK_Object_ObjectType] FOREIGN KEY ([ObjectTypeBM]) REFERENCES [dbo].[ObjectType] ([ObjectTypeBM])
GO
ALTER TABLE [dbo].[@Template_Object] ADD CONSTRAINT [FK_Object_SecurityLevel] FOREIGN KEY ([SecurityLevelBM]) REFERENCES [dbo].[SecurityLevel] ([SecurityLevelBM])
GO
ALTER TABLE [dbo].[@Template_Object] NOCHECK CONSTRAINT [FK_Object_ObjectType]
GO
ALTER TABLE [dbo].[@Template_Object] NOCHECK CONSTRAINT [FK_Object_SecurityLevel]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Possible options for SecurityLevelBM', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Object', 'COLUMN', N'SecurityLevelBM'
GO
