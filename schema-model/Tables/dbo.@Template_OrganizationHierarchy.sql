CREATE TABLE [dbo].[@Template_OrganizationHierarchy]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_OrganizationHierarchy_VersionID] DEFAULT ((0)),
[OrganizationHierarchyID] [int] NOT NULL,
[OrganizationHierarchyName] [nvarchar] (50) NOT NULL,
[LinkedDimensionID] [int] NULL,
[ModelingStatusID] [int] NOT NULL CONSTRAINT [DF_OrganizationHierarchy_ModelingStatusID] DEFAULT ((-40)),
[ModelingComment] [nvarchar] (1024) NULL,
[InheritedFrom] [int] NULL,
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationHierarchy] ADD CONSTRAINT [PK_AccountabilityGroup] PRIMARY KEY CLUSTERED ([OrganizationHierarchyID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Copied from this WorkflowStateID', 'SCHEMA', N'dbo', 'TABLE', N'@Template_OrganizationHierarchy', 'COLUMN', N'InheritedFrom'
GO
