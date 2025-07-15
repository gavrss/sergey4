CREATE TABLE [dbo].[MenuItemType]
(
[MenuItemTypeID] [int] NOT NULL,
[MenuItemTypeName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_MenuItemType_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[MenuItemType] ADD CONSTRAINT [PK_MenuItemType] PRIMARY KEY CLUSTERED ([MenuItemTypeID])
GO
