CREATE TABLE [dbo].[@Template_WorkflowState]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[WorkflowID] [int] NOT NULL CONSTRAINT [DF_WorkflowState_WorkflowID] DEFAULT ((1001)),
[WorkflowStateId] [int] NOT NULL,
[WorkflowStateName] [nvarchar] (50) NOT NULL,
[InheritedFrom] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_WorkflowState] ADD CONSTRAINT [PK_WorkflowState] PRIMARY KEY CLUSTERED ([WorkflowStateId])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Copied from this WorkflowStateID', 'SCHEMA', N'dbo', 'TABLE', N'@Template_WorkflowState', 'COLUMN', N'InheritedFrom'
GO
