CREATE TABLE [dbo].[@Template_OrganizationLevel]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_OrganizationLevel_InstanceID] DEFAULT ((0)),
[VersionID] [int] NULL,
[OrganizationHierarchyID] [int] NOT NULL,
[OrganizationLevelNo] [int] NOT NULL,
[OrganizationLevelName] [nvarchar] (50) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationLevel] ADD CONSTRAINT [PK_WorkflowLevel] PRIMARY KEY CLUSTERED ([OrganizationHierarchyID], [OrganizationLevelNo])
GO
ALTER TABLE [dbo].[@Template_OrganizationLevel] ADD CONSTRAINT [FK_OrganizationLevel_OrganizationHierarchy] FOREIGN KEY ([OrganizationHierarchyID]) REFERENCES [dbo].[@Template_OrganizationHierarchy] ([OrganizationHierarchyID])
GO
