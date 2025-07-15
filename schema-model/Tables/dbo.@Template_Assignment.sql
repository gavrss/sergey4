CREATE TABLE [dbo].[@Template_Assignment]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[AssignmentID] [int] NOT NULL,
[AssignmentName] [nvarchar] (100) NOT NULL,
[Comment] [nvarchar] (255) NULL,
[OrganizationPositionID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[WorkflowID] [int] NOT NULL,
[SpreadingKeyID] [int] NULL,
[GridID] [int] NULL,
[LiveFcstNextFlowID] [int] NOT NULL CONSTRAINT [DF_Assignment_LiveFcstNextFlowID] DEFAULT ((1)),
[Priority] [int] NOT NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Assignment_SelectYN] DEFAULT ((1)),
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_Assignment] ADD CONSTRAINT [PK_pcETL_Accountability_1] PRIMARY KEY CLUSTERED ([AssignmentID])
GO
ALTER TABLE [dbo].[@Template_Assignment] ADD CONSTRAINT [FK_Assignment_Accountability] FOREIGN KEY ([OrganizationPositionID]) REFERENCES [dbo].[@Template_OrganizationPosition] ([OrganizationPositionID])
GO
ALTER TABLE [dbo].[@Template_Assignment] ADD CONSTRAINT [FK_Assignment_DataClass] FOREIGN KEY ([DataClassID]) REFERENCES [dbo].[@Template_DataClass] ([DataClassID])
GO
ALTER TABLE [dbo].[@Template_Assignment] ADD CONSTRAINT [FK_Assignment_DeletedItem] FOREIGN KEY ([DeletedID]) REFERENCES [dbo].[DeletedItem] ([DeletedID])
GO
ALTER TABLE [dbo].[@Template_Assignment] ADD CONSTRAINT [FK_Assignment_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
ALTER TABLE [dbo].[@Template_Assignment] ADD CONSTRAINT [FK_Assignment_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [dbo].[@Template_Workflow] ([WorkflowID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Copied from this AssignmentID', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Assignment', 'COLUMN', N'InheritedFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'If NULL inherited from Workflow', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Assignment', 'COLUMN', N'SpreadingKeyID'
GO
