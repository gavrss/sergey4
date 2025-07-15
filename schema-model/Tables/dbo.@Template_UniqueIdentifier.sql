CREATE TABLE [dbo].[@Template_UniqueIdentifier]
(
[InstanceID] [int] NOT NULL,
[GUID] [uniqueidentifier] NOT NULL CONSTRAINT [DF_UniqueIdentifier_GUID] DEFAULT (newid()),
[VersionID] [int] NOT NULL CONSTRAINT [DF_UniqueIdentifier_VersionID] DEFAULT ((0)),
[TableName] [nvarchar] (100) NOT NULL,
[UserID] [int] NOT NULL CONSTRAINT [DF_UniqueIdentifier_UserID] DEFAULT ((0)),
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_UniqueIdentifier_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UniqueIdentifier_InsertedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_UniqueIdentifier] ADD CONSTRAINT [PK_UniqueIdentifier] PRIMARY KEY CLUSTERED ([GUID])
GO
ALTER TABLE [dbo].[@Template_UniqueIdentifier] ADD CONSTRAINT [FK_UniqueIdentifier_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_UniqueIdentifier] ADD CONSTRAINT [FK_UniqueIdentifier_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'The identifier is initially created for this VersionID. But it will then be used for all versions.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_UniqueIdentifier', 'COLUMN', N'VersionID'
GO
