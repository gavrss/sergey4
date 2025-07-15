CREATE TABLE [dbo].[@Template_WorkflowRow]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[WorkflowID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[Dimension_MemberKey] [nvarchar] (100) NOT NULL,
[CogentYN] [bit] NOT NULL CONSTRAINT [DF_WorkflowRow_CogentYN] DEFAULT ((1))
)
GO
ALTER TABLE [dbo].[@Template_WorkflowRow] ADD CONSTRAINT [PK_WorkflowRow] PRIMARY KEY CLUSTERED ([WorkflowID], [DimensionID], [Dimension_MemberKey])
GO
ALTER TABLE [dbo].[@Template_WorkflowRow] ADD CONSTRAINT [FK_WorkflowRow_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_WorkflowRow] ADD CONSTRAINT [FK_WorkflowRow_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [dbo].[@Template_Workflow] ([WorkflowID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'If set this value can not be changed on assignment level.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_WorkflowRow', 'COLUMN', N'CogentYN'
GO
