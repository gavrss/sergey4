CREATE TABLE [dbo].[@Template_OrganizationPosition_DimensionMember]
(
[Comment] [nvarchar] (100) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[OrganizationPositionID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[HierarchyNo] [int] NOT NULL CONSTRAINT [DF_@Template_OrganizationPosition_DimensionMember_HierarchyNo] DEFAULT ((0)),
[MemberKey] [nvarchar] (100) NOT NULL,
[ReadAccessYN] [bit] NOT NULL CONSTRAINT [DF_OrganizationPosition_DimensionMember_ReadAccessYN] DEFAULT ((1)),
[WriteAccessYN] [bit] NOT NULL CONSTRAINT [DF_@Template_OrganizationPosition_DimensionMember_WriteAccessYN] DEFAULT ((0)),
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DimensionMember] ADD CONSTRAINT [PK_OrganizationPosition_DimensionMember] PRIMARY KEY CLUSTERED ([OrganizationPositionID], [DimensionID], [HierarchyNo], [MemberKey])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DimensionMember] ADD CONSTRAINT [FK_OrganizationPosition_DimensionMember_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DimensionMember] ADD CONSTRAINT [FK_OrganizationPosition_DimensionMember_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DimensionMember] ADD CONSTRAINT [FK_OrganizationPosition_DimensionMember_OrganizationPosition] FOREIGN KEY ([OrganizationPositionID]) REFERENCES [dbo].[@Template_OrganizationPosition] ([OrganizationPositionID])
GO
