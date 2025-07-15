CREATE TABLE [dbo].[AssignmentSource]
(
[AssignmentSourceID] [int] NOT NULL,
[Description] [nvarchar] (100) NOT NULL,
[SourceTable] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[AssignmentSource] ADD CONSTRAINT [PK_AssignmentSource] PRIMARY KEY CLUSTERED ([AssignmentSourceID])
GO
