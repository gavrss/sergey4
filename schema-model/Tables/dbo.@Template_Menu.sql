CREATE TABLE [dbo].[@Template_Menu]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_Menu_VersionID] DEFAULT ((1001)),
[MenuID] [int] NOT NULL,
[MenuName] [nvarchar] (50) NOT NULL,
[MenuDescription] [nvarchar] (255) NOT NULL,
[MenuParentID] [int] NOT NULL,
[MenuTypeBM] [int] NOT NULL CONSTRAINT [DF_Menu_MenuTypeBM] DEFAULT ((1)),
[MenuItemTypeID] [int] NULL CONSTRAINT [DF_Menu_MenuItemTypeID] DEFAULT ((-1)),
[MenuParameter] [nvarchar] (255) NULL,
[LicenseYN] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Menu_LicenseYN] DEFAULT ('1'),
[ExistYN] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Menu_InstalledYN] DEFAULT ('1'),
[SecurityYN] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Menu_SecurityYN] DEFAULT ('1'),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_Menu_SortOrder] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Menu_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Menu_Upd]
	ON [dbo].[@Template_Menu]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[@Template_Menu] M
		INNER JOIN Inserted I ON	
			I.MenuID = M.MenuID
GO
ALTER TABLE [dbo].[@Template_Menu] ADD CONSTRAINT [PK_Menu] PRIMARY KEY CLUSTERED ([MenuID])
GO
ALTER TABLE [dbo].[@Template_Menu] ADD CONSTRAINT [FK_Menu_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Menu] ADD CONSTRAINT [FK_Menu_MenuItemType] FOREIGN KEY ([MenuItemTypeID]) REFERENCES [dbo].[MenuItemType] ([MenuItemTypeID])
GO
ALTER TABLE [dbo].[@Template_Menu] ADD CONSTRAINT [FK_Menu_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = pcPortal, 2 = Excel', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Menu', 'COLUMN', N'MenuTypeBM'
GO
