CREATE TABLE [dbo].[StorageType]
(
[StorageTypeBM] [int] NOT NULL,
[StorageTypeName] [nvarchar] (50) NULL,
[StorageTypeDescription] [nvarchar] (128) NULL
)
GO
ALTER TABLE [dbo].[StorageType] ADD CONSTRAINT [PK_StorageType] PRIMARY KEY CLUSTERED ([StorageTypeBM])
GO
