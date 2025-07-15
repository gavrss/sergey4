CREATE TABLE [dbo].[@Template_Workflow]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_Workflow_VersionID] DEFAULT ((0)),
[WorkflowID] [int] NOT NULL,
[WorkflowName] [nvarchar] (50) NOT NULL,
[ProcessID] [int] NOT NULL,
[ScenarioID] [int] NOT NULL,
[CompareScenarioID] [int] NULL,
[TimeFrom] [int] NULL,
[TimeTo] [int] NULL,
[TimeOffsetFrom] [int] NOT NULL CONSTRAINT [DF_Workflow_TimeOffsetFrom] DEFAULT ((0)),
[TimeOffsetTo] [int] NOT NULL CONSTRAINT [DF_Workflow_TimeOffsetTo] DEFAULT ((0)),
[InitialWorkflowStateID] [int] NOT NULL CONSTRAINT [DF_Workflow_InitialWorkflowStateID] DEFAULT ((0)),
[RefreshActualsInitialWorkflowStateID] [int] NOT NULL CONSTRAINT [DF_Workflow_InitialWorkflowStateID1] DEFAULT ((0)),
[SpreadingKeyID] [int] NOT NULL CONSTRAINT [DF_Workflow_SpreadingKeyID] DEFAULT ((0)),
[LiveFcstNext_TimeFrom] [int] NULL,
[LiveFcstNext_TimeTo] [int] NULL,
[LiveFcstNext_ClosedMonth] [int] NULL,
[ModelingStatusID] [int] NOT NULL CONSTRAINT [DF_Workflow_ModelingStatusID] DEFAULT ((-40)),
[ModelingComment] [nvarchar] (1024) NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL,
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_Workflow] ADD CONSTRAINT [PK_WorkFlow] PRIMARY KEY CLUSTERED ([WorkflowID])
GO
ALTER TABLE [dbo].[@Template_Workflow] ADD CONSTRAINT [FK_Workflow_DeletedItem] FOREIGN KEY ([DeletedID]) REFERENCES [dbo].[DeletedItem] ([DeletedID])
GO
ALTER TABLE [dbo].[@Template_Workflow] ADD CONSTRAINT [FK_Workflow_Process] FOREIGN KEY ([ProcessID]) REFERENCES [dbo].[@Template_Process] ([ProcessID])
GO
ALTER TABLE [dbo].[@Template_Workflow] ADD CONSTRAINT [FK_Workflow_Scenario] FOREIGN KEY ([ScenarioID]) REFERENCES [dbo].[@Template_Scenario] ([ScenarioID])
GO
ALTER TABLE [dbo].[@Template_Workflow] ADD CONSTRAINT [FK_Workflow_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Copied from this WorkflowID', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'InheritedFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Normally YYYYMM (YYYY and YYYYMMDD are also possible)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'LiveFcstNext_ClosedMonth'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Normally YYYYMM (YYYY and YYYYMMDD are also possible)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'LiveFcstNext_TimeFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Normally YYYYMM (YYYY and YYYYMMDD are also possible)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'LiveFcstNext_TimeTo'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Normally YYYYMM (YYYY and YYYYMMDD are also possible)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'TimeFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Number of Months compared to (before) last closed Month for selected Scenario (example: -3)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'TimeOffsetFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Number of Months compared to (after) last closed Month for selected Scenario (example: 12)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'TimeOffsetTo'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Normally YYYYMM (YYYY and YYYYMMDD are also possible)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Workflow', 'COLUMN', N'TimeTo'
GO
