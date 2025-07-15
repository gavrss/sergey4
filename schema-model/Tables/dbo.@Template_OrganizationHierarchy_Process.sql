CREATE TABLE [dbo].[@Template_OrganizationHierarchy_Process]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_OrganizationHierarchy_Process_InstanceID] DEFAULT ((0)),
[VersionID] [int] NULL,
[OrganizationHierarchyID] [int] NOT NULL,
[ProcessID] [int] NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationHierarchy_Process] ADD CONSTRAINT [PK_OrganizationHierarchy_Process] PRIMARY KEY CLUSTERED ([OrganizationHierarchyID], [ProcessID])
GO
ALTER TABLE [dbo].[@Template_OrganizationHierarchy_Process] ADD CONSTRAINT [FK_OrganizationHierarchy_Process_OrganizationHierarchy] FOREIGN KEY ([OrganizationHierarchyID]) REFERENCES [dbo].[@Template_OrganizationHierarchy] ([OrganizationHierarchyID])
GO
ALTER TABLE [dbo].[@Template_OrganizationHierarchy_Process] ADD CONSTRAINT [FK_OrganizationHierarchy_Process_Process] FOREIGN KEY ([ProcessID]) REFERENCES [dbo].[@Template_Process] ([ProcessID])
GO
