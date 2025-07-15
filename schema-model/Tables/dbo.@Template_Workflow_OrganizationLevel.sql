CREATE TABLE [dbo].[@Template_Workflow_OrganizationLevel]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[WorkflowID] [int] NOT NULL,
[OrganizationLevelNo] [int] NOT NULL,
[LevelInWorkflowYN] [bit] NOT NULL,
[ExpectedDate] [date] NOT NULL,
[ActionDescription] [nvarchar] (50) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_Workflow_OrganizationLevel] ADD CONSTRAINT [PK_Workflow_OrganizationLevel] PRIMARY KEY CLUSTERED ([WorkflowID], [OrganizationLevelNo])
GO
ALTER TABLE [dbo].[@Template_Workflow_OrganizationLevel] ADD CONSTRAINT [FK_Workflow_OrganizationLevel_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [dbo].[@Template_Workflow] ([WorkflowID])
GO
