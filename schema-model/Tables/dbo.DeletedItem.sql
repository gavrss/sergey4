CREATE TABLE [dbo].[DeletedItem]
(
[InstanceID] [int] NOT NULL,
[UserID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[DeletedID] [int] NOT NULL IDENTITY(1001, 1),
[TableName] [nvarchar] (100) NOT NULL,
[UserName] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DeletedItem_UserName] DEFAULT (suser_name()),
[DeletedDateTime] [datetime] NOT NULL CONSTRAINT [DF_DeletedItem_DeletedDateTime] DEFAULT (getdate())
)
GO
ALTER TABLE [dbo].[DeletedItem] ADD CONSTRAINT [PK_DeletedItem] PRIMARY KEY CLUSTERED ([DeletedID])
GO
