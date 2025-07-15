CREATE TABLE [dbo].[@Template_OrganizationPosition_User]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[OrganizationPositionID] [int] NOT NULL,
[UserID] [int] NOT NULL,
[DelegateYN] [bit] NOT NULL CONSTRAINT [DF_OrganizationPosition_User_DelegateYN] DEFAULT ((0)),
[DateFrom] [date] NULL,
[DateTo] [date] NULL,
[Comment] [nvarchar] (100) NULL,
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_User] ADD CONSTRAINT [PK_OrganizationPosition_User] PRIMARY KEY CLUSTERED ([OrganizationPositionID], [UserID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_User] ADD CONSTRAINT [FK_OrganizationPosition_User_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_User] ADD CONSTRAINT [FK_OrganizationPosition_User_OrganizationPosition] FOREIGN KEY ([OrganizationPositionID]) REFERENCES [dbo].[@Template_OrganizationPosition] ([OrganizationPositionID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_User] ADD CONSTRAINT [FK_OrganizationPosition_User_User] FOREIGN KEY ([UserID]) REFERENCES [dbo].[@Template_User] ([UserID])
GO
