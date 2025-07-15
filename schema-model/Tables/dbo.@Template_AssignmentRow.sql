CREATE TABLE [dbo].[@Template_AssignmentRow]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[AssignmentID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[Dimension_MemberKey] [nvarchar] (100) NOT NULL,
[Dimension_MemberID] [bigint] NULL,
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_AssignmentRow] ADD CONSTRAINT [PK_AssignmentRow] PRIMARY KEY CLUSTERED ([AssignmentID], [DimensionID], [Dimension_MemberKey])
GO
ALTER TABLE [dbo].[@Template_AssignmentRow] ADD CONSTRAINT [FK_AssignmentRow_Assignment] FOREIGN KEY ([AssignmentID]) REFERENCES [dbo].[@Template_Assignment] ([AssignmentID])
GO
ALTER TABLE [dbo].[@Template_AssignmentRow] ADD CONSTRAINT [FK_AssignmentRow_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
