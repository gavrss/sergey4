CREATE TABLE [dbo].[@Template_WorkflowStateChange]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[WorkflowID] [int] NOT NULL CONSTRAINT [DF_WorkflowStateChange_WorkflowID] DEFAULT ((1001)),
[OrganizationHierarchyID] [int] NOT NULL,
[OrganizationLevelNo] [int] NOT NULL,
[FromWorkflowStateID] [int] NOT NULL,
[ToWorkflowStateID] [int] NOT NULL,
[UserChangeableYN] [bit] NOT NULL,
[BRChangeableYN] [bit] NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_WorkflowStateChange] ADD CONSTRAINT [PK_WorkflowStateChange] PRIMARY KEY CLUSTERED ([WorkflowID], [OrganizationHierarchyID], [OrganizationLevelNo], [FromWorkflowStateID], [ToWorkflowStateID])
GO
ALTER TABLE [dbo].[@Template_WorkflowStateChange] ADD CONSTRAINT [FK_WorkflowStateChange_OrganizationLevel] FOREIGN KEY ([OrganizationHierarchyID], [OrganizationLevelNo]) REFERENCES [dbo].[@Template_OrganizationLevel] ([OrganizationHierarchyID], [OrganizationLevelNo])
GO
ALTER TABLE [dbo].[@Template_WorkflowStateChange] ADD CONSTRAINT [FK_WorkflowStateChange_WorkflowState] FOREIGN KEY ([FromWorkflowStateID]) REFERENCES [dbo].[@Template_WorkflowState] ([WorkflowStateId])
GO
ALTER TABLE [dbo].[@Template_WorkflowStateChange] ADD CONSTRAINT [FK_WorkflowStateChange_WorkflowState1] FOREIGN KEY ([ToWorkflowStateID]) REFERENCES [dbo].[@Template_WorkflowState] ([WorkflowStateId])
GO
