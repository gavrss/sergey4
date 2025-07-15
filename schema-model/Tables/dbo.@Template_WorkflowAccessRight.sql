CREATE TABLE [dbo].[@Template_WorkflowAccessRight]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[WorkflowID] [int] NOT NULL CONSTRAINT [DF_WorkflowAccessRight_WorkflowID] DEFAULT ((1001)),
[OrganizationHierarchyID] [int] NOT NULL,
[OrganizationLevelNo] [int] NOT NULL,
[WorkflowStateID] [int] NOT NULL,
[SecurityLevelBM] [int] NOT NULL CONSTRAINT [DF_WorkflowAccessRight_SecurityLevelBM] DEFAULT ((16))
)
GO
ALTER TABLE [dbo].[@Template_WorkflowAccessRight] ADD CONSTRAINT [PK_WorkflowAccessRight] PRIMARY KEY CLUSTERED ([WorkflowID], [OrganizationHierarchyID], [OrganizationLevelNo], [WorkflowStateID])
GO
ALTER TABLE [dbo].[@Template_WorkflowAccessRight] ADD CONSTRAINT [FK_WorkflowAccessRight_OrganizationLevel] FOREIGN KEY ([OrganizationHierarchyID], [OrganizationLevelNo]) REFERENCES [dbo].[@Template_OrganizationLevel] ([OrganizationHierarchyID], [OrganizationLevelNo])
GO
ALTER TABLE [dbo].[@Template_WorkflowAccessRight] ADD CONSTRAINT [FK_WorkflowAccessRight_WorkflowState] FOREIGN KEY ([WorkflowStateID]) REFERENCES [dbo].[@Template_WorkflowState] ([WorkflowStateId])
GO
