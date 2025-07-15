CREATE TABLE [dbo].[@Template_OrganizationPosition]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_OrganizationPosition_VersionID] DEFAULT ((0)),
[OrganizationPositionID] [int] NOT NULL,
[OrganizationPositionName] [nvarchar] (100) NOT NULL,
[OrganizationPositionDescription] [nvarchar] (255) NOT NULL,
[OrganizationPositionTypeID] [int] NULL,
[OrganizationHierarchyID] [int] NOT NULL,
[ParentOrganizationPositionID] [int] NULL,
[OrganizationLevelNo] [int] NULL,
[LinkedDimension_MemberKey] [nvarchar] (100) NULL,
[InheritedFrom] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_OrganizationPosition_SortOrder] DEFAULT ((10000)),
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition] ADD CONSTRAINT [PK_Accountability] PRIMARY KEY CLUSTERED ([OrganizationPositionID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition] ADD CONSTRAINT [FK_OrganizationPosition_OrganizationHierarchy] FOREIGN KEY ([OrganizationHierarchyID]) REFERENCES [dbo].[@Template_OrganizationHierarchy] ([OrganizationHierarchyID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition] ADD CONSTRAINT [FK_OrganizationPosition_OrganizationLevel] FOREIGN KEY ([OrganizationHierarchyID], [OrganizationLevelNo]) REFERENCES [dbo].[@Template_OrganizationLevel] ([OrganizationHierarchyID], [OrganizationLevelNo])
GO
